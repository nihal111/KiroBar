// Simple test runner - no XCTest needed
import Foundation
import KiroBarCore

var passed = 0
var failed = 0

func test(_ name: String, _ block: () throws -> Void) {
    do {
        try block()
        print("✓ \(name)")
        passed += 1
    } catch {
        print("✗ \(name): \(error)")
        failed += 1
    }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, file: String = #file, line: Int = #line) throws {
    guard a == b else { throw TestError.notEqual("\(a) != \(b) at \(file):\(line)") }
}

func assertApprox(_ a: Double, _ b: Double, accuracy: Double = 0.01) throws {
    guard abs(a - b) < accuracy else { throw TestError.notEqual("\(a) !≈ \(b)") }
}

func assertNotNil<T>(_ v: T?) throws {
    guard v != nil else { throw TestError.wasNil }
}

func assertThrows<E: Error & Equatable>(_ expected: E, _ block: () throws -> Void) throws {
    do {
        try block()
        throw TestError.didNotThrow
    } catch let e as E where e == expected {
        return
    } catch {
        throw TestError.wrongError("\(error)")
    }
}

enum TestError: Error {
    case notEqual(String), wasNil, didNotThrow, wrongError(String)
}

// Tests
test("parse power plan") {
    let output = """
    │ KIRO POWER                                                                  │
    │ Credits   ██████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 14% │
    │           (1428.4 of 10000 covered in plan, resets on 03/01)                │
    """
    let usage = try KiroUsageProbe.parse(output)
    try assertEqual(usage.planName, "KIRO POWER")
    try assertEqual(usage.percent, 14)
    try assertApprox(usage.creditsUsed, 1428.4)
    try assertEqual(usage.creditsTotal, 10000)
    try assertNotNil(usage.resetsAt)
}

test("parse free plan") {
    let output = """
    │ KIRO FREE                                                                   │
    │ Credits   ████████████████████████████████████████████████████████████ 100% │
    │           (50 of 50 covered in plan, resets on 02/20)                       │
    """
    let usage = try KiroUsageProbe.parse(output)
    try assertEqual(usage.planName, "KIRO FREE")
    try assertEqual(usage.percent, 100)
    try assertEqual(usage.creditsUsed, 50)
    try assertEqual(usage.creditsTotal, 50)
}

test("parse with ANSI codes") {
    let output = "\u{1B}[32m│ KIRO POWER\u{1B}[0m\n██████ 25%\n(2500 of 10000 covered in plan, resets on 04/15)"
    let usage = try KiroUsageProbe.parse(output)
    try assertEqual(usage.percent, 25)
    try assertEqual(usage.creditsUsed, 2500)
}

test("not logged in throws") {
    let output = "Error: Not logged in. Please run kiro-cli login"
    try assertThrows(KiroProbeError.notLoggedIn) {
        _ = try KiroUsageProbe.parse(output)
    }
}

test("invalid output throws") {
    let output = "Some random text"
    do {
        _ = try KiroUsageProbe.parse(output)
        throw TestError.didNotThrow
    } catch KiroProbeError.parseFailed {
        // expected
    }
}

print("\n\(passed) passed, \(failed) failed")
exit(failed > 0 ? 1 : 0)
