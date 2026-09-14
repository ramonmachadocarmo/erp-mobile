import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/json.dart';

void main() {
  test('asString', () {
    expect(asString({'a': 1}, 'a'), '1');
    expect(asString({}, 'a'), '');
  });

  test('asDouble', () {
    expect(asDouble({'n': 1.5}, 'n'), 1.5);
    expect(asDouble({'n': '2'}, 'n'), 2);
    expect(asDouble({}, 'n'), 0);
  });

  test('asInt', () {
    expect(asInt({'n': 3}, 'n'), 3);
    expect(asInt({'n': '4'}, 'n'), 4);
    expect(asInt({}, 'n'), 0);
  });

  test('asBool', () {
    expect(asBool({'ok': true}, 'ok'), isTrue);
    expect(asBool({'ok': 'true'}, 'ok'), isTrue);
    expect(asBool({}, 'ok'), isFalse);
  });

  test('asMapList', () {
    expect(asMapList(null), isEmpty);
    expect(asMapList([{'id': '1'}]).single['id'], '1');
  });
}
