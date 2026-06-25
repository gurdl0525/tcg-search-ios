import SwiftUI

struct AppSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var isLoading = false

    var body: some View {
        ZStack {
            SplashBackground(theme: theme)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                SplashLogoMark()

                Text("TCG Search")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                loadingIndicator
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            if !reduceMotion {
                isLoading = true
            }
        }
    }

    private var theme: SplashTheme {
        SplashTheme(colorScheme: colorScheme)
    }

    private var loadingIndicator: some View {
        Capsule(style: .continuous)
            .fill(theme.loadingTrack)
            .frame(width: 58, height: 2)
            .overlay(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(theme.loadingFill)
                    .frame(width: 18, height: 2)
                    .offset(x: isLoading && !reduceMotion ? 40 : 0)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.82).repeatForever(autoreverses: true),
                        value: isLoading,
                    )
            }
            .padding(.top, 2)
            .accessibilityHidden(true)
    }
}

private struct SplashBackground: View {
    let theme: SplashTheme

    var body: some View {
        ZStack {
            theme.canvas
            theme.canvasWash
        }
    }
}

private struct SplashTheme {
    let colorScheme: ColorScheme

    var isBlack: Bool {
        colorScheme == .dark
    }

    var canvas: Color {
        isBlack ? SplashPalette.blackCanvas : SplashPalette.lightCanvas
    }

    var canvasWash: LinearGradient {
        if isBlack {
            LinearGradient(
                colors: [
                    SplashPalette.blackCanvas,
                    SplashPalette.darkSurface.opacity(0.34),
                    SplashPalette.main.opacity(0.14),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        } else {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.58),
                    SplashPalette.lightCanvas,
                    SplashPalette.sub.opacity(0.14),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        }
    }

    var textPrimary: Color {
        isBlack ? .white : SplashPalette.textPrimary
    }

    var loadingTrack: Color {
        isBlack ? Color.white.opacity(0.12) : SplashPalette.main.opacity(0.12)
    }

    var loadingFill: Color {
        isBlack ? SplashPalette.sub.opacity(0.88) : SplashPalette.main.opacity(0.86)
    }
}

private struct SplashLogoMark: View {
    var body: some View {
        Image("LaunchMark")
            .resizable()
            .scaledToFit()
        .frame(width: 58, height: 58)
        .accessibilityLabel("TCG Search")
    }
}

private enum SplashPalette {
    static let lightCanvas = Color(red: 244 / 255, green: 248 / 255, blue: 243 / 255)
    static let blackCanvas = Color(red: 7 / 255, green: 11 / 255, blue: 9 / 255)
    static let darkSurface = Color(red: 14 / 255, green: 50 / 255, blue: 37 / 255)
    static let main = Color(red: 31 / 255, green: 122 / 255, blue: 87 / 255)
    static let sub = Color(red: 63 / 255, green: 174 / 255, blue: 139 / 255)
    static let textPrimary = Color(red: 7 / 255, green: 11 / 255, blue: 9 / 255)
}

#Preview {
    AppSplashView()
}
