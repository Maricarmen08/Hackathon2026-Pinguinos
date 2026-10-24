import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_android/google_sign_in_android.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:hackathon_pinguinos_mvp/v1/google_android_access.dart';

class AttemptClient extends GoogleSignInAndroid {
  final calls = <String>[];
  InitParameters? parameters;
  @override
  Future<void> init(InitParameters params) async {
    expect(parameters, isNull);
    parameters = params;
    calls.add('init');
  }

  @override
  Future<void> signOut(SignOutParams params) async => calls.add('signOut');

  @override
  Future<AuthenticationResults> authenticate(
      AuthenticateParameters params) async {
    calls.add('authenticate');
    return AuthenticationResults(
        user: const GoogleSignInUserData(
            email: 'fixture@example.invalid', id: 'fixture-sub'),
        authenticationTokens:
            AuthenticationTokenData(idToken: 'fixture-${parameters!.nonce}'));
  }
}

void main() {
  test('cada ingreso Android inicializa una instancia con nonce nuevo',
      () async {
    final clients = <AttemptClient>[];
    GoogleSignInPlatform factory() {
      final client = AttemptClient();
      clients.add(client);
      return client;
    }

    final first = await androidGoogleCredential('fixture-web-client',
        clientFactory: factory);
    final second = await androidGoogleCredential('fixture-web-client',
        clientFactory: factory);
    expect(first.nonce, isNot(second.nonce));
    expect(first.token, isNot(second.token));
    for (var i = 0; i < clients.length; i++) {
      expect(clients[i].calls, ['init', 'signOut', 'authenticate']);
      expect(clients[i].parameters!.serverClientId, 'fixture-web-client');
      expect(clients[i].parameters!.nonce, [first.nonce, second.nonce][i]);
    }
  });
}
