import AppKit
import Combine
import LocalAuthentication

struct ProtectedApplication: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let path: String

    var icon: NSImage { NSWorkspace.shared.icon(forFile: path) }
}

final class AppModel: ObservableObject {
    @Published private(set) var apps: [ProtectedApplication] = []
    @Published private(set) var clock = ProcessInfo.processInfo.systemUptime
    @Published private(set) var gateApp: ProtectedApplication?
    @Published private(set) var authenticating = false
    @Published private(set) var notice: String?
    @Published private(set) var gateError: String?
    @Published var unlockMinutes = 5

    var onShowGate: (() -> Void)?
    var onCloseGate: (() -> Void)?

    private var policy = LockPolicy()
    private var context: LAContext?
    private var requestID = UUID()
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?
    private var hiddenFailures = Set<String>()
    private let storageKey = "AppLatch.protectedApplications.v1"

    var unlockedCount: Int {
        apps.filter { policy.isUnlocked($0.id, now: clock) }.count
    }

    func start() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                let saved = try JSONDecoder().decode([ProtectedApplication].self, from: data)
                var seen = Set<String>()
                apps = saved.filter { seen.insert($0.id).inserted && !excluded($0.id) }
            } catch {
                notice = "The saved app list could not be read. Protection is not loaded. Add your apps again."
            }
        }

        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.didUnhideApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let running = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                self?.enforce(running, showGate: running.isActive)
            })
        }
        observers.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                                             object: nil, queue: .main) { [weak self] note in
            guard let self = self,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let id = app.bundleIdentifier else { return }
            self.policy.revoke(id)
            self.clock = ProcessInfo.processInfo.systemUptime
            if self.gateApp?.id == id { self.cancelGate() }
        })
        // Use public workspace notifications. Screen-lock detection alone is not
        // guaranteed by these APIs; this prototype does not claim otherwise.
        for name in [NSWorkspace.willSleepNotification,
                     NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification,
                     NSWorkspace.didWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.lockAll(showGate: false)
            })
        }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        lockAll(showGate: false)
    }

    deinit {
        timer?.invalidate()
        context?.invalidate()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    private func excluded(_ id: String) -> Bool {
        id == Bundle.main.bundleIdentifier || id == "com.apple.finder" || id == "com.apple.loginwindow"
    }

    func remaining(_ app: ProtectedApplication) -> Int {
        Int(ceil(policy.remaining(app.id, now: clock)))
    }

    func status(_ app: ProtectedApplication) -> String {
        if hiddenFailures.contains(app.id) { return "Could not hide — check this app" }
        let seconds = remaining(app)
        return seconds > 0 ? String(format: "Unlocked · %d:%02d", seconds / 60, seconds % 60) : "Locked"
    }

    private func persist(_ updated: [ProtectedApplication]) -> Bool {
        do {
            let data = try JSONEncoder().encode(updated)
            UserDefaults.standard.set(data, forKey: storageKey)
            apps = updated
            return true
        } catch {
            notice = "Your app list could not be saved. No changes were applied."
            return false
        }
    }

    func addApplications(_ urls: [URL]) {
        var candidates: [ProtectedApplication] = []
        var skipped = false
        for url in urls {
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier,
                  !excluded(id), url.pathExtension.lowercased() == "app" else {
                skipped = true
                continue
            }
            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            if !candidates.contains(where: { $0.id == id }) {
                candidates.append(ProtectedApplication(id: id, name: name, path: url.path))
            }
        }
        guard !candidates.isEmpty else {
            notice = "Choose a regular Mac application. AppLatch and Finder cannot be protected."
            return
        }
        authenticate(reason: "add apps to your protected list") { [weak self] in
            guard let self = self else { return }
            var updated = self.apps
            for app in candidates {
                updated.removeAll { $0.id == app.id }
                updated.append(app)
            }
            updated.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            guard self.persist(updated) else { return }
            self.notice = skipped ? "Some items were skipped. AppLatch and Finder cannot be protected." : nil
            for app in candidates {
                self.policy.revoke(app.id)
                self.hideInstances(of: app)
            }
            self.clock = ProcessInfo.processInfo.systemUptime
        }
    }

    func remove(_ app: ProtectedApplication) {
        authenticate(reason: "stop protecting \(app.name)") { [weak self] in
            guard let self = self else { return }
            guard self.persist(self.apps.filter { $0.id != app.id }) else { return }
            self.policy.revoke(app.id)
            self.hiddenFailures.remove(app.id)
            if self.gateApp?.id == app.id { self.cancelGate() }
            self.clock = ProcessInfo.processInfo.systemUptime
        }
    }

    func requestUnlock(_ app: ProtectedApplication) {
        guard apps.contains(where: { $0.id == app.id }) else { return }
        if gateApp?.id != app.id {
            cancelAuthentication()
            gateError = nil
            gateApp = app
        }
        if !authenticating { onShowGate?() }
    }

    func unlockGate() {
        guard let app = gateApp else { return }
        let duration = [1, 5, 15].contains(unlockMinutes) ? unlockMinutes : 5
        authenticate(reason: "unlock \(app.name) for \(duration) minute\(duration == 1 ? "" : "s")") { [weak self] in
            guard let self = self,
                  self.gateApp?.id == app.id,
                  self.apps.contains(where: { $0.id == app.id }) else { return }
            self.policy.grant(app.id, seconds: TimeInterval(duration * 60), now: ProcessInfo.processInfo.systemUptime)
            self.clock = ProcessInfo.processInfo.systemUptime
            self.gateApp = nil
            self.gateError = nil
            self.onCloseGate?()
            self.open(app)
        }
    }

    func lock(_ app: ProtectedApplication) {
        cancelAuthentication()
        policy.revoke(app.id)
        let wasFrontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == app.id
        hideInstances(of: app)
        clock = ProcessInfo.processInfo.systemUptime
        if wasFrontmost { requestUnlock(app) }
    }

    func lockAll(showGate: Bool = true) {
        let foregroundID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        cancelGate()
        policy.lockAll()
        for app in apps { hideInstances(of: app) }
        clock = ProcessInfo.processInfo.systemUptime
        if showGate, let app = apps.first(where: { $0.id == foregroundID }) { requestUnlock(app) }
    }

    func cancelGate() {
        cancelAuthentication()
        gateApp = nil
        gateError = nil
        onCloseGate?()
    }

    func dismissNotice() { notice = nil }

    func authenticateToQuit(_ completion: @escaping () -> Void) {
        if apps.isEmpty { completion(); return }
        authenticate(reason: "quit AppLatch and stop app protection", onSuccess: completion)
    }

    private func cancelAuthentication() {
        requestID = UUID()
        context?.invalidate()
        context = nil
        authenticating = false
    }

    private func authenticate(reason: String, onSuccess: @escaping () -> Void) {
        guard !authenticating else { return }
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        // This policy permits the Mac login password. Do NOT use the
        // biometrics-only policy: a Mac without Touch ID must be able to unlock.
        let authenticationPolicy: LAPolicy = .deviceOwnerAuthentication
        var error: NSError?
        guard context.canEvaluatePolicy(authenticationPolicy, error: &error) else {
            let message = "macOS authentication is unavailable. \(error?.localizedDescription ?? "Check your Mac login password in System Preferences.")"
            notice = message
            gateError = message
            return // No authentication means no authorization.
        }
        let ticket = UUID()
        let generation = policy.generation
        requestID = ticket
        self.context = context
        authenticating = true
        gateError = nil
        context.evaluatePolicy(authenticationPolicy, localizedReason: reason) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self, self.requestID == ticket, self.policy.generation == generation else { return }
                self.context = nil
                self.authenticating = false
                if success {
                    self.notice = nil
                    onSuccess()
                } else {
                    let code = (error as? LAError)?.code
                    if code == .userCancel || code == .appCancel || code == .systemCancel { return }
                    let message = error?.localizedDescription ?? "Authentication did not succeed. Try again."
                    self.notice = message
                    self.gateError = message
                }
            }
        }
    }

    private func enforce(_ running: NSRunningApplication, showGate: Bool) {
        guard let id = running.bundleIdentifier,
              let app = apps.first(where: { $0.id == id }),
              !policy.isUnlocked(id, now: ProcessInfo.processInfo.systemUptime) else { return }
        hideInstances(of: app)
        if showGate { requestUnlock(app) }
    }

    private func hideInstances(of app: ProtectedApplication) {
        var failed = false
        for running in NSRunningApplication.runningApplications(withBundleIdentifier: app.id) {
            if !running.isTerminated && !running.isHidden && !running.hide() { failed = true }
        }
        if failed {
            hiddenFailures.insert(app.id)
            notice = "\(app.name) did not accept the hide request. Its windows may still be visible."
        } else {
            hiddenFailures.remove(app.id)
        }
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let expired = apps.filter { policy.grants[$0.id] != nil && !policy.isUnlocked($0.id, now: now) }
        let foregroundID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        for app in expired {
            policy.revoke(app.id)
            hideInstances(of: app)
        }
        clock = now
        if let app = expired.first(where: { $0.id == foregroundID }) { requestUnlock(app) }
        // Recover if an activation notification was missed; not an OS security boundary.
        if let front = NSWorkspace.shared.frontmostApplication { enforce(front, showGate: true) }
    }

    private func open(_ app: ProtectedApplication) {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.id).first {
            running.unhide()
            if !running.activate(options: [.activateIgnoringOtherApps, .activateAllWindows]) {
                notice = "\(app.name) is unlocked. Open it from the Dock."
            }
            return
        }
        let stored = URL(fileURLWithPath: app.path)
        let url: URL
        if Bundle(url: stored)?.bundleIdentifier == app.id {
            url = stored
        } else if let found = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.id) {
            url = found
        } else {
            policy.revoke(app.id)
            notice = "\(app.name) could not be found. Add it again if you moved it."
            clock = ProcessInfo.processInfo.systemUptime
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        let launchGeneration = policy.generation
        let launchGrant = policy.grants[app.id]
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] _, error in
            guard let error = error else { return }
            DispatchQueue.main.async {
                guard let self = self,
                      self.policy.generation == launchGeneration,
                      self.policy.grants[app.id] == launchGrant else { return }
                self.policy.revoke(app.id)
                self.clock = ProcessInfo.processInfo.systemUptime
                self.notice = "Could not open \(app.name): \(error.localizedDescription)"
            }
        }
    }
}
