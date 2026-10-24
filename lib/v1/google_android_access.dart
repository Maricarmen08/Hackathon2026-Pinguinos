import 'package:google_sign_in_android/google_sign_in_android.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:uuid/uuid.dart';

class AndroidGoogleCredential {
  final String? token;
  final String nonce;
  const AndroidGoogleCredential(this.token, this.nonce);
}

// Use a fresh official Android adapter per interactive request. Each adapter is
// initialized exactly once, so its nonce changes without reinitializing the
// app-facing GoogleSignIn singleton (which explicitly forbids that).
Future<AndroidGoogleCredential> androidGoogleCredential(String serverClientId,
    {GoogleSignInPlatform Function()? clientFactory}) async {
  final nonce = const Uuid().v4();
  final client = clientFactory?.call() ?? GoogleSignInAndroid();
  await client
      .init(InitParameters(serverClientId: serverClientId, nonce: nonce));
  await client.signOut(const SignOutParams());
  final result = await client.authenticate(const AuthenticateParameters());
  return AndroidGoogleCredential(result.authenticationTokens.idToken, nonce);
}
