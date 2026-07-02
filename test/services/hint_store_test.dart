import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopping_list/services/hint_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load() returns an empty set when nothing has been saved', () async {
    expect(await HintStore.load(), isEmpty);
  });

  test('save() then load() round-trips the same ids', () async {
    await HintStore.save({'a', 'b'});
    expect(await HintStore.load(), {'a', 'b'});
  });

  test('save() fully overwrites the previous set (not a merge)', () async {
    await HintStore.save({'a'});
    await HintStore.save({'a', 'b'});
    expect(await HintStore.load(), {'a', 'b'});
  });
}
