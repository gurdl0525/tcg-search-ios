import SwiftUI

struct AppRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var session: AuthSession
    @State private var isShowingSplash = true

    var body: some View {
        Group {
            if isShowingSplash {
                AppSplashView()
                    .transition(.opacity.combined(with: .scale(scale: 1.015)))
            } else {
                appContent
                    .transition(.opacity)
            }
        }
        .task {
            guard isShowingSplash else {
                return
            }

            session.restore()

            if !reduceMotion {
                try? await Task.sleep(nanoseconds: 950_000_000)
            }

            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.28)) {
                isShowingSplash = false
            }
        }
    }

    private var appContent: some View {
        NavigationStack {
            if session.isSignedIn {
                SessionSummaryView()
                    .navigationTitle("세션")
            } else {
                AuthView()
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
    }
}
