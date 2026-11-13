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

/// App text uses Hurmit Nerd Font Light when it is installed on this Mac, otherwise the system font.
let appFontName = "HurmitNF-Light"

func appFont(_ size: CGFloat, _ scale: CGFloat = 1) -> Font {
    let size = size * scale
    return NSFont(name: appFontName, size: size) != nil ? .custom(appFontName, size: size) : .system(size: size)
}

/// The md-glasses icon (Nerd Fonts U+F02AA, from Hurmit Nerd Font, SIL OFL 1.1),
/// stored as its outline so the app doesn't need to ship the font. Size: 97.89 × 37.50.
func glassesPath() -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 11.44, y: 29.30))
    p.addLine(to: CGPoint(x: 36.44, y: 29.30))
    p.addCurve(to: CGPoint(x: 38.34, y: 28.40), control1: CGPoint(x: 37.34, y: 29.30), control2: CGPoint(x: 37.94, y: 29.00))
    p.addCurve(to: CGPoint(x: 38.74, y: 26.60), control1: CGPoint(x: 38.74, y: 27.80), control2: CGPoint(x: 38.84, y: 27.30))
    p.addLine(to: CGPoint(x: 34.34, y: 13.30))
    p.addCurve(to: CGPoint(x: 32.04, y: 9.80), control1: CGPoint(x: 34.04, y: 12.00), control2: CGPoint(x: 33.34, y: 10.80))
    p.addCurve(to: CGPoint(x: 28.04, y: 8.40), control1: CGPoint(x: 30.74, y: 8.80), control2: CGPoint(x: 29.44, y: 8.40))
    p.addLine(to: CGPoint(x: 15.54, y: 8.40))
    p.addCurve(to: CGPoint(x: 12.14, y: 9.80), control1: CGPoint(x: 14.34, y: 8.40), control2: CGPoint(x: 13.14, y: 8.90))
    p.addCurve(to: CGPoint(x: 10.24, y: 13.30), control1: CGPoint(x: 11.14, y: 10.70), control2: CGPoint(x: 10.54, y: 11.90))
    p.addLine(to: CGPoint(x: 8.34, y: 25.60))
    p.addCurve(to: CGPoint(x: 8.94, y: 28.20), control1: CGPoint(x: 8.24, y: 26.70), control2: CGPoint(x: 8.34, y: 27.50))
    p.addCurve(to: CGPoint(x: 11.44, y: 29.30), control1: CGPoint(x: 9.54, y: 28.90), control2: CGPoint(x: 10.34, y: 29.30))
    p.closeSubpath()
    p.move(to: CGPoint(x: 28.04, y: 0.00))
    p.addCurve(to: CGPoint(x: 37.14, y: 3.20), control1: CGPoint(x: 31.34, y: 0.00), control2: CGPoint(x: 34.34, y: 1.10))
    p.addCurve(to: CGPoint(x: 42.54, y: 10.90), control1: CGPoint(x: 39.94, y: 5.30), control2: CGPoint(x: 41.74, y: 7.90))
    p.addLine(to: CGPoint(x: 46.24, y: 22.70))
    p.addCurve(to: CGPoint(x: 48.94, y: 23.40), control1: CGPoint(x: 46.94, y: 23.20), control2: CGPoint(x: 47.94, y: 23.40))
    p.addCurve(to: CGPoint(x: 51.64, y: 22.70), control1: CGPoint(x: 49.94, y: 23.40), control2: CGPoint(x: 50.84, y: 23.20))
    p.addLine(to: CGPoint(x: 55.34, y: 11.30))
    p.addCurve(to: CGPoint(x: 60.74, y: 3.30), control1: CGPoint(x: 56.14, y: 8.20), control2: CGPoint(x: 57.94, y: 5.50))
    p.addCurve(to: CGPoint(x: 69.84, y: 0.00), control1: CGPoint(x: 63.54, y: 1.10), control2: CGPoint(x: 66.54, y: 0.00))
    p.addLine(to: CGPoint(x: 82.34, y: 0.00))
    p.addCurve(to: CGPoint(x: 91.24, y: 3.40), control1: CGPoint(x: 85.64, y: 0.00), control2: CGPoint(x: 88.54, y: 1.10))
    p.addCurve(to: CGPoint(x: 95.84, y: 11.70), control1: CGPoint(x: 93.94, y: 5.70), control2: CGPoint(x: 95.44, y: 8.40))
    p.addLine(to: CGPoint(x: 97.74, y: 24.60))
    p.addCurve(to: CGPoint(x: 95.14, y: 33.70), control1: CGPoint(x: 98.24, y: 28.10), control2: CGPoint(x: 97.44, y: 31.20))
    p.addCurve(to: CGPoint(x: 86.44, y: 37.50), control1: CGPoint(x: 92.84, y: 36.20), control2: CGPoint(x: 89.94, y: 37.50))
    p.addLine(to: CGPoint(x: 61.44, y: 37.50))
    p.addCurve(to: CGPoint(x: 52.84, y: 33.60), control1: CGPoint(x: 57.74, y: 37.50), control2: CGPoint(x: 54.94, y: 36.20))
    p.addCurve(to: CGPoint(x: 51.64, y: 31.40), control1: CGPoint(x: 52.34, y: 32.90), control2: CGPoint(x: 51.94, y: 32.20))
    p.addCurve(to: CGPoint(x: 46.24, y: 31.40), control1: CGPoint(x: 49.84, y: 31.80), control2: CGPoint(x: 48.04, y: 31.80))
    p.addCurve(to: CGPoint(x: 45.04, y: 33.60), control1: CGPoint(x: 45.94, y: 32.20), control2: CGPoint(x: 45.54, y: 32.90))
    p.addCurve(to: CGPoint(x: 36.44, y: 37.50), control1: CGPoint(x: 42.94, y: 36.20), control2: CGPoint(x: 40.14, y: 37.50))
    p.addLine(to: CGPoint(x: 11.44, y: 37.50))
    p.addCurve(to: CGPoint(x: 2.74, y: 33.70), control1: CGPoint(x: 7.94, y: 37.50), control2: CGPoint(x: 5.04, y: 36.20))
    p.addCurve(to: CGPoint(x: 0.14, y: 24.40), control1: CGPoint(x: 0.44, y: 31.20), control2: CGPoint(x: -0.36, y: 28.10))
    p.addLine(to: CGPoint(x: 2.04, y: 11.90))
    p.addCurve(to: CGPoint(x: 6.54, y: 3.50), control1: CGPoint(x: 2.44, y: 8.60), control2: CGPoint(x: 3.94, y: 5.80))
    p.addCurve(to: CGPoint(x: 15.54, y: 0.00), control1: CGPoint(x: 9.14, y: 1.20), control2: CGPoint(x: 12.14, y: 0.00))
    p.closeSubpath()
    p.move(to: CGPoint(x: 61.44, y: 29.30))
    p.addLine(to: CGPoint(x: 86.44, y: 29.30))
    p.addCurve(to: CGPoint(x: 88.94, y: 28.20), control1: CGPoint(x: 87.54, y: 29.30), control2: CGPoint(x: 88.34, y: 28.90))
    p.addCurve(to: CGPoint(x: 89.54, y: 25.80), control1: CGPoint(x: 89.54, y: 27.50), control2: CGPoint(x: 89.64, y: 26.70))
    p.addLine(to: CGPoint(x: 87.44, y: 13.10))
    p.addCurve(to: CGPoint(x: 85.74, y: 9.80), control1: CGPoint(x: 87.34, y: 11.80), control2: CGPoint(x: 86.74, y: 10.70))
    p.addCurve(to: CGPoint(x: 82.34, y: 8.40), control1: CGPoint(x: 84.74, y: 8.90), control2: CGPoint(x: 83.54, y: 8.40))
    p.addLine(to: CGPoint(x: 69.84, y: 8.40))
    p.addCurve(to: CGPoint(x: 65.94, y: 10.00), control1: CGPoint(x: 68.44, y: 8.40), control2: CGPoint(x: 67.14, y: 8.90))
    p.addCurve(to: CGPoint(x: 63.44, y: 13.70), control1: CGPoint(x: 64.74, y: 11.10), control2: CGPoint(x: 63.84, y: 12.30))
    p.addLine(to: CGPoint(x: 59.14, y: 26.40))
    p.addCurve(to: CGPoint(x: 59.54, y: 28.40), control1: CGPoint(x: 59.04, y: 27.10), control2: CGPoint(x: 59.14, y: 27.80))
    p.addCurve(to: CGPoint(x: 61.44, y: 29.30), control1: CGPoint(x: 59.94, y: 29.00), control2: CGPoint(x: 60.54, y: 29.30))
    p.closeSubpath()
    return p
}

