import Foundation
import FirebaseAuth
import GoogleSignIn
import FirebaseCore

class AuthRepository: ObservableObject {

    private let firebaseAuth = Auth.auth()

    var currentUser: User? {
        return firebaseAuth.currentUser
    }

    func registerWithEmail(email: String, password: String) async -> Result<Void, Error> {
        do {
            _ = try await firebaseAuth.createUser(withEmail: email, password: password)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func loginWithEmail(email: String, password: String) async -> Result<Void, Error> {
        do {
            _ = try await firebaseAuth.signIn(withEmail: email, password: password)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func signInWithGoogle(presenting viewController: UIViewController) async -> Result<Void, Error> {
        do {
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing Firebase client ID"])
            }

            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config

            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
            guard let idToken = result.user.idToken?.tokenString else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing Google ID token"])
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            _ = try await firebaseAuth.signIn(with: credential)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func logout() {
        try? firebaseAuth.signOut()
        GIDSignIn.sharedInstance.signOut()
    }
}
