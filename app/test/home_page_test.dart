import 'package:flutter_test/flutter_test.dart';
import 'package:rusmedia_app/core/api_client.dart';
import 'package:rusmedia_app/main.dart';

class _FakeApi extends ApiClient {
  _FakeApi(this._result);
  final Future<HealthStatus> Function() _result;

  @override
  Future<HealthStatus> health() => _result();
}

void main() {
  testWidgets('shows connected state', (tester) async {
    await tester.pumpWidget(RusmediaApp(
      api: _FakeApi(() async => const HealthStatus(ok: true, database: true, storage: true)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Server terhubung.'), findsOneWidget);
  });

  testWidgets('shows an Indonesian error with a retry button', (tester) async {
    await tester.pumpWidget(RusmediaApp(
      api: _FakeApi(() async => throw ApiException('Tidak dapat terhubung ke server.')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Tidak dapat terhubung ke server.'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });
}
