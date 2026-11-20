import FirefoxSyncKit
import SwiftUI

// Sign-in sheet: the Mozilla page and a cancel button.
struct LoginSheet: View {
    let account: AccountModel
    @Environment(\.dismiss) private var dismiss
    @State private var attempt: LoginAttempt?
    @State private var isFinishing = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Firefox Account")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
        .onAppear { attempt = attempt ?? account.beginLogin() }
    }

    @ViewBuilder private var content: some View {
        if isFinishing {
            ProgressView("Fetching your tabs")
        } else if let attempt {
            LoginWebView(url: attempt.url) { code, state in
                isFinishing = true
                Task {
                    await account.finishLogin(attempt, code: code, state: state)
                    dismiss()
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

#Preview("Finishing sign-in") {
    NavigationStack {
        ProgressView("Fetching your tabs")
            .navigationTitle("Firefox Account")
            .navigationBarTitleDisplayMode(.inline)
    }
}
