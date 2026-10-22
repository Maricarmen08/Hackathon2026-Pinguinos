import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';

void main() {
  test('Flutter/Dart consulta salud real Express y MySQL sin escrituras',
      () async {
    final api = ApiClient(
        baseUrl: const String.fromEnvironment('LIVE_API_URL',
            defaultValue: 'http://127.0.0.1:3000/api/v1'));
    try {
      expect((await api.request('GET', '/health/live'))['status'], 'ok');
      expect((await api.request('GET', '/health/ready'))['status'], 'ready');
      await expectLater(api.request('GET', '/negocios'),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
    } finally {
      api.client.close();
    }
  }, skip: !const bool.fromEnvironment('RUN_LIVE_API'));
}
