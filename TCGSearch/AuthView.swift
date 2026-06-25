import SwiftUI
import UIKit

struct AuthView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var session: AuthSession

    @State private var mode = AuthMode.login
    @State private var id = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var didAttemptSubmit = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var deviceId: String
    @FocusState private var focusedField: AuthField?

    @MainActor
    init() {
        _deviceId = State(initialValue: DeviceIdentifier.current)
    }

    var body: some View {
        let theme = AuthTheme(colorScheme: colorScheme)

        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: AuthMetrics.brandToCardSpacing) {
                        serviceHeader(theme: theme)
                        authCard(theme: theme)
                    }
                        .frame(width: min(AuthMetrics.cardWidth, max(0, proxy.size.width - AuthMetrics.horizontalMargin * 2)))
                        .padding(.top, contentTopPadding(in: proxy))
                        .padding(.bottom, contentBottomPadding(in: proxy))
                        .frame(maxWidth: .infinity, alignment: .top)
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .background {
                AuthBackground(theme: theme)
                    .ignoresSafeArea()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if !didAttemptSubmit {
                session.errorMessage = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) {
            updateKeyboardHeight(from: $0)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(AuthMetrics.keyboardAnimation) {
                keyboardHeight = 0
            }
        }
        .onChange(of: mode) {
            didAttemptSubmit = false
            session.errorMessage = nil
            focusedField = .id
        }
        .onChange(of: id) {
            session.errorMessage = nil
        }
        .onChange(of: password) {
            session.errorMessage = nil
        }
    }

    private func serviceHeader(theme: AuthTheme) -> some View {
        VStack(spacing: 12) {
            BrandMark()

            Text("TCG Search")
                .authFont(size: 34, weight: .bold)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)
    }

    private func authCard(theme: AuthTheme) -> some View {
        VStack(alignment: .leading, spacing: AuthMetrics.formSpacing) {
            cardHeader(theme: theme)

            AuthTextField(
                title: "아이디",
                text: $id,
                prompt: mode == .login ? "collector_001" : "new_collector",
                keyboardType: .asciiCapable,
                textContentType: .username,
                helperMessage: idHelperMessage,
                validationMessage: idValidationMessage,
                isFocused: focusedField == .id,
                theme: theme,
            )
            .focused($focusedField, equals: .id)
            .submitLabel(.next)
            .onSubmit {
                focusedField = .password
            }

            AuthPasswordField(
                password: $password,
                isPasswordVisible: $isPasswordVisible,
                validationMessage: passwordMessage,
                isFocused: focusedField == .password,
                theme: theme,
            )
            .focused($focusedField, equals: .password)
            .submitLabel(.go)
            .onSubmit {
                Task { await submit() }
            }

            if let errorMessage = remoteErrorMessage {
                AuthErrorBanner(message: errorMessage, theme: theme)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            primaryButton(theme: theme)
                .padding(.top, 2)

            secondaryAction(theme: theme)
        }
        .padding(AuthMetrics.cardPadding)
        .frame(minHeight: mode.cardMinHeight, alignment: .top)
        .figmaGlass(
            fill: theme.glassFill,
            stroke: theme.glassStroke,
            cornerRadius: AuthMetrics.cardRadius,
            shadow: .card,
            interactive: false,
        )
        .animation(AuthMetrics.keyboardAnimation, value: isKeyboardDriven)
        .animation(.easeOut(duration: 0.18), value: mode)
    }

    private func cardHeader(theme: AuthTheme) -> some View {
        Text(mode.title)
            .authFont(size: 26, weight: .bold)
            .foregroundStyle(theme.textPrimary)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityAddTraits(.isHeader)
        .padding(.bottom, 6)
    }

    private func primaryButton(theme: AuthTheme) -> some View {
        Button {
            Task { await submit() }
        } label: {
            HStack(spacing: 8) {
                if session.isRequestInFlight {
                    ProgressView()
                        .tint(theme.ctaText)
                        .controlSize(.small)
                }

                Text(mode.buttonTitle)
                    .authFont(size: 15, weight: .bold)
            }
            .foregroundStyle(canSubmit ? theme.ctaText : theme.link)
            .frame(maxWidth: .infinity)
            .frame(height: AuthMetrics.ctaHeight)
            .background(canSubmit ? theme.ctaFill : theme.ctaDisabledFill, in: RoundedRectangle(cornerRadius: AuthMetrics.ctaRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .animation(.easeOut(duration: 0.18), value: canSubmit)
    }

    private func secondaryAction(theme: AuthTheme) -> some View {
        Button {
            mode = mode.alternate
        } label: {
            HStack(spacing: 4) {
                Text(mode.secondaryPrompt)
                    .authFont(size: 13, weight: .regular)
                    .foregroundStyle(theme.textSecondary)

                Text(mode.secondaryAction)
                    .authFont(size: 13, weight: .bold)
                    .foregroundStyle(theme.link)
            }
            .frame(maxWidth: .infinity)
            .frame(height: AuthMetrics.secondaryHeight)
        }
        .buttonStyle(.plain)
    }

    private func contentTopPadding(in proxy: GeometryProxy) -> CGFloat {
        let safeTop = proxy.safeAreaInsets.top
        let availableHeight = proxy.size.height - safeTop - proxy.safeAreaInsets.bottom
        let restingTop = safeTop + max(28, (availableHeight - estimatedContentHeight) / 2)
        let raisedTop = safeTop + 24
        return isKeyboardDriven ? raisedTop : restingTop
    }

    private func contentBottomPadding(in proxy: GeometryProxy) -> CGFloat {
        max(32, keyboardHeight + proxy.safeAreaInsets.bottom + 20)
    }

    private var estimatedContentHeight: CGFloat {
        AuthMetrics.brandHeaderHeight + AuthMetrics.brandToCardSpacing + estimatedCardHeight
    }

    private var estimatedCardHeight: CGFloat {
        var height = AuthMetrics.cardPadding * 2 + 34 + 6
        height += AuthMetrics.formSpacing + AuthMetrics.fieldBaseHeight
        height += AuthMetrics.formSpacing + AuthMetrics.fieldBaseHeight
        height += AuthMetrics.formSpacing + 2 + AuthMetrics.ctaHeight
        height += AuthMetrics.formSpacing + AuthMetrics.secondaryHeight

        if mode == .signUp {
            height += 15
        }

        if idValidationMessage != nil {
            height += 18
        }

        if passwordMessage != nil {
            height += 18
        }

        if remoteErrorMessage != nil {
            height += 52 + AuthMetrics.formSpacing
        }

        return max(height, mode.cardMinHeight)
    }

    private var isKeyboardDriven: Bool {
        keyboardHeight > 0 || focusedField != nil
    }

    private func updateKeyboardHeight(from notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        let screenHeight = UIScreen.main.bounds.height
        let nextHeight = max(0, screenHeight - frame.minY)

        withAnimation(AuthMetrics.keyboardAnimation) {
            keyboardHeight = nextHeight
        }
    }

    private var trimmedId: String {
        id.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var idHelperMessage: String? {
        mode == .signUp ? "4-20자 영문 소문자, 숫자, ., _" : nil
    }

    private var idValidationMessage: String? {
        if trimmedId.isEmpty {
            return didAttemptSubmit ? "아이디를 입력해 주세요." : nil
        }

        if mode == .login {
            guard trimmedId.count <= 64 else {
                return "아이디는 64자 이하로 입력해 주세요."
            }

            return nil
        }

        guard trimmedId.range(of: #"^(?!.*[._]{2})[a-z0-9](?:[a-z0-9._]{2,18}[a-z0-9])$"#, options: .regularExpression) != nil else {
            return "4-20자 영문 소문자, 숫자, ., _를 사용할 수 있어요."
        }

        if session.errorMessage == "이미 사용 중인 아이디입니다." {
            return "이미 사용 중인 아이디입니다."
        }

        return nil
    }

    private var passwordMessage: String? {
        if password.isEmpty {
            return didAttemptSubmit ? "비밀번호를 입력해 주세요." : nil
        }

        guard (8 ... 72).contains(password.count) else {
            return "비밀번호는 8-72자로 입력해 주세요."
        }

        if mode == .signUp {
            guard password.range(of: #"^(?=.*[A-Za-z])(?=.*\d)(?=.*[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>/?])(?!.*\s).{8,72}$"#, options: .regularExpression) != nil else {
                return "영문, 숫자, 특수문자를 포함해 주세요."
            }
        }

        return nil
    }

    private var remoteErrorMessage: String? {
        guard didAttemptSubmit else {
            return nil
        }

        guard let message = session.errorMessage else {
            return nil
        }

        if mode == .signUp, message == "이미 사용 중인 아이디입니다." {
            return nil
        }

        return message
    }

    private var canSubmit: Bool {
        idValidationMessage == nil &&
            passwordMessage == nil &&
            !trimmedId.isEmpty &&
            !password.isEmpty &&
            !session.isRequestInFlight
    }

    private func submit() async {
        didAttemptSubmit = true
        session.errorMessage = nil

        guard canSubmit else {
            focusedField = idValidationMessage == nil ? .password : .id
            return
        }

        switch mode {
        case .login:
            await session.login(id: trimmedId, password: password, deviceId: deviceId)
        case .signUp:
            await session.signUp(id: trimmedId, password: password, deviceId: deviceId)
        }
    }
}

private enum AuthMode: String, CaseIterable, Identifiable {
    case login
    case signUp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .login:
            return "로그인"
        case .signUp:
            return "회원가입"
        }
    }

    var buttonTitle: String {
        switch self {
        case .login:
            return "로그인"
        case .signUp:
            return "계정 만들기"
        }
    }

    var secondaryPrompt: String {
        switch self {
        case .login:
            return "계정이 없나요?"
        case .signUp:
            return "이미 계정이 있나요?"
        }
    }

    var secondaryAction: String {
        alternate.title
    }

    var alternate: AuthMode {
        switch self {
        case .login:
            return .signUp
        case .signUp:
            return .login
        }
    }

    var cardMinHeight: CGFloat {
        switch self {
        case .login:
            return AuthMetrics.loginCardMinHeight
        case .signUp:
            return AuthMetrics.signUpCardMinHeight
        }
    }
}

private enum AuthField {
    case id
    case password
}

private struct BrandMark: View {
    var body: some View {
        Image("LaunchMark")
            .resizable()
            .scaledToFit()
            .frame(width: 58, height: 58)
            .shadow(color: AuthPalette.main.opacity(0.22), radius: 22, x: 0, y: 12)
            .accessibilityHidden(true)
    }
}

private struct AuthTextField: View {
    let title: String
    @Binding var text: String
    let prompt: String
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType
    let helperMessage: String?
    let validationMessage: String?
    let isFocused: Bool
    let theme: AuthTheme

    var body: some View {
        VStack(alignment: .leading, spacing: AuthMetrics.fieldSpacing) {
            AuthFieldLabel(title: title, theme: theme)

            TextField(prompt, text: $text)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .authFont(size: 15, weight: .regular)
                .foregroundStyle(theme.textPrimary)
                .tint(theme.link)
                .padding(.horizontal, AuthMetrics.inputHorizontalPadding)
                .frame(height: AuthMetrics.inputHeight)
                .background(fieldShape.fill(theme.inputFill))
                .overlay(fieldShape.stroke(fieldStroke, lineWidth: fieldStrokeWidth))

            if let message = validationMessage ?? helperMessage {
                Text(message)
                    .authFont(size: validationMessage == nil ? 11 : 12, weight: .regular)
                    .foregroundStyle(validationMessage == nil ? theme.helperText : AuthPalette.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AuthMetrics.inputRadius, style: .continuous)
    }

    private var fieldStroke: Color {
        validationMessage == nil ? (isFocused ? theme.link.opacity(0.58) : theme.inputStroke) : AuthPalette.error
    }

    private var fieldStrokeWidth: CGFloat {
        isFocused ? 1.5 : 1
    }
}

private struct AuthPasswordField: View {
    @Binding var password: String
    @Binding var isPasswordVisible: Bool
    let validationMessage: String?
    let isFocused: Bool
    let theme: AuthTheme

    var body: some View {
        VStack(alignment: .leading, spacing: AuthMetrics.fieldSpacing) {
            AuthFieldLabel(title: "비밀번호", theme: theme)

            HStack(spacing: 10) {
                Group {
                    if isPasswordVisible {
                        TextField("••••••••", text: $password)
                    } else {
                        SecureField("••••••••", text: $password)
                    }
                }
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .authFont(size: 15, weight: .regular)
                .foregroundStyle(theme.textPrimary)
                .tint(theme.link)

                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .font(.system(size: 16, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                }
                .foregroundStyle(theme.link)
                .frame(width: 42, height: 28)
                .buttonStyle(.plain)
                .accessibilityLabel(isPasswordVisible ? "비밀번호 숨기기" : "비밀번호 보기")
            }
            .padding(.leading, AuthMetrics.inputHorizontalPadding)
            .padding(.trailing, 10)
            .frame(height: AuthMetrics.inputHeight)
            .background(fieldShape.fill(theme.inputFill))
            .overlay(fieldShape.stroke(fieldStroke, lineWidth: fieldStrokeWidth))

            if let validationMessage {
                Text(validationMessage)
                    .authFont(size: 12, weight: .regular)
                    .foregroundStyle(AuthPalette.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AuthMetrics.inputRadius, style: .continuous)
    }

    private var fieldStroke: Color {
        validationMessage == nil ? (isFocused ? theme.link.opacity(0.58) : theme.inputStroke) : AuthPalette.error
    }

    private var fieldStrokeWidth: CGFloat {
        isFocused ? 1.5 : 1
    }
}

private struct AuthFieldLabel: View {
    let title: String
    let theme: AuthTheme

    var body: some View {
        Text(title)
            .authFont(size: 12, weight: .medium)
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 16, alignment: .center)
    }
}

private struct AuthErrorBanner: View {
    let message: String
    let theme: AuthTheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AuthPalette.error)

            Text(message)
                .authFont(size: 12, weight: .medium)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AuthPalette.error.opacity(0.10), in: RoundedRectangle(cornerRadius: AuthMetrics.inputRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AuthMetrics.inputRadius, style: .continuous)
                .stroke(AuthPalette.error.opacity(0.28), lineWidth: 1)
        }
    }
}

private struct AuthBackground: View {
    let theme: AuthTheme

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                theme.canvas
                theme.diagonalWash
                theme.topAmbientGlow
                theme.lowerCollectorGlow

                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(theme.backgroundGlass)
                    .frame(
                        width: min(345, max(0, proxy.size.width - AuthMetrics.horizontalMargin * 2)),
                        height: theme.backgroundWashHeight,
                    )
                    .shadow(color: .black.opacity(theme.isBlack ? 0.18 : 0.12), radius: 21, x: 0, y: 22)
                    .position(
                        x: proxy.size.width / 2,
                        y: min(proxy.size.height * 0.62, proxy.size.height - theme.backgroundWashHeight / 2),
                    )
            }
        }
    }
}

