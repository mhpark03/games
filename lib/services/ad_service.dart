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

  // 보상형 광고 쿨다운 (한번 시청 후 일정 시간 동안 광고 스킵)
  DateTime? _lastRewardedAdTime;
  static const Duration rewardedAdCooldown = Duration(minutes: 3);

  /// 마지막 광고 시청 후 쿨다운 기간 내인지 확인
  bool get isInRewardCooldown {
    if (_lastRewardedAdTime == null) return false;
    return DateTime.now().difference(_lastRewardedAdTime!) < rewardedAdCooldown;
  }

  /// 광고 시청 시간 기록 (쿨다운 시작)
  void _markRewardedAdWatched() {
    _lastRewardedAdTime = DateTime.now();
  }

  // 광고 단위 ID (디버그 모드에서는 테스트 ID 사용)
  String get rewardedAdUnitId {
    if (kDebugMode) {
      // 테스트 광고 ID
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-3940256099942544/1712485313';
    }
    // 실제 광고 ID
    if (Platform.isAndroid) {
      return 'ca-app-pub-8361977398389047/3216947358'; // Android 보상형
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // iOS 테스트 ID
    }
    throw UnsupportedError('지원하지 않는 플랫폼입니다');
  }

  String get bannerAdUnitId {
    if (kDebugMode) {
      // 테스트 광고 ID
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';
    }
    // 실제 광고 ID
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
  /// [onUserEarnedReward] 광고 시청 완료 시 호출되는 콜백
  /// [onAdDismissed] 광고가 닫혔을 때 호출되는 콜백
  /// [onAdNotAvailable] 광고가 준비되지 않았을 때 호출되는 콜백
  /// 반환값: 광고가 표시되었으면 true, 아니면 false
  Future<bool> showRewardedAd({
    required Function(AdWithoutView, RewardItem) onUserEarnedReward,
    Function()? onAdDismissed,
    Function()? onAdNotAvailable,
  }) async {
    if (_rewardedAd == null) {
      loadRewardedAd();
      onAdNotAvailable?.call();
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
        _markRewardedAdWatched();
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
        // 광고 실패 시 콜백 호출
        onAdNotAvailable?.call();
        loadRewardedAd();
      },
    );

    await _rewardedAd!.show(onUserEarnedReward: onUserEarnedReward);
    return true;
  }

  // 배너 광고 로드 (적응형 배너, 실패 시 표준 배너 폴백)
  bool _useStandardBanner = false;

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

    // 배너 크기 결정
    AdSize adSize;
    if (_useStandardBanner) {
      // 표준 배너 (320x50)
      adSize = AdSize.banner;
    } else {
      // 적응형 배너 크기 (화면 너비에 맞춤)
      final int width = (screenWidth ?? 320).toInt();
      final AdSize? adaptiveSize = await AdSize.getAnchoredAdaptiveBannerAdSize(
        Orientation.portrait,
        width,
      );
      if (adaptiveSize == null) {
        debugPrint('적응형 배너 크기를 가져올 수 없음, 표준 배너로 폴백');
        adSize = AdSize.banner;
        _useStandardBanner = true;
      } else {
        adSize = adaptiveSize;
      }
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
          // 적응형 배너 실패 시 표준 배너로 폴백 재시도
          if (!_useStandardBanner) {
            _useStandardBanner = true;
            debugPrint('표준 배너(320x50)로 폴백 재시도');
            loadBannerAd(onLoaded: onLoaded, screenWidth: screenWidth);
            return;
          }
          // 표준 배너도 실패 시 30초 후 재시도
          Future.delayed(const Duration(seconds: 30), () {
            _useStandardBanner = false; // 다시 적응형부터 시도
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
