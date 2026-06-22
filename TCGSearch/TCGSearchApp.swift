import SwiftUI

@main
struct TCGSearchApp: App {
    @StateObject private var session: AuthSession

    init() {
        let client = AuthClient(baseURL: AppConfiguration.apiBaseURL)
        _session = StateObject(wrappedValue: AuthSession(api: client))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(session)
        }
    }
}
