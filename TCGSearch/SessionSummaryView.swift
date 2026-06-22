import SwiftUI

struct SessionSummaryView: View {
    @EnvironmentObject private var session: AuthSession

    var body: some View {
        Form {
            Section("Session") {
                LabeledContent("Token Type", value: session.tokenPair?.tokenType ?? "-")
                LabeledContent("Expires In", value: "\(session.tokenPair?.expiresIn ?? 0)s")

                if let accessToken = session.tokenPair?.accessToken {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Access Token")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(accessToken.prefix(32) + "...")
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }

            if let errorMessage = session.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await session.refresh() }
                } label: {
                    Label("Refresh Token", systemImage: "arrow.clockwise")
                }
                .disabled(session.isRequestInFlight)

                Button(role: .destructive) {
                    Task { await session.logout() }
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .disabled(session.isRequestInFlight)
            }
        }
    }
}
