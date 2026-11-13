// NerdrKeys — a tiny menu bar cheat sheet for herdr shortcuts.
// Reads ~/.config/herdr/config.toml every time it opens, so new bindings show up automatically.

import AppKit
import SwiftUI

// MARK: - Model

struct Shortcut: Identifiable {
    let id = UUID()
    let keys: String   // raw binding, e.g. "prefix+shift+c"
    let label: String
}

struct ShortcutGroup: Identifiable {
    let id = UUID()
    let title: String
    let items: [Shortcut]
}

/// herdr's built-in actions: (config name, default binding, friendly label, group).
private let builtins: [(String, String, String, String)] = [
    ("split_vertical", "prefix+v", "Split right", "Panes"),
    ("split_horizontal", "prefix+minus", "Split down", "Panes"),
    ("focus_pane_left", "prefix+h", "Focus left", "Panes"),
    ("focus_pane_down", "prefix+j", "Focus down", "Panes"),
    ("focus_pane_up", "prefix+k", "Focus up", "Panes"),
    ("focus_pane_right", "prefix+l", "Focus right", "Panes"),
    ("cycle_pane_next", "prefix+tab", "Next pane", "Panes"),
    ("zoom", "prefix+z", "Zoom pane", "Panes"),
    ("close_pane", "prefix+x", "Close pane", "Panes"),
    ("resize_mode", "prefix+r", "Resize mode", "Panes"),
    ("rename_pane", "prefix+shift+p", "Rename pane", "Panes"),
    ("edit_scrollback", "prefix+e", "Edit scrollback", "Panes"),
    ("new_tab", "prefix+c", "New tab", "Tabs"),
    ("next_tab", "prefix+n", "Next tab", "Tabs"),
    ("previous_tab", "prefix+p", "Previous tab", "Tabs"),
    ("switch_tab", "prefix+1..9", "Go to tab 1–9", "Tabs"),
    ("rename_tab", "prefix+shift+t", "Rename tab", "Tabs"),
    ("close_tab", "prefix+shift+x", "Close tab", "Tabs"),
    ("new_workspace", "prefix+shift+n", "New workspace", "Workspaces"),
    ("workspace_picker", "prefix+w", "Workspace picker", "Workspaces"),
    ("goto", "prefix+g", "Go to…", "Workspaces"),
    ("rename_workspace", "prefix+shift+w", "Rename workspace", "Workspaces"),
    ("close_workspace", "prefix+shift+d", "Close workspace", "Workspaces"),
    ("new_worktree", "prefix+shift+g", "New git worktree", "Workspaces"),
    ("next_agent", "", "Next agent", "Workspaces"),
    ("previous_agent", "", "Previous agent", "Workspaces"),
    ("toggle_sidebar", "prefix+b", "Toggle sidebar", "General"),
    ("help", "prefix+?", "Help", "General"),
    ("settings", "prefix+s", "Settings", "General"),
    ("reload_config", "prefix+shift+r", "Reload config", "General"),
    ("open_notification_target", "prefix+o", "Open notification", "General"),
    ("detach", "prefix+q", "Detach", "General"),
]

private let friendlyActions: [String: String] = [
    "ray.plugin-manager.open": "Plugin Manager",
    "persiyanov.reviewr.toggle": "reviewr (diff review)",
    "iuhoay.break-pane.break": "Break pane → new tab",
    "iuhoay.break-pane.break-to-workspace": "Break pane → new workspace",
    "iuhoay.break-pane.move-to-workspace": "Move pane → workspace",
    "hhdebb.herdr-radar.view-flip": "Radar: active ↔ recent",
    "hhdebb.herdr-radar.settings": "Radar settings",
]

private func unquote(_ raw: String) -> String {
    let s = raw.trimmingCharacters(in: .whitespaces)
    guard let q = s.first, q == "\"" || q == "'" else {
        // Unquoted value: drop any trailing comment.
        return s.components(separatedBy: "#").first!.trimmingCharacters(in: .whitespaces)
    }
    let rest = s.dropFirst()
    if let end = rest.firstIndex(of: q) { return String(rest[..<end]) }
    return String(rest)
}

