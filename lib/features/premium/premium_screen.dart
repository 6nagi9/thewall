import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/theme.dart';
import '../../data/repositories.dart';

const _kMonthly = 'wall_premium_monthly';
const _kYearly = 'wall_premium_yearly';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});
  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  late StreamSubscription<List<PurchaseDetails>> _sub;
  List<ProductDetails> _products = [];
  bool _storeLoading = true;
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    _sub = InAppPurchase.instance.purchaseStream.listen(_onPurchase);
    _loadProducts();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      if (mounted) setState(() => _storeLoading = false);
      return;
    }
    final response = await InAppPurchase.instance
        .queryProductDetails({_kMonthly, _kYearly});
    if (mounted) {
      setState(() {
        _products = response.productDetails
          ..sort((a, b) => a.id == _kMonthly ? -1 : 1);
        _storeLoading = false;
      });
    }
  }

  void _onPurchase(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        try {
          await ref.read(repoProvider).verifyPurchase(
                productId: p.productID,
                verificationData:
                    p.verificationData.serverVerificationData,
                source: p.verificationData.source,
              );
        } catch (_) {}
        await InAppPurchase.instance.completePurchase(p);
      } else if (p.status == PurchaseStatus.error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(p.error?.message ?? 'Purchase failed.')));
        }
        await InAppPurchase.instance.completePurchase(p);
      }
    }
    if (mounted) setState(() => _purchasing = false);
  }

  Future<void> _buy(ProductDetails product) async {
    setState(() => _purchasing = true);
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  Future<void> _restore() async {
    setState(() => _purchasing = true);
    await InAppPurchase.instance.restorePurchases();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).value;
    if (user?.premium == true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Premium')),
        body: const Center(child: _ActiveBanner()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade to Premium')),
      body: _storeLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _FeatureList(),
                const SizedBox(height: 24),
                if (_products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Store unavailable — check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.slate500),
                    ),
                  )
                else
                  ..._products.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ProductCard(
                          product: p,
                          onBuy: _purchasing ? null : () => _buy(p),
                        ),
                      )),
                TextButton(
                  onPressed: _purchasing ? null : _restore,
                  child: const Text('Restore purchases'),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Subscriptions auto-renew unless cancelled 24 h before '
                    'renewal. Manage in device Settings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.slate500, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _ActiveBanner extends StatelessWidget {
  const _ActiveBanner();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.verified, color: AppTheme.teal, size: 64),
            SizedBox(height: 16),
            Text('You are on Premium!',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text('All features unlocked. Thank you for supporting The Wall.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.slate300)),
          ],
        ),
      );
}

const _kFeatures = [
  (Icons.show_chart_outlined, 'Trend charts',
      'See how your scores change over time with fl_chart visualisations.'),
  (Icons.people_outline, 'Cohort comparison',
      'Find out where you rank vs. the wider Wall community.'),
  (Icons.lightbulb_outline, 'Coaching prompts',
      'Personalised growth tips based on your lowest-scoring dimensions.'),
  (Icons.campaign_outlined, 'Feedback campaigns',
      'Solicit targeted feedback from people you trust.'),
  (Icons.workspace_premium_outlined, 'Premium badge',
      'A visible signal of your commitment to growth.'),
];

class _FeatureList extends StatelessWidget {
  const _FeatureList();
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What you unlock',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          ..._kFeatures.map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(f.$1, color: AppTheme.teal, size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.$2,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(f.$3,
                              style: const TextStyle(
                                  color: AppTheme.slate300,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      );
}

class _ProductCard extends StatelessWidget {
  final ProductDetails product;
  final VoidCallback? onBuy;
  const _ProductCard({required this.product, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    final isYearly = product.id == _kYearly;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (isYearly)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.amber,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Best value',
                    style: TextStyle(
                        color: AppTheme.slate900,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            if (isYearly) const SizedBox(height: 10),
            Text(
              product.title.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim(),
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(product.price,
                style: const TextStyle(
                    fontSize: 26,
                    color: AppTheme.teal,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onBuy,
              child: Text(isYearly ? 'Subscribe yearly' : 'Subscribe monthly'),
            ),
          ],
        ),
      ),
    );
  }
}
