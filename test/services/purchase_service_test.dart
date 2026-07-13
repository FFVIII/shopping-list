import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shopping_list/services/purchase_service.dart';
import 'package:shopping_list/storage/app_repository.dart';

PurchaseDetails _purchase(PurchaseStatus status, {String? productId}) {
  return PurchaseDetails(
    purchaseID: 'test_purchase',
    productID: productId ?? PurchaseService.kProProductId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: 'server',
      source: 'test',
    ),
    transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
    status: status,
    // Explicit rather than relying on the package's default, so this test
    // doesn't silently start asserting nothing if that default ever changes.
  )..pendingCompletePurchase = true;
}

void main() {
  late Directory tempDir;
  late AppRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    repo = AppRepository();
    await repo.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('starts with the cached isPro value from the repo', () async {
    await repo.saveIsPro(true);
    final controller = StreamController<List<PurchaseDetails>>.broadcast();
    final service = PurchaseService(
      purchaseStream: controller.stream,
      completePurchase: (_) async {},
    );

    await service.init(repo);

    expect(service.isPro, isTrue);
    await controller.close();
    service.dispose();
  });

  test('a purchased update for the pro product sets isPro and persists it',
      () async {
    final controller = StreamController<List<PurchaseDetails>>.broadcast();
    final completed = <PurchaseDetails>[];
    final completer = Completer<void>();
    final service = PurchaseService(
      purchaseStream: controller.stream,
      completePurchase: (p) async {
        completed.add(p);
        completer.complete();
      },
    );

    await service.init(repo);
    expect(service.isPro, isFalse);

    controller.add([_purchase(PurchaseStatus.purchased)]);
    // Wait for the handler to actually finish (it awaits saveIsPro, a real
    // Hive disk write, before calling completePurchase) rather than a fixed
    // delay, which raced the write on slower disks.
    await completer.future;

    expect(service.isPro, isTrue);
    expect(await repo.loadIsPro(), isTrue);
    expect(completed, hasLength(1));

    await controller.close();
    service.dispose();
  });

  test('a purchase update for a different product is ignored', () async {
    final controller = StreamController<List<PurchaseDetails>>.broadcast();
    final service = PurchaseService(
      purchaseStream: controller.stream,
      completePurchase: (_) async {},
    );

    await service.init(repo);
    controller.add([_purchase(PurchaseStatus.purchased, productId: 'other')]);
    await Future<void>.delayed(Duration.zero);

    expect(service.isPro, isFalse);

    await controller.close();
    service.dispose();
  });

  test('debugSetIsPro flips isPro and persists it (debug-only escape hatch)',
      () async {
    final controller = StreamController<List<PurchaseDetails>>.broadcast();
    final service = PurchaseService(
      purchaseStream: controller.stream,
      completePurchase: (_) async {},
    );
    await service.init(repo);

    await service.debugSetIsPro(true);
    expect(service.isPro, isTrue);
    expect(await repo.loadIsPro(), isTrue);

    await service.debugSetIsPro(false);
    expect(service.isPro, isFalse);
    expect(await repo.loadIsPro(), isFalse);

    await controller.close();
    service.dispose();
  });

  test('an error status does not set isPro and records lastError', () async {
    final controller = StreamController<List<PurchaseDetails>>.broadcast();
    final service = PurchaseService(
      purchaseStream: controller.stream,
      completePurchase: (_) async {},
    );

    await service.init(repo);
    controller.add([_purchase(PurchaseStatus.error)]);
    await Future<void>.delayed(Duration.zero);

    expect(service.isPro, isFalse);
    expect(service.lastError, isNotNull);

    await controller.close();
    service.dispose();
  });
}