/// Very small TOML reader: only what we need from herdr's config.
func loadShortcuts() -> (prefix: String, groups: [ShortcutGroup], error: String?) {
    let path = ProcessInfo.processInfo.environment["HERDR_CONFIG_PATH"]
        ?? (NSHomeDirectory() + "/.config/herdr/config.toml")
    let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""

    var section = ""
    var overrides: [String: String] = [:]
    var custom: [[String: String]] = []

    for rawLine in text.components(separatedBy: .newlines) {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.hasPrefix("#") { continue }
        if line.hasPrefix("[") {
            section = line.trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
            if line.hasPrefix("[[") && section == "keys.command" { custom.append([:]) }
            continue
        }
        guard let eq = line.firstIndex(of: "=") else { continue }
        let key = line[..<eq].trimmingCharacters(in: .whitespaces)
        let value = unquote(String(line[line.index(after: eq)...]))
        if section == "keys" { overrides[key] = value }
        else if section == "keys.command", !custom.isEmpty { custom[custom.count - 1][key] = value }
    }

    let prefix = overrides["prefix"] ?? "ctrl+b"

    var mine: [Shortcut] = []
    for c in custom {
        guard let k = c["key"], !k.isEmpty else { continue }
        let cmd = c["command"] ?? ""
        let label = friendlyActions[cmd]
            ?? c["description"].map { $0.prefix(1).uppercased() + $0.dropFirst() }
            ?? cmd
        mine.append(Shortcut(keys: k, label: label))
    }

    var grouped: [(String, [Shortcut])] = []
    for (name, def, label, group) in builtins {
        let binding = overrides[name] ?? def
        if binding.isEmpty { continue }
        if let i = grouped.firstIndex(where: { $0.0 == group }) {
            grouped[i].1.append(Shortcut(keys: binding, label: label))
        } else {
            grouped.append((group, [Shortcut(keys: binding, label: label)]))
        }
    }

    var groups: [ShortcutGroup] = []
    if !mine.isEmpty { groups.append(ShortcutGroup(title: "Your shortcuts", items: mine)) }
    groups += grouped.map { ShortcutGroup(title: $0.0, items: $0.1) }
    return (prefix, groups, text.isEmpty ? "Couldn't read \(path)" : nil)
}

/// "prefix+shift+c" -> ["⌃B", "⇧C"]: the prefix chord, then the key.
func prettyKeys(_ binding: String, prefix: String) -> [String] {
    func chord(_ s: String) -> String {
        let symbols: [String: String] = [
            "ctrl": "⌃", "shift": "⇧", "alt": "⌥", "option": "⌥", "cmd": "⌘", "super": "⌘",
            "minus": "-", "comma": ",", "tab": "⇥", "enter": "↩", "esc": "esc",
            "left": "←", "right": "→", "up": "↑", "down": "↓", "space": "space",
        ]
        return s.split(separator: "+").map { part -> String in
            let p = String(part).lowercased()
            if let sym = symbols[p] { return sym }
            return p.count == 1 ? p.uppercased() : p
        }.joined()
    }
    var parts = binding.components(separatedBy: "+")
    if parts.first?.lowercased() == "prefix" {
        parts.removeFirst()
        return [chord(prefix), chord(parts.joined(separator: "+"))]
    }
    return [chord(binding)]
}

// MARK: - Font & icon

/// Hurmit Nerd Font Light, bundled in the app (Contents/Resources/Fonts) and also used if installed.
let appFontName = "HurmitNF-Light"

func appFont(_ size: CGFloat) -> Font {
    NSFont(name: appFontName, size: size) != nil ? .custom(appFontName, size: size) : .system(size: size)
}

