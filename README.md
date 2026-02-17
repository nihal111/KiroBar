# KiroBar

A minimal macOS menu bar app that displays your [Kiro](https://kiro.dev) usage.

<p align="center">
  <img src="docs/screenshot.png" alt="KiroBar Screenshot">
</p>

## Features

- Shows Kiro credits usage percentage in the menu bar
- Displays plan name, credits used/total, and reset date
- Auto-refreshes every 5 minutes
- Native macOS popover UI with progress bar

## Requirements

- macOS 13+
- `kiro-cli` installed and logged in

## Installation

```bash
# Clone and build
git clone https://github.com/user/KiroBar.git
cd KiroBar
swift build -c release

# Copy to a permanent location
sudo cp .build/release/KiroBar /usr/local/bin/

# Run
/usr/local/bin/KiroBar &
```

To launch automatically on login, click the menu bar icon → Settings → enable "Launch at login".

## How it works

- **Usage check**: Runs `kiro-cli chat --no-interactive "/usage"` and parses the output
- **Launch at login**: Creates a LaunchAgent at `~/Library/LaunchAgents/com.kirobar.app.plist`

## Attribution

This project is inspired by and based on [CodexBar](https://github.com/steipete/CodexBar) by [@steipete](https://github.com/steipete). CodexBar is a comprehensive menu bar app supporting multiple AI providers. KiroBar extracts and simplifies the Kiro-specific functionality into a minimal, standalone app.

## License

MIT