private struct FigmaGlassModifier: ViewModifier {
    let fill: Color
    let stroke: Color
    let cornerRadius: CGFloat
    let shadow: AuthShadow?
    let interactive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(iOS 26.0, *) {
            content
                .background(fill.opacity(0.42), in: shape)
                .overlay {
                    shape.stroke(stroke, lineWidth: 1)
                }
                .glassEffect(glassEffect, in: .rect(cornerRadius: cornerRadius))
                .shadow(
                    color: .black.opacity(Double(shadow?.opacity ?? 0)),
                    radius: shadow?.radius ?? 0,
                    x: shadow?.x ?? 0,
                    y: shadow?.y ?? 0,
                )
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(fill, in: shape)
                .overlay {
                    shape.stroke(stroke, lineWidth: 1)
                }
                .shadow(
                    color: .black.opacity(Double(shadow?.opacity ?? 0)),
                    radius: shadow?.radius ?? 0,
                    x: shadow?.x ?? 0,
                    y: shadow?.y ?? 0,
                )
        }
    }

    @available(iOS 26.0, *)
    private var glassEffect: Glass {
        if interactive {
            return .regular.tint(fill.opacity(0.22)).interactive()
        }

        return .regular.tint(fill.opacity(0.22))
    }
}

private extension View {
    func figmaGlass(
        fill: Color,
        stroke: Color,
        cornerRadius: CGFloat,
        shadow: AuthShadow? = nil,
        interactive: Bool = false,
    ) -> some View {
        modifier(
            FigmaGlassModifier(
                fill: fill,
                stroke: stroke,
                cornerRadius: cornerRadius,
                shadow: shadow,
                interactive: interactive,
            ),
        )
    }

