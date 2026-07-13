import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/purchase_service.dart';
import '../theme/app_colors.dart';
import '../widgets/toast.dart';

class ProUpgradeScreen extends StatefulWidget {
  final PurchaseService purchaseService;

  const ProUpgradeScreen({super.key, required this.purchaseService});

  @override
  State<ProUpgradeScreen> createState() => _ProUpgradeScreenState();
}

class _ProUpgradeScreenState extends State<ProUpgradeScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.purchaseService.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.purchaseService.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() => _busy = false);
    final l = L10n.of(context);
    if (widget.purchaseService.isPro) {
      showAppToast(context, l.proPurchaseSuccessToast);
      Navigator.pop(context);
      return;
    }
    if (widget.purchaseService.lastError != null) {
      showAppToast(context, l.proPurchaseFailedToast);
    }
  }

  Future<void> _buy() async {
    setState(() => _busy = true);
    await widget.purchaseService.buy();
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    await widget.purchaseService.restorePurchases();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final product = widget.purchaseService.proProduct;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(l.proScreenTitle,
            style:
                const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.proDesc,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: (_busy || product == null) ? null : _buy,
                  child: Text(
                    product != null
                        ? '${l.proBuyButton} · ${product.price}'
                        : l.proPriceUnavailable,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _restore,
                  child: Text(l.proRestoreButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
