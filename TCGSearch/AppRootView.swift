import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var session: AuthSession

    var body: some View {
        NavigationStack {
            Group {
                if session.isSignedIn {
                    SessionSummaryView()
                } else {
                    AuthView()
                }
            }
            .navigationTitle("TCG Search")
        }
        .task {
            session.restore()
        }
    }
}
