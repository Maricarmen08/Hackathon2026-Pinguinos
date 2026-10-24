// Fuera del navegador no hay reconocimiento de voz del navegador.
bool webVoiceSupported() => false;

Future<String> webVoiceListen(
        void Function(String) partial, void Function() ready) async =>
    'ERR:UNSUPPORTED';

void webVoiceStop() {}

void webVoiceCancel() {}
