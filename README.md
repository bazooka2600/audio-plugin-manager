# Plugin Manager for macOS

A native macOS application built with Swift and SwiftUI for managing audio plugins (VST, VST2, VST3, AU, CLAP) on Apple Silicon machines.

## Features

- **Plugin Discovery**: Automatically scans all standard macOS plugin directories to find installed plugins
- **Multi-Format Support**: Detects and displays VST, VST2, VST3, AU (Audio Units), and CLAP plugins
- **Plugin Removal**: Safely remove plugins with options to:
  - Move to Trash (recoverable)
  - Permanent delete
- **Backup Functionality**: Backup selected plugins to any destination folder
- **Multi-Format Detection**: View plugins that are installed in multiple formats
- **Advanced Filtering**: Filter by plugin format, search by name, and sort by various criteria
- **Detailed Information**: View plugin details including manufacturer, version, size, and file locations

## Project Structure

```
PluginManager/
├── PluginManagerApp.swift          # Main app entry point
├── Models/
│   └── Plugin.swift                # Plugin data model
├── Services/
│   ├── PluginScanner.swift         # Plugin discovery service
│   └── PluginManager.swift         # Removal and backup operations
├── Views/
│   ├── ContentView.swift           # Main UI with tabs
│   ├── PluginListView.swift        # Plugin list view
│   ├── MultiFormatView.swift       # Multi-format plugin view
│   └── BackupView.swift            # Backup functionality
├── Resources/
│   ├── Info.plist                  # App configuration
│   └── PluginManager.entitlements  # Sandbox entitlements
```

## Setup Instructions

### Prerequisites

- macOS 12.0 (Monterey) or later
- Xcode 14.0 or later
- Apple Silicon (M1/M2/M3) Mac

### Creating the Xcode Project

1. Open Xcode
2. Select **File > New > Project**
3. Choose **macOS > App**
4. Enter the following details:
   - Product Name: `PluginManager`
   - Team: Select your development team
   - Organization Identifier: `com.yourcompany`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None**
5. Save the project to: `/Users/admin/Downloads/macos-plugin-mgr/PluginManager`

### Adding Files to Xcode

1. Delete the default `ContentView.swift` created by Xcode
2. In Xcode's Project Navigator, create the following groups:
   - `Models`
   - `Services`
   - `Views`
   - `Resources`
3. Add the Swift files to their respective groups:
   - **Models**: `Plugin.swift`
   - **Services**: `PluginScanner.swift`, `PluginManager.swift`
   - **Views**: `ContentView.swift`, `PluginListView.swift`, `MultiFormatView.swift`, `BackupView.swift`
   - **Root**: `PluginManagerApp.swift` (replace the App file)

4. Add the resource files:
   - Replace `Info.plist` with the provided one
   - Add `PluginManager.entitlements` to the project

### Project Settings

1. Select the project in the Navigator
2. Choose the `PluginManager` target
3. **General** tab:
   - Bundle Identifier: `com.yourcompany.PluginManager`
   - Version: `1.0`
   - Build: `1`
4. **Signing & Capabilities** tab:
   - Team: Select your development team
   - Enable **App Sandbox**
   - Add the following entitlements (or use the provided entitlements file):
     - Outgoing Connections (Client)
     - File Access (User Selected Files)
     - File Access (Downloads Folder)
5. **Build Settings** tab:
   - Deployment Target: macOS 12.0

## Building the App

1. Select **My Mac** as the destination
2. Press **Cmd + R** or click the **Run** button
3. Grant any necessary permissions when prompted

## Usage

### Scanning for Plugins

1. Launch the app
2. Click the **Scan** button in the header
3. The app will search all standard plugin directories:
   - `/Library/Audio/Plug-Ins/VST`
   - `/Library/Audio/Plug-Ins/VST3`
   - `/Library/Audio/Plug-Ins/Components`
   - `/Library/Audio/Plug-Ins/CLAP`
   - `~/Library/Audio/Plug-Ins/` (all formats)
   - `/System/Library/Audio/Plug-Ins/` (all formats)

### Removing Plugins

1. Select plugins by clicking the checkbox next to each plugin
2. Click **Remove Selected** in the footer
3. Choose an option:
   - **Move to Trash**: Plugins are moved to Trash and can be recovered
   - **Delete Permanently**: Plugins are permanently removed from your system

### Backing Up Plugins

1. Navigate to the **Backup** tab
2. Select plugins you want to backup
3. Click **Backup Selected** in the footer
4. Choose a destination folder
5. The app will create a timestamped backup folder with all selected plugins

### Multi-Format Plugins

1. Navigate to the **Multi-Format** tab
2. View all plugins that have multiple formats installed (e.g., VST3 + AU)
3. Click on a plugin to expand and see which formats are installed and their locations

## Permissions

The app requires the following permissions:

- **File System Access**: To scan plugin directories and manage plugin files
- **Trash Access**: To move plugins to Trash
- **Write Access**: To create backup files and remove plugins

## Security

The app uses Apple's App Sandbox for security. All file operations are performed within the sandbox constraints, and the app only accesses plugin directories with your explicit permission.

## Troubleshooting

### Plugins Not Found

- Ensure plugins are installed in standard directories
- Check that you have granted necessary file system permissions
- Try running the scan again with **Refresh**

### Removal Fails

- Make sure the app has necessary permissions
- Some plugins in `/System/Library/` may be protected by SIP (System Integrity Protection)
- Try using "Move to Trash" instead of permanent delete

### Backup Fails

- Ensure you have write permissions to the destination folder
- Check available disk space
- Make sure the destination path is accessible

## License

This project is provided as-is for managing your audio plugin collection.

## Future Enhancements

Potential features for future versions:

- Plugin validation and integrity checking
- Plugin metadata editing
- Batch operations on plugin formats
- Plugin database with online lookup
- Import/export plugin lists
- Plugin conflict detection
- Plugin version history tracking
