# PurelyTab

<div align="center">
  <img src="Resources/AppIcon.png" alt="PurelyTab Logo" width="128" height="128">

  <h3>A fast and beautiful window switcher for macOS</h3>

  <p>
    <a href="#features">Features</a> •
    <a href="#installation">Installation</a> •
    <a href="#usage">Usage</a> •
    <a href="#development">Development</a> •
    <a href="#license">License</a>
  </p>

  <p>
    <img src="https://img.shields.io/badge/platform-macOS%2011%2B-blue" alt="Platform">
    <img src="https://img.shields.io/badge/Swift-5.5-orange" alt="Swift">
    <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
  </p>
</div>

---

## Features

🚀 **Fast & Lightweight**
- Instant window switching with minimal resource usage
- Optimized for performance on all Mac devices
- Native Swift implementation for maximum efficiency

🎨 **Beautiful Interface**
- Modern, translucent design that adapts to your desktop
- Smooth animations and transitions
- Customizable appearance with multiple themes

⌨️ **Intuitive Shortcuts**
- Uses familiar Cmd+Tab shortcut
- Navigate with arrow keys or Tab
- Quick selection with number keys

🖥️ **Multi-Monitor Support**
- Works seamlessly across multiple displays
- Shows windows from all screens
- Smart positioning based on active monitor

🌍 **Internationalization**
- English and Chinese interface
- Auto-detects system language
- Easy to add more languages

🔧 **Customizable**
- Adjust thumbnail size
- Choose your preferred theme colors
- Configure behavior settings

🔄 **Auto-Update**
- Built-in update mechanism
- Stay current with the latest features
- One-click update installation

## Installation

### Download
Download the latest release from [GitHub Releases](https://github.com/dengshenkk/purelyTab/releases).

### Requirements
- macOS 11.0 (Big Sur) or later
- Intel or Apple Silicon Mac

### Install
1. Open the downloaded DMG file
2. Drag PurelyTab to your Applications folder
3. Launch PurelyTab
4. Grant necessary permissions when prompted

## Usage

### Basic Controls

| Shortcut | Action |
|----------|--------|
| `⌘ Tab` | Open window switcher |
| `⌘ Shift Tab` | Cycle backwards |
| `← → ↑ ↓` | Navigate between windows |
| `Return` | Select window |
| `Esc` | Cancel selection |

### Settings

Click the menu bar icon to access:
- **Show All Windows**: Open the window switcher
- **Settings**: Customize appearance and behavior
- **Check for Updates**: Update to the latest version
- **Quit**: Close PurelyTab

### Customization

In Settings, you can:
- Adjust window thumbnail size
- Set maximum columns
- Choose background and selection colors
- Configure corner radius
- Select interface language

## Development

### Prerequisites
- Xcode 14.0 or later
- Swift 5.5 or later
- macOS 11.0 or later

### Build from Source

```bash
# Clone the repository
git clone https://github.com/dengshenkk/purelyTab.git
cd purelyTab

# Build the project
./build.sh release

# The app will be in build/PurelyTab.app
```

### Project Structure

```
purelyTab/
├── Sources/
│   ├── PurelyTabApp.swift      # App entry point
│   ├── AppDelegate.swift       # Main application delegate
│   ├── WindowManager.swift     # Window enumeration and management
│   ├── HotkeyManager.swift     # Keyboard shortcut handling
│   ├── SettingsManager.swift   # User preferences
│   └── UI/
│       ├── WindowSwitcherView.swift  # Main UI
│       └── SettingsView.swift        # Settings window
├── Resources/
│   ├── Info.plist              # App configuration
│   ├── Entitlements.plist      # App entitlements
│   ├── en.lproj/               # English localization
│   └── zh_CN.lproj/            # Chinese localization
├── Package.swift               # Swift package manifest
├── build.sh                    # Build script
└── README.md                   # This file
```

### Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Release

For maintainers, please follow the [Release Guide](RELEASE.md) when publishing new versions.

## Roadmap

- [ ] Window search functionality
- [ ] Custom keyboard shortcut configuration
- [ ] Window grouping by application
- [ ] Virtual desktop support
- [ ] Plugin system for extensions

## Known Issues

See [Issues](https://github.com/dengshenkk/purelyTab/issues) for current known issues.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by [AltTab](https://github.com/lwouis/alt-tab-macos)
- Uses [Sparkle](https://sparkle-project.org/) for auto-updates
- Icons from SF Symbols

## Support

- 🐛 [Report a Bug](https://github.com/dengshenkk/purelyTab/issues/new?labels=bug)
- 💡 [Request a Feature](https://github.com/dengshenkk/purelyTab/issues/new?labels=enhancement)
- 💬 [Discussions](https://github.com/dengshenkk/purelyTab/discussions)

---

<div align="center">
  <p>Made with ❤️ for macOS</p>
</div>
