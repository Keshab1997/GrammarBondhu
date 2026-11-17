import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// The learner closed Google's account sheet — not a failure, just "not now".
class SignInCancelled implements Exception {
  const SignInCancelled();
}

/// This build cannot talk to Firebase: no google-services.json was baked in, or
/// the platform refused to start the flow. The app keeps working as a guest.
class SignInUnavailable implements Exception {
  const SignInUnavailable();
}

/// Optional Google sign-in, plugged into the local profile screen.
///
/// Deliberately lazy. main() initialises nothing Firebase-related, so a fresh
/// checkout with no google-services.json starts just as fast and never touches
/// the network until a learner taps the button themselves.
class GoogleAuth {
  GoogleAuth._();

  static final GoogleAuth instance = GoogleAuth._();

  /// Firebase's own *web* client for this project. Android needs it as the ID
  /// token audience before [FirebaseAuth] will accept the credential, and it is
  /// a public identifier — the project's real secret never leaves the console.
  static const _serverClientId =
      '804779855148-t7n94563lu36rqa55aphorrsne08mbs6.apps.googleusercontent.com';

  bool _ready = false;

  bool get isSignedIn => _ready && FirebaseAuth.instance.currentUser != null;

  /// Starts Google's account picker and exchanges the ID token for a Firebase
  /// session. Throws [SignInCancelled] / [SignInUnavailable] so the caller can
  /// word its message; anything else is a real error worth surfacing too.
  Future<UserCredential> signIn() async {
    await _ensureReady();

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const SignInCancelled();
      }
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) throw const SignInUnavailable();

    return FirebaseAuth.instance.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  /// Drops both sessions. Best effort: a guest who never signed in has nothing
  /// to clear, and a failed revoke must not block the learner from continuing.
  Future<void> signOut() async {
    if (!_ready) return;
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Offline or already signed out — the local profile is what matters.
    }
  }

  Future<void> _ensureReady() async {
    if (_ready) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw const SignInUnavailable();
      }
      await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
      _ready = true;
    } catch (_) {
      throw const SignInUnavailable();
    }
  }
}
