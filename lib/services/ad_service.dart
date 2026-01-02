import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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

  // 광고 단위 ID
  String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-8361977398389047/3216947358'; // Android 보상형
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // iOS 테스트 ID
    }
    throw UnsupportedError('지원하지 않는 플랫폼입니다');
  }

  String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-8361977398389047/1127832458'; // Android 배너
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
      onAdShowedFullScreenContent: (ad) {
        debugPrint('광고 노출됨: ${ad.adUnitId}');
        // 광고가 뜨는 순간 하단 네비게이션 바 숨김
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('사용자가 광고를 닫음');
        ad.dispose();
        _rewardedAd = null;
        // 앱 복귀 시 몰입 모드 유지
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        onAdDismissed?.call();
        // 다음 광고 미리 로드
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('광고 노출 실패: $error');
        ad.dispose();
        _rewardedAd = null;
        // 실패 시에도 몰입 모드 유지
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        loadRewardedAd();
      },
    );

    await _rewardedAd!.show(onUserEarnedReward: onUserEarnedReward);
    return true;
  }

  // 배너 광고 로드 (적응형 배너)
  Future<void> loadBannerAd({
    Function()? onLoaded,
    bool forceReload = false,
    double? screenWidth,
  }) async {
    // 모바일 플랫폼이 아닌 경우 배너 광고 로드하지 않음
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    // 이미 로드된 광고가 있고 강제 새로고침이 아니면 콜백만 호출
    if (_isBannerLoaded && _bannerAd != null && !forceReload) {
      onLoaded?.call();
      return;
    }

    // 기존 광고 정리
    if (_bannerAd != null) {
      _bannerAd!.dispose();
      _bannerAd = null;
      _isBannerLoaded = false;
    }

    // 적응형 배너 크기 (화면 너비에 맞춤)
    final int width = (screenWidth ?? 320).toInt();
    final AdSize? adSize = await AdSize.getAnchoredAdaptiveBannerAdSize(
      Orientation.portrait,
      width,
    );

    if (adSize == null) {
      debugPrint('적응형 배너 크기를 가져올 수 없음');
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: adSize,
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
            loadBannerAd(onLoaded: onLoaded, screenWidth: screenWidth);
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
