import Foundation

public struct KiroUsage {
    public let planName: String
    public let creditsUsed: Double
    public let creditsTotal: Double
    public let percent: Int
    public let resetsAt: Date?
}

public enum KiroProbeError: LocalizedError, Equatable {
    case cliNotFound, notLoggedIn, parseFailed(String)
    public var errorDescription: String? {
        switch self {
        case .cliNotFound: "kiro-cli not found"
        case .notLoggedIn: "Not logged in"
        case .parseFailed(let msg): msg
        }
    }
}

public struct KiroUsageProbe {
    public init() {}
    
    public func fetch() async throws -> KiroUsage {
        let output = try await runCLI()
        return try Self.parse(output)
    }
    
    private func runCLI() async throws -> String {
        guard let path = Self.which("kiro-cli") else { throw KiroProbeError.cliNotFound }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["chat", "--no-interactive", "/usage"]
        process.environment = ProcessInfo.processInfo.environment.merging(["TERM": "xterm-256color"]) { $1 }
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        
        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global().async {
                do {
                    try process.run()
                    let deadline = Date().addingTimeInterval(20)
                    while process.isRunning && Date() < deadline {
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                    if process.isRunning { process.terminate() }
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    cont.resume(returning: String(data: data, encoding: .utf8) ?? "")
                } catch { cont.resume(throwing: error) }
            }
        }
    }
    
    public static func parse(_ output: String) throws -> KiroUsage {
        let stripped = stripANSI(output)
        let lower = stripped.lowercased()
        
        if lower.contains("not logged in") || lower.contains("login required") {
            throw KiroProbeError.notLoggedIn
        }
        
        // Plan name: "| KIRO FREE" or "│ KIRO FREE" or "Plan: X"
        var planName = "Kiro"
        if let m = stripped.range(of: #"[│|]\s*(KIRO\s+\w+)"#, options: .regularExpression) {
            planName = stripped[m].replacingOccurrences(of: "│", with: "").replacingOccurrences(of: "|", with: "").trimmingCharacters(in: .whitespaces)
        } else if let m = stripped.range(of: #"Plan:\s*(.+)"#, options: .regularExpression) {
            let line = stripped[m].replacingOccurrences(of: "Plan:", with: "").trimmingCharacters(in: .whitespaces)
            if let first = line.split(separator: "\n").first { planName = String(first) }
        }
        
        // Percent: "███...█ X%" or "██░░░ X%"
        var percent = 0
        if let m = stripped.range(of: #"[█░]+\s*(\d+)%"#, options: .regularExpression),
           let n = stripped[m].range(of: #"\d+"#, options: .regularExpression) {
            percent = Int(stripped[m][n]) ?? 0
        }
        
        // Credits: "(X.XX of Y covered in plan)"
        var used = 0.0, total = 50.0
        if let m = stripped.range(of: #"\((\d+\.?\d*)\s+of\s+(\d+)"#, options: .regularExpression) {
            let sub = String(stripped[m])
            let numPattern = try? NSRegularExpression(pattern: #"(\d+\.?\d*)"#)
            let range = NSRange(sub.startIndex..., in: sub)
            let matches = numPattern?.matches(in: sub, range: range) ?? []
            if matches.count >= 2 {
                if let r0 = Range(matches[0].range, in: sub) { used = Double(sub[r0]) ?? 0 }
                if let r1 = Range(matches[1].range, in: sub) { total = Double(sub[r1]) ?? 50 }
            }
        }
        
        // Reset: "resets on MM/DD"
        var resetsAt: Date?
        if let m = stripped.range(of: #"resets on (\d{2}/\d{2})"#, options: .regularExpression),
           let d = stripped[m].range(of: #"\d{2}/\d{2}"#, options: .regularExpression) {
            resetsAt = parseResetDate(String(stripped[m][d]))
        }
        
        if percent == 0 && used == 0 && total == 50 {
            throw KiroProbeError.parseFailed("Could not parse usage output")
        }
        
        return KiroUsage(planName: planName, creditsUsed: used, creditsTotal: total, percent: percent, resetsAt: resetsAt)
    }
    
    private static func stripANSI(_ s: String) -> String {
        s.replacingOccurrences(of: #"\x1B\[[0-9;?]*[A-Za-z]|\x1B\].*?\x07"#, with: "", options: .regularExpression)
    }
    
    private static func parseResetDate(_ s: String) -> Date? {
        let parts = s.split(separator: "/")
        guard parts.count == 2, let m = Int(parts[0]), let d = Int(parts[1]) else { return nil }
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        var c = DateComponents(year: year, month: m, day: d)
        if let date = cal.date(from: c), date > Date() { return date }
        c.year = year + 1
        return cal.date(from: c)
    }
    
    private static func which(_ cmd: String) -> String? {
        let paths = (ProcessInfo.processInfo.environment["PATH"] ?? "/usr/local/bin:/usr/bin")
            .split(separator: ":").map(String.init)
        for p in paths {
            let full = "\(p)/\(cmd)"
            if FileManager.default.isExecutableFile(atPath: full) { return full }
        }
        return nil
    }
}
