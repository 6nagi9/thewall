import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../../shared/wall_ui.dart';

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
    HapticFeedback.mediumImpact();
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
    if (user?.isPremium == true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Premium')),
        body: const Center(child: _ActiveBanner()),
      );
    }
    var i = 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: _storeLoading
          ? const WallLoader()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                // Gold hero
                WallCard(
                  padding: const EdgeInsets.all(24),
                  borderColor: AppTheme.gold.withValues(alpha: 0.4),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.gold.withValues(alpha: 0.14),
                      AppTheme.ink850,
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                            Icons.workspace_premium_outlined,
                            color: AppTheme.goldSoft,
                            size: 30),
                      )
                          .animate(
                              onPlay: (c) => c.repeat(reverse: true))
                          .scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.06, 1.06),
                            duration: 1600.ms,
                            curve: Curves.easeInOut,
                          ),
                      const SizedBox(height: 16),
                      Text('See the whole picture',
                          style: AppTheme.display(size: 26)),
                      const SizedBox(height: 6),
                      Text(
                        'AI summary, trends, peer comparison and coaching — everything to turn feedback into growth.',
                        style: AppTheme.body(
                            size: 14,
                            color: AppTheme.ink300,
                            height: 1.5),
                      ),
                    ],
                  ),
                ).entrance(++i),
                const SizedBox(height: 22),
                SectionLabel('What you unlock').entrance(++i),
                ..._kFeatures.map((f) {
                  i++;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: WallCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AppTheme.gold
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(f.$1,
                                color: AppTheme.goldSoft, size: 20),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(f.$2,
                                    style: AppTheme.body(
                                        size: 14.5,
                                        weight: FontWeight.w700,
                                        color: AppTheme.paper)),
                                const SizedBox(height: 2),
                                Text(f.$3,
                                    style: AppTheme.body(
                                        size: 12.5,
                                        color: AppTheme.ink400,
                                        height: 1.45)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).entrance(i),
                  );
                }),
                const SizedBox(height: 12),
                if (_products.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Store unavailable — check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: AppTheme.body(
                          size: 13, color: AppTheme.ink400),
                    ),
                  )
                else
                  ..._products.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ProductCard(
                          product: p,
                          onBuy: _purchasing ? null : () => _buy(p),
                        ).entrance(++i),
                      )),
                TextButton(
                  onPressed: _purchasing ? null : _restore,
                  child: const Text('Restore purchases'),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Subscriptions auto-renew unless cancelled 24 h before renewal. Manage in device Settings.',
                    textAlign: TextAlign.center,
                    style: AppTheme.body(
                        size: 11, color: AppTheme.ink400, height: 1.5),
                  ),
                ),
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
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.verified_rounded,
                  color: AppTheme.goldSoft, size: 44),
            )
                .animate()
                .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1, 1),
                  duration: WallMotion.slow,
                  curve: WallMotion.spring,
                )
                .fadeIn(),
            const SizedBox(height: 20),
            Text("You're on Premium",
                style: AppTheme.display(size: 24)),
            const SizedBox(height: 8),
            Text(
              'All features unlocked. Thank you for supporting The Wall.',
              textAlign: TextAlign.center,
              style: AppTheme.body(
                  size: 14, color: AppTheme.ink300, height: 1.5),
            ),
          ],
        ),
      );
}

// Campaigns are deliberately NOT premium — the ask-link is the viral loop.
// Premium sells the insight on the results.
const _kFeatures = [
  (Icons.auto_awesome_rounded, 'AI wall summary',
      'What people consistently say about you — written for you, with a growth plan.'),
  (Icons.show_chart_outlined, 'Trend charts',
      'See how your scores change over time.'),
  (Icons.people_outline, 'Cohort comparison',
      'Find out where you stand vs. the wider Wall community.'),
  (Icons.lightbulb_outline, 'Coaching prompts',
      'Personalised growth tips based on your lowest-scoring dimensions.'),
  (Icons.all_inclusive_rounded, 'Unlimited campaigns',
      'Run as many feedback requests at once as you like (free includes one).'),
  (Icons.workspace_premium_outlined, 'Premium badge',
      'A visible signal of your commitment to growth.'),
];

class _ProductCard extends StatelessWidget {
  final ProductDetails product;
  final VoidCallback? onBuy;
  const _ProductCard({required this.product, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    final isYearly = product.id == _kYearly;
    return WallCard(
      padding: const EdgeInsets.all(20),
      borderColor:
          isYearly ? AppTheme.gold.withValues(alpha: 0.45) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                product.title
                    .replaceAll(RegExp(r'\s*\(.*?\)'), '')
                    .trim(),
                style: AppTheme.body(
                    size: 15,
                    weight: FontWeight.w700,
                    color: AppTheme.paper),
              ),
              const Spacer(),
              if (isYearly)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.gold,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('BEST VALUE',
                      style: AppTheme.body(
                          size: 10,
                          weight: FontWeight.w800,
                          color: AppTheme.ink950,
                          letterSpacing: 0.8)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(product.price,
              style: AppTheme.display(
                  size: 30, color: AppTheme.goldSoft)),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onBuy,
            style: isYearly
                ? ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold)
                : null,
            child: Text(
                isYearly ? 'Subscribe yearly' : 'Subscribe monthly'),
          ),
        ],
      ),
    );
  }
}
