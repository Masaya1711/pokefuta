import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authService: AuthService

    @State private var isSignUpMode = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if isSignUpMode {
                        TextField("表示名", text: $displayName)
                            .textInputAutocapitalization(.never)
                    }
                    TextField("メールアドレス", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("パスワード(6文字以上)", text: $password)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(isSignUpMode ? "新規登録" : "ログイン") {
                        submit()
                    }
                    .disabled(isSubmitting || email.isEmpty || password.isEmpty)
                }

                Section {
                    Button(isSignUpMode ? "ログインはこちら" : "新規登録はこちら") {
                        isSignUpMode.toggle()
                        errorMessage = nil
                    }
                }
            }
            .navigationTitle("ポケふた収集")
        }
    }

    private func submit() {
        errorMessage = nil
        isSubmitting = true
        Task {
            do {
                if isSignUpMode {
                    try await authService.signUp(email: email, password: password, displayName: displayName)
                } else {
                    try await authService.signIn(email: email, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
