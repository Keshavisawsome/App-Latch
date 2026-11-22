import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var model: AppModel
    let addApps: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 34)).foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text("AppLatch").font(.system(size: 25, weight: .bold))
                    Text("A little more privacy for your Mac.").foregroundColor(.secondary)
                }
                Spacer()
                Button("Lock All Now") { model.lockAll() }.disabled(model.apps.isEmpty)
            }.padding(24)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "key.fill").foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Mac login password works here.").font(.headline)
                    Text("macOS handles authentication. Touch ID is optional; AppLatch never receives your password.")
                        .font(.callout).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.08)).cornerRadius(10)
            .padding(.horizontal, 24).padding(.bottom, 20)

            HStack {
                Text("Protected apps").font(.headline)
                Text("\(model.apps.count)").foregroundColor(.secondary)
                Spacer()
                if model.authenticating { ProgressView().scaleEffect(0.65).frame(width: 20, height: 20) }
                Button(action: addApps) { Label("Add Apps…", systemImage: "plus") }
                    .disabled(model.authenticating)
            }.padding(.horizontal, 24).padding(.bottom, 10)

            if model.apps.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "app.badge").font(.system(size: 35)).foregroundColor(.secondary)
                    Text("Choose your first app").font(.headline)
                    Text("Start with a simple app to try password unlocking.").foregroundColor(.secondary)
                    Button("Add Apps…", action: addApps).disabled(model.authenticating)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.apps) { app in
                            appRow(app)
                            Divider().padding(.leading, 60)
                        }
                    }.padding(.horizontal, 24)
                }
            }

            if let notice = model.notice {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                    Text(notice).font(.callout).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button(action: model.dismissNotice) { Image(systemName: "xmark") }
                        .buttonStyle(PlainButtonStyle()).accessibilityLabel("Dismiss notice")
                }
                .foregroundColor(.orange).padding(12).background(Color.orange.opacity(0.08))
                .cornerRadius(8).padding(.horizontal, 24).padding(.top, 10)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Keep AppLatch running in the menu bar.").font(.callout).fontWeight(.medium)
                Text("This is a privacy barrier. App windows may briefly appear; force-quitting AppLatch bypasses it. App data and notifications stay accessible.")
                    .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(24)
        }
        .frame(minWidth: 650, minHeight: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func appRow(_ app: ProtectedApplication) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: app.icon).resizable().frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name).fontWeight(.medium).lineLimit(1)
                Text(model.status(app)).font(.caption).foregroundColor(.secondary)
            }
            Spacer(minLength: 8)
            if model.remaining(app) > 0 {
                Button("Lock Now") { model.lock(app) }
            } else {
                Button("Unlock…") { model.requestUnlock(app) }.disabled(model.authenticating)
            }
            Button(action: { model.remove(app) }) { Image(systemName: "minus.circle") }
                .buttonStyle(BorderlessButtonStyle()).disabled(model.authenticating)
                .help("Remove protection; requires authentication")
                .accessibilityLabel("Stop protecting \(app.name)")
        }.padding(.vertical, 12)
    }
}

struct UnlockView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 15) {
            if let app = model.gateApp {
                Image(nsImage: app.icon).resizable().frame(width: 56, height: 56)
                Text("Unlock \(app.name)")
                    .font(.system(size: 22, weight: .semibold)).lineLimit(2).multilineTextAlignment(.center)
                Text("Use your Mac login password. Touch ID is optional on supported Macs.")
                    .font(.callout).foregroundColor(.secondary).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 7) {
                    Text("Unlock for").font(.caption).foregroundColor(.secondary)
                    Picker("Unlock duration", selection: $model.unlockMinutes) {
                        Text("1 minute").tag(1)
                        Text("5 minutes").tag(5)
                        Text("15 minutes").tag(15)
                    }.pickerStyle(SegmentedPickerStyle()).labelsHidden().disabled(model.authenticating)
                }

                if let error = model.gateError {
                    Text(error).font(.caption).foregroundColor(.orange).lineLimit(3)
                }

                HStack {
                    Button("Cancel") { model.cancelGate() }.keyboardShortcut(.cancelAction)
                    Spacer()
                    if model.authenticating { ProgressView().scaleEffect(0.65).frame(width: 20, height: 20) }
                    Button(model.authenticating ? "Authenticating…" : "Unlock") { model.unlockGate() }
                        .keyboardShortcut(.defaultAction).disabled(model.authenticating)
                }.padding(.top, 3)
                Text("Your password is entered only in the macOS system prompt.")
                    .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
        }.padding(28).frame(width: 420, height: 500)
    }
}
