import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'admob_service.dart';

class AdBanner extends StatefulWidget {
  const AdBanner({super.key, required this.service});
  final AdMobService service;
  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  int? _width;
  int _generation = 0;
  Timer? _retry;
  void _retryLater() {
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 30), () {
      if (mounted && widget.service.canRequestAds && _width != null) {
        _load(_width!);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    if (!widget.service.canRequestAds) {
      _retry?.cancel();
      _generation++;
      _ad?.dispose();
      _ad = null;
      _width = null;
      _loaded = false;
    }
    setState(() {});
  }

  Future<void> _load(int width) async {
    if (!mounted || !widget.service.canRequestAds) return;
    final generation = ++_generation;
    _ad?.dispose();
    _ad = null;
    setState(() => _loaded = false);
    try {
      const size =
          AdSize.banner; // Standard 320 × 50, the smallest phone banner.
      if (width < size.width ||
          !mounted ||
          generation != _generation ||
          !widget.service.canRequestAds) {
        return;
      }
      final ad = BannerAd(
        adUnitId: widget.service.config.banner,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted ||
                generation != _generation ||
                !widget.service.canRequestAds) {
              ad.dispose();
              return;
            }
            setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, _) {
            ad.dispose();
            if (mounted && generation == _generation) {
              setState(() {
                _ad = null;
                _loaded = false;
              });
              _retryLater();
            }
          },
        ),
      );
      _ad = ad;
      await ad.load();
    } catch (_) {
      if (mounted && generation == _generation) {
        _ad?.dispose();
        _ad = null;
        setState(() => _loaded = false);
        _retryLater();
      }
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    _generation++;
    widget.service.removeListener(_changed);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.service.canRequestAds) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.floor();
        if (_width != width && width > 0) {
          _width = width;
          WidgetsBinding.instance.addPostFrameCallback((_) => _load(width));
        }
        final ad = _ad;
        if (!_loaded || ad == null) return const SizedBox.shrink();
        return Center(
          heightFactor: 1,
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        );
      },
    );
  }
}
