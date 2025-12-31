import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  RewardedAd? _rewardedAd;
  bool _isLoading = false;
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  // 테스트 광고 단위 ID (실제 배포시 변경 필요)
  String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // Android 테스트 ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // iOS 테스트 ID
    }
    throw UnsupportedError('지원하지 않는 플랫폼입니다');
  }

  String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Android 배너 테스트 ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // iOS 배너 테스트 ID
    }
    throw UnsupportedError('지원하지 않는 플랫폼입니다');
  }

  bool get isAdLoaded => _rewardedAd != null;
  bool get isBannerLoaded => _isBannerLoaded;
  BannerAd? get bannerAd => _bannerAd;

  // AdMob 초기화
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  // 보상형 광고 로드
  void loadRewardedAd() {
    if (_isLoading || _rewardedAd != null) return;

    _isLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          // 5초 후 재시도
          Future.delayed(const Duration(seconds: 5), () {
            loadRewardedAd();
          });
        },
      ),
    );
  }

  // 보상형 광고 표시
  Future<bool> showRewardedAd({
    required Function(AdWithoutView, RewardItem) onUserEarnedReward,
    Function()? onAdDismissed,
  }) async {
    if (_rewardedAd == null) {
      loadRewardedAd();
      return false;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        onAdDismissed?.call();
        // 다음 광고 미리 로드
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
      },
    );

    await _rewardedAd!.show(onUserEarnedReward: onUserEarnedReward);
    return true;
  }

  // 배너 광고 로드
  void loadBannerAd({Function()? onLoaded}) {
    // 모바일 플랫폼이 아닌 경우 배너 광고 로드하지 않음
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isBannerLoaded = true;
          onLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('배너 광고 로드 실패: $error');
          ad.dispose();
          _bannerAd = null;
          _isBannerLoaded = false;
          // 30초 후 재시도
          Future.delayed(const Duration(seconds: 30), () {
            loadBannerAd(onLoaded: onLoaded);
          });
        },
      ),
    );
    _bannerAd!.load();
  }

  // 배너 광고 해제
  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerLoaded = false;
  }

  // 리소스 정리
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    disposeBannerAd();
  }
}
