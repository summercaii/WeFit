import SwiftUI

struct AuthenticationView: View {
    @State private var isSignUp = false
    @State private var showDebugSheet = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [.appPrimary.opacity(0.8), .appSecondary.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Content
            ScrollView {
                VStack(spacing: 30) {
                    // Logo and App Name
                    VStack(spacing: 16) {
                        Image(systemName: "figure.run.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(.white.opacity(0.2))
                                    .frame(width: 100, height: 100)
                            )
                        
                        Text("WeFit")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 60)
                    
                    // Auth Forms Container
                    VStack {
                        if isSignUp {
                            SignUpView(isSignUp: $isSignUp)
                                .transition(.move(edge: .trailing))
                        } else {
                            SignInView(isSignUp: $isSignUp)
                                .transition(.move(edge: .leading))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 32)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
                
                // Debug button (only in development)
                #if DEBUG
                Button("🐛 Debug Database") {
                    showDebugSheet = true
                }
                .foregroundColor(.white.opacity(0.7))
                .font(.caption)
                .padding(.bottom, 20)
                #endif
            }
        }
        .animation(.easeInOut, value: isSignUp)
        .sheet(isPresented: $showDebugSheet) {
            DatabaseTestView()
        }
    }
}

struct AuthTextField: View {
    let icon: String
    let placeholder: String
    let isSecure: Bool
    @Binding var text: String
    var contentType: UITextContentType?
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 24)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textContentType(contentType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } else {
                TextField(placeholder, text: $text)
                    .textContentType(contentType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

struct AuthButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(.appPrimary)
    }
}

struct SignInView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Binding var isSignUp: Bool
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Welcome Back!")
                .font(.title2.bold())
                .foregroundColor(.appText)
            
            VStack(spacing: 16) {
                AuthTextField(
                    icon: "envelope",
                    placeholder: "Email",
                    isSecure: false,
                    text: $email,
                    contentType: .emailAddress
                )
                
                AuthTextField(
                    icon: "lock",
                    placeholder: "Password",
                    isSecure: true,
                    text: $password,
                    contentType: .password
                )
            }
            
            AuthButton(
                title: "Sign In",
                isLoading: isLoading,
                action: signIn
            )
            .disabled(isLoading)
            
            Button("Create an Account") {
                withAnimation {
                    isSignUp = true
                }
            }
            .foregroundColor(.appPrimary)
        }
        .alert(alertTitle, isPresented: $authManager.showError) {
            Button("OK", role: .cancel) {
                // If email verification is required, navigate back to login
                if authManager.authError == .emailVerificationRequired {
                    withAnimation {
                        isSignUp = false
                    }
                }
            }
        } message: {
            Text(authManager.authError?.message ?? "Unknown error")
        }
    }
    
    private var alertTitle: String {
        switch authManager.authError {
        case .emailVerificationRequired:
            return "Email Verification Required"
        default:
            return "Error"
        }
    }
    
    private func signIn() {
        isLoading = true
        Task {
            do {
                try await authManager.signIn(email: email, password: password)
            } catch {
                // Error is handled by AuthenticationManager
            }
            isLoading = false
        }
    }
}

struct SignUpView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Binding var isSignUp: Bool
    
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Account")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 15) {
                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.username)
                    .autocapitalization(.none)
                
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.newPassword)
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.newPassword)
            }
            
            Button(action: signUp) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Sign Up")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.appPrimary)
            .disabled(isLoading || !isValidForm)
            
            Button("Already have an account?") {
                isSignUp = false
            }
            .foregroundColor(.appPrimary)
        }
        .alert(alertTitle, isPresented: $authManager.showError) {
            Button("OK", role: .cancel) {
                // If email verification is required, navigate back to login
                if authManager.authError == .emailVerificationRequired {
                    withAnimation {
                        isSignUp = false
                    }
                }
            }
        } message: {
            Text(authManager.authError?.message ?? "Unknown error")
        }
    }
    
    private var alertTitle: String {
        switch authManager.authError {
        case .emailVerificationRequired:
            return "Email Verification Required"
        default:
            return "Error"
        }
    }
    
    private var isValidForm: Bool {
        !username.isEmpty && 
        !email.isEmpty && 
        !password.isEmpty && 
        password == confirmPassword &&
        password.count >= 6
    }
    
    private func signUp() {
        isLoading = true
        Task {
            do {
                try await authManager.signUp(username: username, email: email, password: password)
            } catch {
                print("Supabase signUp error: \(error)")
            }
            isLoading = false
        }
    }
}
