import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthManager

    @State private var email      = ""
    @State private var password   = ""
    @State private var deviceName = UIDevice.current.name
    @State private var serverURL  = AppConfig.defaultServerURL
    @State private var isLoading  = false
    @State private var errorText  = ""
    @State private var mode: Mode = .login

    enum Mode { case login, register }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("Password", text: $password)
                        .textContentType(mode == .register ? .newPassword : .password)
                }

                if mode == .register {
                    Section("Device") {
                        TextField("Device name", text: $deviceName)
                    }
                }

                Section("Server") {
                    TextField("Server URL", text: $serverURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }

                if !errorText.isEmpty {
                    Section {
                        Text(errorText)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }

                Section {
                    Button(action: submit) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(mode == .login ? "Sign In" : "Create Account")
                                .frame(maxWidth: .infinity)
                                .bold()
                        }
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)

                    Button(mode == .login ? "Create an account" : "Already have an account") {
                        withAnimation { mode = mode == .login ? .register : .login }
                        errorText = ""
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(mode == .login ? "Sign In to AirClip" : "Create Account")
        }
    }

    private func submit() {
        let url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.isEmpty {
            UserDefaults.standard.set(url, forKey: "serverURL")
        }
        errorText = ""
        isLoading = true

        Task {
            do {
                if mode == .register {
                    try await authManager.register(email: email, password: password)
                    try await authManager.registerDevice(name: deviceName)
                } else {
                    try await authManager.login(email: email, password: password)
                    if !authManager.isDeviceApproved {
                        try await authManager.registerDevice(name: deviceName)
                    }
                }
            } catch {
                errorText = error.localizedDescription
            }
            isLoading = false
        }
    }
}
