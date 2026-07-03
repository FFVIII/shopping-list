import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopping_list/services/tutorial_controller.dart';
import 'package:shopping_list/services/tutorial_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TutorialController.instance.step = TutorialStep.done;
    TutorialController.instance.onSkipRequested = null;
  });

  test('resolveInitialStep starts at addItem for a fresh, empty install',
      () async {
    await TutorialController.instance.resolveInitialStep(dataIsEmpty: true);
    expect(TutorialController.instance.step, TutorialStep.addItem);
  });

  test('resolveInitialStep marks done for an existing user with real data',
      () async {
    await TutorialController.instance.resolveInitialStep(dataIsEmpty: false);
    expect(TutorialController.instance.step, TutorialStep.done);
  });

  test('resolveInitialStep resumes a persisted in-progress step', () async {
    await TutorialStore.save(TutorialStep.completeTrip);
    await TutorialController.instance.resolveInitialStep(dataIsEmpty: true);
    expect(TutorialController.instance.step, TutorialStep.completeTrip);
  });

  test(
      'onItemAdded advances addItem -> completeTrip only for the example item',
      () async {
    TutorialController.instance.step = TutorialStep.addItem;
    TutorialController.instance.onItemAdded('香蕉');
    expect(TutorialController.instance.step, TutorialStep.addItem);
    TutorialController.instance
        .onItemAdded(TutorialController.exampleItemNameZh);
    expect(TutorialController.instance.step, TutorialStep.completeTrip);
  });

  test('onTripCompleted advances completeTrip -> viewInventory', () async {
    TutorialController.instance.step = TutorialStep.completeTrip;
    TutorialController.instance.onTripCompleted(['某其他商品']);
    expect(TutorialController.instance.step, TutorialStep.completeTrip);
    TutorialController.instance
        .onTripCompleted([TutorialController.exampleItemNameZh]);
    expect(TutorialController.instance.step, TutorialStep.viewInventory);
  });

  test('onTabChanged advances viewInventory -> finalMessage only for tab 1',
      () async {
    TutorialController.instance.step = TutorialStep.viewInventory;
    TutorialController.instance.onTabChanged(0);
    expect(TutorialController.instance.step, TutorialStep.viewInventory);
    TutorialController.instance.onTabChanged(1);
    expect(TutorialController.instance.step, TutorialStep.finalMessage);
  });

  test('finish() moves straight to done', () async {
    TutorialController.instance.step = TutorialStep.finalMessage;
    TutorialController.instance.finish();
    expect(TutorialController.instance.step, TutorialStep.done);
  });

  test('skip() calls onSkipRequested and moves to done', () async {
    var called = false;
    TutorialController.instance.step = TutorialStep.addItem;
    TutorialController.instance.onSkipRequested = () => called = true;
    TutorialController.instance.skip();
    expect(called, isTrue);
    expect(TutorialController.instance.step, TutorialStep.done);
  });

  test(
      'onItemDeleted silently ends the tutorial if the example item is removed',
      () async {
    TutorialController.instance.step = TutorialStep.completeTrip;
    TutorialController.instance.onItemDeleted('某其他商品');
    expect(TutorialController.instance.step, TutorialStep.completeTrip);
    TutorialController.instance
        .onItemDeleted(TutorialController.exampleItemNameZh);
    expect(TutorialController.instance.step, TutorialStep.done);
  });
}
