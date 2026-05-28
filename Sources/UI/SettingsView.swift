import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(0)

            BehaviorSettingsView()
                .tabItem {
                    Label("Behavior", systemImage: "gearshape")
                }
                .tag(1)

            ShortcutSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag(2)

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(3)
        }
        .frame(width: 480, height: 400)
        .padding()
    }
}

struct AppearanceSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section(header: Text("Window Size")) {
                HStack {
                    Text("Width:")
                    Slider(value: $settings.thumbnailSize.width, in: 150...500, step: 10)
                    Text("\(Int(settings.thumbnailSize.width))")
                        .frame(width: 40)
                }

                HStack {
                    Text("Height:")
                    Slider(value: $settings.thumbnailSize.height, in: 100...400, step: 10)
                    Text("\(Int(settings.thumbnailSize.height))")
                        .frame(width: 40)
                }
            }

            Section(header: Text("Layout")) {
                Stepper("Max columns: \(settings.maxColumns)", value: $settings.maxColumns, in: 2...10)
                Toggle("Show window titles", isOn: $settings.showWindowTitles)
            }

            Section(header: Text("Theme")) {
                HStack {
                    Text("Background color:")
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: { Color(nsColor: settings.backgroundColor) },
                        set: { settings.backgroundColor = NSColor($0) }
                    ))
                }

                HStack {
                    Text("Selection border:")
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: { Color(nsColor: settings.borderColor) },
                        set: { settings.borderColor = NSColor($0) }
                    ))
                }

                HStack {
                    Text("Corner radius:")
                    Slider(value: $settings.cornerRadius, in: 0...30, step: 1)
                    Text("\(Int(settings.cornerRadius))")
                        .frame(width: 30)
                }
            }

            Section {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
            }
        }
    }
}

struct BehaviorSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section(header: Text("Window List")) {
                Toggle("Hide PurelyTab from list", isOn: $settings.hideSelfFromList)
                Toggle("Show minimized windows", isOn: $settings.showMinimizedWindows)
                Toggle("Show hidden windows", isOn: $settings.showHiddenWindows)
            }

            Section(header: Text("Language")) {
                Picker("Interface Language", selection: $settings.language) {
                    Text("Auto (System)").tag("auto")
                    Text("English").tag("en")
                    Text("中文").tag("zh")
                }
                .pickerStyle(.radioGroup)
            }
        }
    }
}

struct ShortcutSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Keyboard Shortcuts")
                .font(.headline)

            Text("PurelyTab uses the standard Cmd+Tab shortcut to show the window switcher.")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("Navigation:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Text("⌘ + Tab")
                    Spacer()
                    Text("Open window switcher, cycle forward")
                }

                HStack {
                    Text("⌘ + Shift + Tab")
                    Spacer()
                    Text("Cycle backward")
                }

                HStack {
                    Text("← → ↑ ↓")
                    Spacer()
                    Text("Navigate between windows")
                }

                HStack {
                    Text("Return or release ⌘")
                    Spacer()
                    Text("Select window")
                }

                HStack {
                    Text("Esc")
                    Spacer()
                    Text("Cancel")
                }
            }
            .font(.system(size: 12))

            Spacer()
        }
        .padding()
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("PurelyTab")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .foregroundColor(.secondary)

            Text("A fast and beautiful window switcher for macOS")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Spacer()

            VStack(spacing: 10) {
                Link("GitHub Repository", destination: URL(string: "https://github.com/dengshenkk/purelyTab")!)
                Link("Report an Issue", destination: URL(string: "https://github.com/dengshenkk/purelyTab/issues")!)
            }

            Text("© 2024 PurelyTab. All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}