    func authFont(size: CGFloat, weight: Font.Weight) -> some View {
        // Keep this as the native iOS font stack unless font files are bundled.
        font(.system(size: size, weight: weight, design: .default))
            .lineSpacing(0)
    }
}

private struct AuthTheme {
    let colorScheme: ColorScheme

    var isBlack: Bool {
        colorScheme == .dark
    }

    var canvas: Color {
        isBlack ? AuthPalette.blackCanvas : AuthPalette.lightCanvas
    }

    var backgroundGlass: Color {
        isBlack ? AuthPalette.darkSurface.opacity(0.22) : Color.white.opacity(0.26)
    }

    var backgroundWashHeight: CGFloat {
        isBlack ? 444 : 392
    }

    var diagonalWash: LinearGradient {
        if isBlack {
            LinearGradient(
                stops: [
                    .init(color: AuthPalette.darkWash.opacity(0.48), location: 0),
                    .init(color: AuthPalette.blackCanvas.opacity(0.08), location: 0.48),
                    .init(color: AuthPalette.collectorBlue.opacity(0.38), location: 1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        } else {
            LinearGradient(
                stops: [
                    .init(color: AuthPalette.mintWash.opacity(0.38), location: 0),
                    .init(color: AuthPalette.lightCanvas.opacity(0.04), location: 0.52),
                    .init(color: AuthPalette.blueWash.opacity(0.32), location: 1),
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
                    .init(color: AuthPalette.sub.opacity(0.22), location: 0),
                    .init(color: AuthPalette.collectorBlue.opacity(0.08), location: 0.42),
                    .init(color: AuthPalette.blackCanvas.opacity(0), location: 1),
                ],
                center: UnitPoint(x: 0.5, y: 0.08),
                startRadius: 0,
                endRadius: 360,
            )
        } else {
            RadialGradient(
                stops: [
                    .init(color: Color.white.opacity(0.62), location: 0),
                    .init(color: AuthPalette.sub.opacity(0.12), location: 0.36),
                    .init(color: AuthPalette.lightCanvas.opacity(0), location: 1),
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
                    .init(color: AuthPalette.collectorBlue.opacity(0.14), location: 0),
                    .init(color: AuthPalette.sub.opacity(0.06), location: 0.5),
                    .init(color: AuthPalette.blackCanvas.opacity(0), location: 1),
                ],
                center: UnitPoint(x: 0.52, y: 0.92),
                startRadius: 0,
                endRadius: 420,
            )
        } else {
            RadialGradient(
                stops: [
                    .init(color: AuthPalette.collectorBlue.opacity(0.12), location: 0),
                    .init(color: AuthPalette.sub.opacity(0.06), location: 0.48),
                    .init(color: AuthPalette.lightCanvas.opacity(0), location: 1),
                ],
                center: UnitPoint(x: 0.52, y: 0.92),
                startRadius: 0,
                endRadius: 420,
            )
        }
    }

    var textPrimary: Color {
        isBlack ? .white : AuthPalette.textPrimary
    }

    var textSecondary: Color {
        isBlack ? AuthPalette.borderDefault : AuthPalette.textSecondary
    }

    var helperText: Color {
        AuthPalette.helper
    }

    var link: Color {
        isBlack ? AuthPalette.sub : AuthPalette.main
    }

    var glassFill: Color {
        (isBlack ? Color.black : Color.white).opacity(AuthMetrics.glassOpacity)
    }

    var glassStroke: Color {
        isBlack ? Color.white.opacity(0.14) : Color.white.opacity(0.72)
    }

    var inputFill: Color {
        isBlack ? AuthPalette.darkSurface : .white
    }

    var inputStroke: Color {
        isBlack ? Color.white.opacity(0.14) : Color.white.opacity(0.74)
    }

    var ctaFill: Color {
        isBlack ? AuthPalette.sub : AuthPalette.main
    }

    var ctaDisabledFill: Color {
        isBlack ? AuthPalette.sub.opacity(0.36) : AuthPalette.main.opacity(0.24)
    }

    var ctaText: Color {
        isBlack ? AuthPalette.textPrimary : .white
    }
}

private enum AuthPalette {
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
    static let textSecondary = Color(red: 51 / 255, green: 67 / 255, blue: 58 / 255)
    static let borderDefault = Color(red: 214 / 255, green: 225 / 255, blue: 216 / 255)
    static let helper = Color(red: 113 / 255, green: 128 / 255, blue: 118 / 255)
    static let error = Color(red: 224 / 255, green: 41 / 255, blue: 56 / 255)
}

private enum AuthMetrics {
    static let cardWidth: CGFloat = 345
    static let loginCardMinHeight: CGFloat = 392
    static let signUpCardMinHeight: CGFloat = 444
    static let horizontalMargin: CGFloat = 24
    static let brandHeaderHeight: CGFloat = 104
    static let brandToCardSpacing: CGFloat = 22
    static let cardRadius: CGFloat = 30
    static let cardPadding: CGFloat = 22
    static let formSpacing: CGFloat = 16
    static let fieldSpacing: CGFloat = 7
    static let fieldBaseHeight: CGFloat = 71
    static let inputHeight: CGFloat = 48
    static let inputRadius: CGFloat = 18
    static let inputHorizontalPadding: CGFloat = 14
    static let ctaHeight: CGFloat = 54
    static let ctaRadius: CGFloat = 18
    static let secondaryHeight: CGFloat = 22
    static let glassOpacity: CGFloat = 0.58
    static let keyboardAnimation = Animation.easeOut(duration: 0.28)
}

private struct AuthShadow {
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    let opacity: CGFloat

    static let card = AuthShadow(radius: 23, x: 0, y: 24, opacity: 0.10)
}