/// Draws the glasses as a template image for the menu bar: scaled to fit 22×16 pt and centered.
func menuBarIcon() -> NSImage {
    let path = glassesPath()
    let box = path.boundingBoxOfPath
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
    var scale: CGFloat = 1
    var body: some View {
        Text(text)
            .font(appFont(11, scale))
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

    /// One number that sizes all text (1.0 = default). Saved between launches;
    /// also settable from Terminal: `defaults write local.nerdrkeys textScale 1.2`
    static let scaleRange: ClosedRange<CGFloat> = 0.8...1.6
    @Published var scale: CGFloat = {
        let saved = CGFloat(UserDefaults.standard.double(forKey: "textScale"))
        return saved == 0 ? 1 : min(max(saved, Store.scaleRange.lowerBound), Store.scaleRange.upperBound)
    }() {
        didSet {
            UserDefaults.standard.set(Double(scale), forKey: "textScale")
            onResize?()
        }
    }
    var width: CGFloat { (320 * scale).rounded() }   // widen with the text so labels don't get cut off
    var onResize: (() -> Void)?

    func bumpScale(_ delta: CGFloat) {
        let next = ((scale + delta) * 10).rounded() / 10
        scale = min(max(next, Store.scaleRange.lowerBound), Store.scaleRange.upperBound)
    }

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

    private var s: CGFloat { store.scale }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("herdr shortcuts").font(appFont(14, s))
                Spacer()
                Text("prefix").font(appFont(11, s)).foregroundStyle(.secondary)
                KeyCap(text: prettyKeys(store.prefix, prefix: store.prefix)[0], scale: s)
            }
            .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 8)

            TextField("Filter…", text: $store.query)
                .textFieldStyle(.roundedBorder)
                .font(appFont(12, s))
                .padding(.horizontal, 12).padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let e = store.error { Text(e).foregroundStyle(.red).font(appFont(11, s)) }
                    ForEach(filtered) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.title.uppercased())
                                .font(appFont(10, s))
                                .foregroundStyle(.secondary)
                            ForEach(group.items) { item in
                                HStack {
                                    Text(item.label).font(appFont(12, s))
                                    Spacer()
                                    HStack(spacing: 3) {
                                        let caps = prettyKeys(item.keys, prefix: store.prefix)
                                        ForEach(caps.indices, id: \.self) { i in
                                            if i > 0 { Text("then").font(appFont(9, s)).foregroundStyle(.tertiary) }
                                            KeyCap(text: caps[i], scale: s)
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
                // Text size: A− / A+ step by 10%; click the percentage to reset.
                Button("A−") { store.bumpScale(-0.1) }
                    .disabled(s <= Store.scaleRange.lowerBound)
                    .help("Smaller text")
                Button("\(Int((s * 100).rounded()))%") { store.scale = 1 }
                    .foregroundStyle(.secondary)
                    .help("Reset text size")
                Button("A+") { store.bumpScale(0.1) }
                    .disabled(s >= Store.scaleRange.upperBound)
                    .help("Bigger text")
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .font(appFont(11, s))
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .frame(width: store.width, height: store.height)
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
        popover.contentSize = NSSize(width: store.width, height: store.height)
        store.onResize = { [weak self] in
            guard let self else { return }
            self.popover.contentSize = NSSize(width: self.store.width, height: self.store.height)
        }
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
            popover.contentSize = NSSize(width: store.width, height: store.height)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// `NerdrKeys --dump` prints what the popover would show, for debugging.
if CommandLine.arguments.contains("--dump") {
    let r = loadShortcuts()
    print("text scale: \(Store().scale)")
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
