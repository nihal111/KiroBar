# KiroBar

A minimal macOS menu bar app that displays your [Kiro](https://kiro.dev) usage.

![KiroBar Screenshot](docs/screenshot.png)

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

# Run
.build/release/KiroBar &
```

## Attribution

This project is inspired by and based on [CodexBar](https://github.com/steipete/CodexBar) by [@steipete](https://github.com/steipete). CodexBar is a comprehensive menu bar app supporting multiple AI providers. KiroBar extracts and simplifies the Kiro-specific functionality into a minimal, standalone app.

## License

MIT
