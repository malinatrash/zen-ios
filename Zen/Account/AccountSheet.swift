import FirefoxSyncKit
import SwiftUI

// Account sheet: sync state, devices and sign-out.
struct AccountSheet: View {
    let account: AccountModel
    var onSignIn: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Sync") {
                    LabeledContent("Firefox Account", value: account.isSignedIn ? "Connected" : "Not connected")
                    LabeledContent("Zen spaces", value: spacesLabel)
                    LabeledContent("Updated", value: account.snapshot.date.formatted(date: .omitted, time: .shortened))
                    Button("Refresh Now", systemImage: "arrow.clockwise") {
                        Task { await account.refresh() }
                    }
                    .disabled(!account.isSignedIn || account.isRefreshing)
                }
                if !account.snapshot.devices.isEmpty {
                    Section("Devices") {
                        ForEach(account.snapshot.devices) { device in
                            LabeledContent {
                                Text("\(device.tabs.count)")
                            } label: {
                                Label(device.name, systemImage: device.kind == .desktop ? "laptopcomputer" : "iphone")
                            }
                        }
                    }
                }
                Section {
                    if account.isSignedIn {
                        Button("Sign Out", role: .destructive) {
                            Task { await account.signOut() }
                        }
                    } else {
                        Button("Sign In to Firefox Account") {
                            dismiss()
                            onSignIn()
                        }
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var spacesLabel: String {
        switch account.snapshot.spacesState {
        case .available: "\(account.snapshot.spaces.spaces.count)"
        case .notEnabled: "Sync is off in Zen"
        case .unsupportedVersion(let version): "Format \(version) is not supported"
        }
    }
}

#Preview("Connected") {
    AccountSheet(account: PreviewData.account)
}

#Preview("Signed out") {
    AccountSheet(account: AccountModel.signedOutPreview)
}
