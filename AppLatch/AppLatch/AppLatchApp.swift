import AppKit
import SwiftUI

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem!
    private var mainWindow: NSWindow!
    private var gateWindow: NSWindow!
    private var summaryItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        makeMenu()
        makeWindows()
        model.onShowGate = { [weak self] in self?.showGate() }
        model.onCloseGate = { [weak self] in self?.gateWindow.orderOut(nil) }
        model.start()
        showSettings()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    private func makeWindows() {
        mainWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 570),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        mainWindow.title = "AppLatch"
        mainWindow.minSize = NSSize(width: 650, height: 500)
        mainWindow.isReleasedWhenClosed = false
        mainWindow.contentView = NSHostingView(rootView: SettingsView(model: model, addApps: { [weak self] in self?.pickApps() }))
        mainWindow.center()

        gateWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 500),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        gateWindow.title = "Unlock an app"
        gateWindow.isReleasedWhenClosed = false
        gateWindow.level = .floating
        gateWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        gateWindow.contentView = NSHostingView(rootView: UnlockView(model: model))
        gateWindow.delegate = self
        gateWindow.center()
    }

    private func makeMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "AppLatch")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = "AppLatch · App privacy controls"
        let menu = NSMenu()
        menu.delegate = self
        summaryItem = NSMenuItem(title: "AppLatch", action: nil, keyEquivalent: "")
        menu.addItem(summaryItem)
        menu.addItem(.separator())
        menu.addItem(item("Open AppLatch…", action: #selector(showSettings), key: ""))
        menu.addItem(item("Lock All Apps", action: #selector(lockAll), key: ""))
        menu.addItem(.separator())
        menu.addItem(item("Quit AppLatch…", action: #selector(requestQuit), key: ""))
        statusItem.menu = menu

        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "AppLatch")
        appMenu.addItem(item("AppLatch Settings…", action: #selector(showSettings), key: ","))
        appMenu.addItem(.separator())
        appMenu.addItem(item("Quit AppLatch…", action: #selector(requestQuit), key: "q"))
        appItem.submenu = appMenu
        main.addItem(appItem)
        NSApp.mainMenu = main
    }

    private func item(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        summaryItem.title = "\(model.apps.count) protected · \(model.unlockedCount) unlocked"
    }

    @objc private func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        mainWindow.makeKeyAndOrderFront(nil)
    }

    @objc private func lockAll() { model.lockAll() }

    @objc private func requestQuit() {
        showSettings()
        model.authenticateToQuit { NSApp.terminate(nil) }
    }

    private func showGate() {
        NSApp.activate(ignoringOtherApps: true)
        gateWindow.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === gateWindow { model.cancelGate() }
    }

    private func pickApps() {
        let panel = NSOpenPanel()
        panel.title = "Choose apps to protect"
        panel.prompt = "Add Apps"
        panel.message = "Choose one or more applications. Hold Command to select several."
        panel.allowedFileTypes = ["app"]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.beginSheetModal(for: mainWindow) { [weak self] result in
            if result == .OK { self?.model.addApplications(panel.urls) }
        }
    }
}
