import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var session: AuthSession
    @State private var mode = AuthMode.login
    @State private var id = ""
    @State private var password = ""
    @State private var deviceId: String

    @MainActor
    init() {
        _deviceId = State(initialValue: DeviceIdentifier.current)
    }

    var body: some View {
        Form {
            Section {
                Picker("Mode", selection: $mode) {
                    ForEach(AuthMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                TextField("ID", text: $id)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Password", text: $password)

                TextField("Device ID", text: $deviceId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if let errorMessage = session.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        if session.isRequestInFlight {
                            ProgressView()
                        }
                        Label(mode.buttonTitle, systemImage: mode.systemImage)
                    }
                }
                .disabled(!canSubmit)
            }
        }
    }

    private var canSubmit: Bool {
        !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !password.isEmpty &&
            !deviceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !session.isRequestInFlight
    }

    private func submit() async {
        let trimmedId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDeviceId = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .login:
            await session.login(id: trimmedId, password: password, deviceId: trimmedDeviceId)
        case .signUp:
            await session.signUp(id: trimmedId, password: password, deviceId: trimmedDeviceId)
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
            return "Login"
        case .signUp:
            return "Sign Up"
        }
    }

    var buttonTitle: String {
        switch self {
        case .login:
            return "Log In"
        case .signUp:
            return "Create Account"
        }
    }

    var systemImage: String {
        switch self {
        case .login:
            return "person.crop.circle.badge.checkmark"
        case .signUp:
            return "person.badge.plus"
        }
    }
}
