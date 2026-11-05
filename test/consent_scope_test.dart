import 'package:flutter_test/flutter_test.dart';
import 'package:spy_love/features/consent/models/consent_scope.dart';

void main() {
  test('pairing catalog includes live camera, microphone, and screen', () {
    final ids = ConsentScope.all.map((scope) => scope.id).toSet();
    expect(ids, containsAll(['screen', 'camera', 'microphone']));
  });
}
