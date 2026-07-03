import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopping_list/services/tutorial_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load() returns null when nothing has been saved', () async {
    expect(await TutorialStore.load(), isNull);
  });

  test('save() then load() round-trips the same step', () async {
    await TutorialStore.save(TutorialStep.completeTrip);
    expect(await TutorialStore.load(), TutorialStep.completeTrip);
  });

  test('save() overwrites the previous step', () async {
    await TutorialStore.save(TutorialStep.addItem);
    await TutorialStore.save(TutorialStep.done);
    expect(await TutorialStore.load(), TutorialStep.done);
  });
}