/// Draws one Nerd Font glyph (default U+F02AA, md-glasses) as a template image for the menu bar.
/// Falls back to the SF Symbol keyboard if the font or glyph isn't available.
func menuBarIcon(codepoint: UInt32 = 0xF02AA) -> NSImage? {
    guard let font = NSFont(name: appFontName, size: 16),
          let scalar = UnicodeScalar(codepoint) else {
        return NSImage(systemSymbolName: "keyboard", accessibilityDescription: "herdr shortcuts")
    }
    let glyph = String(scalar)
    var ids = [CGGlyph](repeating: 0, count: 2)
    let utf16 = Array(glyph.utf16)
    guard CTFontGetGlyphsForCharacters(font as CTFont, utf16, &ids, utf16.count) else {
        return NSImage(systemSymbolName: "keyboard", accessibilityDescription: "herdr shortcuts")
    }
    // Use the glyph's exact outline so it can be scaled and centered precisely,
    // instead of relying on the font's line metrics (which left it small and high).
    guard let path = CTFontCreatePathForGlyph(font as CTFont, ids[0], nil) else {
        return NSImage(systemSymbolName: "keyboard", accessibilityDescription: "herdr shortcuts")
    }
    let box = path.boundingBoxOfPath
    // Canvas matches a standard menu bar icon; the glyph fills up to 22×16 pt of it,
    // which lines up with the visual size of the system icons next to it.
    let canvas = NSSize(width: 24, height: 22)
    let maxW: CGFloat = 22, maxH: CGFloat = 16
    let scale = min(maxW / box.width, maxH / box.height)
    let image = NSImage(size: canvas, flipped: false) { rect in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
        ctx.translateBy(x: (rect.width - box.width * scale) / 2,
                        y: (rect.height - box.height * scale) / 2)
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -box.minX, y: -box.minY)
        ctx.addPath(path)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fillPath()
        return true
    }
    image.isTemplate = true   // macOS tints it to match the menu bar (light or dark)
    image.accessibilityDescription = "herdr shortcuts"
    return image
}

// MARK: - View

struct KeyCap: View {
    let text: String
    var body: some View {
        Text(text)
            .font(appFont(11))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.15)))
    }
}

final class Store: ObservableObject {
    @Published var prefix = "ctrl+b"
    @Published var groups: [ShortcutGroup] = []
    @Published var error: String?
    @Published var query = ""
    @Published var height: CGFloat = 460
    func reload() { (prefix, groups, error) = loadShortcuts() }
}

struct CheatSheet: View {
    @ObservedObject var store: Store

    private var filtered: [ShortcutGroup] {
        guard !store.query.isEmpty else { return store.groups }
        return store.groups.compactMap { g in
            let items = g.items.filter { $0.label.localizedCaseInsensitiveContains(store.query) }
            return items.isEmpty ? nil : ShortcutGroup(title: g.title, items: items)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("herdr shortcuts").font(appFont(14))
                Spacer()
                Text("prefix").font(appFont(11)).foregroundStyle(.secondary)
                KeyCap(text: prettyKeys(store.prefix, prefix: store.prefix)[0])
            }
            .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 8)

            TextField("Filter…", text: $store.query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12).padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let e = store.error { Text(e).foregroundStyle(.red).font(appFont(11)) }
                    ForEach(filtered) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.title.uppercased())
                                .font(appFont(10))
                                .foregroundStyle(.secondary)
                            ForEach(group.items) { item in
                                HStack {
                                    Text(item.label).font(appFont(12))
                                    Spacer()
                                    HStack(spacing: 3) {
                                        let caps = prettyKeys(item.keys, prefix: store.prefix)
                                        ForEach(caps.indices, id: \.self) { i in
                                            if i > 0 { Text("then").font(appFont(9)).foregroundStyle(.tertiary) }
                                            KeyCap(text: caps[i])
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(12)
            }

            Divider()

            HStack {
                Button("Edit config") {
                    let path = NSHomeDirectory() + "/.config/herdr/config.toml"
                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .font(appFont(11))
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .frame(width: 320, height: store.height)
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let store = Store()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = menuBarIcon()
            button.action = #selector(toggle)
            button.target = self
        }
        popover.behavior = .transient
        popover.animates = false
        let host = NSHostingController(rootView: CheatSheet(store: store))
        host.sizingOptions = []   // keep the popover the size we set, so it stays anchored under the icon
        popover.contentViewController = host
        popover.contentSize = NSSize(width: 320, height: store.height)
    }

    @objc private func toggle() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            store.reload()
            // Fit below the menu bar: never taller than the space under it, minus a gap.
            let visible = button.window?.screen?.visibleFrame.height ?? 800
            store.height = min(460, visible - 40)
            popover.contentSize = NSSize(width: 320, height: store.height)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// `NerdrKeys --dump` prints what the popover would show, for debugging.
if CommandLine.arguments.contains("--dump") {
    let r = loadShortcuts()
    if let e = r.error { print("error:", e) }
    for g in r.groups {
        print("\n" + g.title)
        for s in g.items { print("  \(prettyKeys(s.keys, prefix: r.prefix).joined(separator: " then "))\t\(s.label)") }
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
