import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var session: AuthSession

    var body: some View {
        NavigationStack {
            if session.isSignedIn {
                SessionSummaryView()
                    .navigationTitle("세션")
            } else {
                AuthView()
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        .task {
            session.restore()
        }
    }
}
