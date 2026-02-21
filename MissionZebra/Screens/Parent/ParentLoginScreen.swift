import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import FirebaseCore

struct ParentLoginScreen: View {
    @EnvironmentObject var router: NavigationRouter

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var passwordVisible = false
    @State private var confirmPasswordVisible = false
    @State private var isLoading = false
    @State private var error: String?
    @State private var showPinSetup = false
    @State private var newPin = ""
    @State private var pinError: String?
    @State private var isRegisterMode = false

    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    Text(isRegisterMode ? "Ouderaccount aanmaken" : "Inloggen als ouder")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                        .multilineTextAlignment(.center)

                    Spacer().frame(height: 16)

                    // Email field
                    TextField("E-mail", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Spacer().frame(height: 12)

                    // Password field
                    HStack {
                        if passwordVisible {
                            TextField("Wachtwoord", text: $password)
                        } else {
                            SecureField("Wachtwoord", text: $password)
                        }
                        Button(action: { passwordVisible.toggle() }) {
                            Image(systemName: passwordVisible ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                    .textFieldStyle(.roundedBorder)

                    if isRegisterMode {
                        Spacer().frame(height: 12)
                        HStack {
                            if confirmPasswordVisible {
                                TextField("Herhaal wachtwoord", text: $confirmPassword)
                            } else {
                                SecureField("Herhaal wachtwoord", text: $confirmPassword)
                            }
                            Button(action: { confirmPasswordVisible.toggle() }) {
                                Image(systemName: confirmPasswordVisible ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                    }

                    if let error = error {
                        Spacer().frame(height: 8)
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    Spacer().frame(height: 16)

                    // Login/Register button
                    Button(action: {
                        if !isLoading {
                            if isRegisterMode { register() } else { login() }
                        }
                    }) {
                        Text(isLoading ? "Bezig..." : (isRegisterMode ? "Account aanmaken" : "Inloggen"))
                            .font(.body)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)

                    Spacer().frame(height: 12)

                    // Toggle register/login
                    Button(action: {
                        isRegisterMode.toggle()
                        error = nil
                    }) {
                        Text(isRegisterMode ? "Ik heb al een account – Inloggen" : "Nog geen account? Maak er een")
                            .font(.subheadline)
                    }

                    // Divider
                    Spacer().frame(height: 16)

                    HStack {
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(height: 1)
                        Text("of")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(height: 1)
                    }

                    Spacer().frame(height: 16)

                    // Google Sign-In button
                    Button(action: {
                        if !isLoading { signInWithGoogle() }
                    }) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                                .font(.title3)
                            Spacer().frame(width: 12)
                            Text("Inloggen met Google")
                                .font(.body)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)

                    Spacer()
                }
                .padding(24)
            }
        }
        .alert("Kies een ouder-PIN", isPresented: $showPinSetup) {
            TextField("4-cijferige PIN", text: $newPin)
                .keyboardType(.numberPad)
                .onChange(of: newPin, perform: { newValue in
                    newPin = String(newValue.filter { $0.isNumber }.prefix(4))
                })
            Button("Opslaan") { savePinAndContinue() }
            Button("Annuleren", role: .cancel) {
                newPin = ""
                pinError = nil
            }
        } message: {
            Text("Kies een 4-cijferige code. Deze heb je nodig om van profiel te wisselen of om het kind af te melden.")
        }
    }

    // MARK: - Auth Methods

    private func login() {
        if email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty {
            error = "Vul e-mail en wachtwoord in"
            return
        }
        isLoading = true
        error = nil

        auth.signIn(withEmail: email.trimmingCharacters(in: .whitespaces), password: password) { result, err in
            isLoading = false
            if let err = err {
                error = err.localizedDescription
            } else {
                SessionManager.shared.setParentLoggedIn()
                fetchPinAndContinue()
            }
        }
    }

    private func register() {
        if email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty || confirmPassword.isEmpty {
            error = "Vul alle velden in"
            return
        }
        if password.count < 6 {
            error = "Wachtwoord moet minstens 6 tekens zijn"
            return
        }
        if password != confirmPassword {
            error = "Wachtwoorden komen niet overeen"
            return
        }
        isLoading = true
        error = nil

        auth.createUser(withEmail: email.trimmingCharacters(in: .whitespaces), password: password) { result, err in
            isLoading = false
            if let err = err {
                error = err.localizedDescription
            } else {
                showPinSetup = true
            }
        }
    }

    private func signInWithGoogle() {
        isLoading = true
        error = nil

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            isLoading = false
            error = "Firebase niet geconfigureerd"
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            isLoading = false
            error = "Kan venster niet vinden"
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, err in
            if let err = err {
                isLoading = false
                error = err.localizedDescription
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                isLoading = false
                error = "Google inloggen is niet gelukt"
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            auth.signIn(with: credential) { _, err in
                isLoading = false
                if let err = err {
                    error = err.localizedDescription
                } else {
                    handleGoogleSignInSuccess()
                }
            }
        }
    }

    private func handleGoogleSignInSuccess() {
        SessionManager.shared.setParentLoggedIn()
        guard let user = auth.currentUser else {
            showPinSetup = true
            return
        }

        firestore.collection("parents").document(user.uid).getDocument { snapshot, err in
            if let data = snapshot?.data(), data["pinHash"] != nil {
                fetchPinAndContinue()
            } else {
                showPinSetup = true
            }
        }
    }

    private func fetchPinAndContinue() {
        guard let user = auth.currentUser else {
            navigateToModeChoice()
            return
        }

        let docRef = firestore.collection("parents").document(user.uid)
        docRef.getDocument { snapshot, err in
            if let data = snapshot?.data() {
                let hash = data["pinHash"] as? String
                let salt = data["pinSalt"] as? String
                let oldPlainPin = data["pin"] as? String

                if let hash = hash, let salt = salt {
                    ParentPinManager.shared.setParentPinHashed(hash: hash, salt: salt)
                } else if let oldPlainPin = oldPlainPin {
                    let newSalt = PinSecurity.generateSalt()
                    let newHash = PinSecurity.hashPin(oldPlainPin, salt: newSalt)
                    ParentPinManager.shared.setParentPinHashed(hash: newHash, salt: newSalt)

                    docRef.setData([
                        "pinHash": newHash,
                        "pinSalt": newSalt
                    ], merge: true) { _ in
                        docRef.updateData(["pin": FieldValue.delete()])
                    }
                }
            }
            navigateToModeChoice()
        }
    }

    private func savePinAndContinue() {
        if newPin.count == 4 {
            guard let user = auth.currentUser else {
                pinError = "Niet ingelogd"
                return
            }

            let salt = PinSecurity.generateSalt()
            let hash = PinSecurity.hashPin(newPin, salt: salt)

            firestore.collection("parents").document(user.uid).setData([
                "pinHash": hash,
                "pinSalt": salt
            ], merge: true) { err in
                if let err = err {
                    pinError = err.localizedDescription
                } else {
                    ParentPinManager.shared.setParentPinHashed(hash: hash, salt: salt)
                    SessionManager.shared.setParentLoggedIn()
                    showPinSetup = false
                    newPin = ""
                    pinError = nil
                    navigateToModeChoice()
                }
            }
        } else {
            pinError = "PIN moet 4 cijfers zijn"
        }
    }

    private func navigateToModeChoice() {
        router.navigate(to: .deviceMode)
    }
}
