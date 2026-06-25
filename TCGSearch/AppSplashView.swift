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
            theme.diagonalWash
            theme.topAmbientGlow
            theme.lowerCollectorGlow
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

    var diagonalWash: LinearGradient {
        if isBlack {
            LinearGradient(
                stops: [
                    .init(color: SplashPalette.darkWash.opacity(0.48), location: 0),
                    .init(color: SplashPalette.blackCanvas.opacity(0.08), location: 0.48),
                    .init(color: SplashPalette.collectorBlue.opacity(0.38), location: 1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        } else {
            LinearGradient(
                stops: [
                    .init(color: SplashPalette.mintWash.opacity(0.38), location: 0),
                    .init(color: SplashPalette.lightCanvas.opacity(0.04), location: 0.52),
                    .init(color: SplashPalette.blueWash.opacity(0.32), location: 1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        }
    }

    var topAmbientGlow: RadialGradient {
        if isBlack {
            RadialGradient(
                stops: [
                    .init(color: SplashPalette.sub.opacity(0.22), location: 0),
                    .init(color: SplashPalette.collectorBlue.opacity(0.08), location: 0.42),
                    .init(color: SplashPalette.blackCanvas.opacity(0), location: 1),
                ],
                center: UnitPoint(x: 0.5, y: 0.08),
                startRadius: 0,
                endRadius: 360,
            )
        } else {
            RadialGradient(
                stops: [
                    .init(color: Color.white.opacity(0.62), location: 0),
                    .init(color: SplashPalette.sub.opacity(0.12), location: 0.36),
                    .init(color: SplashPalette.lightCanvas.opacity(0), location: 1),
                ],
                center: UnitPoint(x: 0.5, y: 0.08),
                startRadius: 0,
                endRadius: 360,
            )
        }
    }

    var lowerCollectorGlow: RadialGradient {
        if isBlack {
            RadialGradient(
                stops: [
                    .init(color: SplashPalette.collectorBlue.opacity(0.14), location: 0),
                    .init(color: SplashPalette.sub.opacity(0.06), location: 0.5),
                    .init(color: SplashPalette.blackCanvas.opacity(0), location: 1),
                ],
                center: UnitPoint(x: 0.52, y: 0.92),
                startRadius: 0,
                endRadius: 420,
            )
        } else {
            RadialGradient(
                stops: [
                    .init(color: SplashPalette.collectorBlue.opacity(0.12), location: 0),
                    .init(color: SplashPalette.sub.opacity(0.06), location: 0.48),
                    .init(color: SplashPalette.lightCanvas.opacity(0), location: 1),
                ],
                center: UnitPoint(x: 0.52, y: 0.92),
                startRadius: 0,
                endRadius: 420,
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
            .shadow(color: SplashPalette.main.opacity(0.22), radius: 22, x: 0, y: 12)
            .accessibilityLabel("TCG Search")
    }
}

private enum SplashPalette {
    static let lightCanvas = Color(red: 244 / 255, green: 248 / 255, blue: 243 / 255)
    static let blackCanvas = Color(red: 7 / 255, green: 11 / 255, blue: 9 / 255)
    static let darkSurface = Color(red: 14 / 255, green: 50 / 255, blue: 37 / 255)
    static let darkWash = Color(red: 28 / 255, green: 74 / 255, blue: 54 / 255)
    static let mintWash = Color(red: 187 / 255, green: 236 / 255, blue: 211 / 255)
    static let blueWash = Color(red: 211 / 255, green: 228 / 255, blue: 255 / 255)
    static let collectorBlue = Color(red: 62 / 255, green: 131 / 255, blue: 236 / 255)
    static let main = Color(red: 31 / 255, green: 122 / 255, blue: 87 / 255)
    static let sub = Color(red: 63 / 255, green: 174 / 255, blue: 139 / 255)
    static let textPrimary = Color(red: 7 / 255, green: 11 / 255, blue: 9 / 255)
}

#Preview {
    AppSplashView()
}
