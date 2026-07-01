//
//  ISMaticooCustomRewardedVideo.m
//  MaticooIronSourceAdapter
//
//  Created by york.dong on 2026/4/18.
//

#import "ISMaticooCustomRewardedVideo.h"
#import <MaticooSDK/MATRewardedVideoAd.h>
#import <MaticooSDK/MaticooAds.h>

static NSString * const kAdapterSource = @"ironsource";
static const NSInteger kAdTypeRewardedVideo = 3;
/// 与 `ZMATLoadFailedNoFill`（20105）对齐，用于 IronSource `ISAdapterErrorTypeNoFill`。
static const NSInteger kMATLoadFailedNoFillCode = 20105;

#define dispatch_main_MATASYNC_safe(block)\
        if ([NSThread isMainThread]) {\
        block();\
        } else {\
        dispatch_async(dispatch_get_main_queue(), block);\
        }

static NSString *MATAdTypeDes(NSString *placementId, NSString * _Nullable msg) {
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    dic[@"placementId"] = placementId ?: @"";
    dic[@"adType"] = @(kAdTypeRewardedVideo);
    dic[@"source"] = kAdapterSource;
    if (msg.length) {
        dic[@"msg"] = msg;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
}

@interface ISMaticooCustomRewardedVideo()<MATRewardedVideoAdDelegate>
@property (nonatomic, strong) MATRewardedVideoAd *rewardedVideo;
@property (nonatomic, weak) id<ISRewardedVideoAdDelegate> iSDelegate;
@property (nonatomic, copy) NSString *placementId;
@end

@implementation ISMaticooCustomRewardedVideo

- (void)loadAdWithAdData:(nonnull ISAdData *)adData
                delegate:(nonnull id<ISRewardedVideoAdDelegate>)delegate {
    // 与同目录 Banner 对齐：IronSource mediation 不保证在主线程回调 loadAdWithAdData:，
    // 统一切主线程执行 alloc / delegate / loadAd，规避 Main Thread Checker 报警及潜在时序问题。
    dispatch_main_MATASYNC_safe(^{
        NSString *placementId = [adData getString:@"placement_id"];
        if (placementId.length == 0) {
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(placementId, @"placement_id is nil")];
            if ([delegate respondsToSelector:@selector(adDidFailToLoadWithErrorType:errorCode:errorMessage:)]) {
                [delegate adDidFailToLoadWithErrorType:ISAdapterErrorTypeInternal errorCode:1 errorMessage:@"zMaticoo Adapter RewardedVideo Error: placementId is nil"];
            }
            return;
        }
        self.placementId = placementId;
        self.iSDelegate = delegate;

        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load" des:MATAdTypeDes(placementId, nil)];

        self.rewardedVideo = [[MATRewardedVideoAd alloc] initWithPlacementID:placementId];
        self.rewardedVideo.delegate = self;
        [self.rewardedVideo loadAd];
    });
}

- (BOOL)isAdAvailableWithAdData:(nonnull ISAdData *)adData {
    return self.rewardedVideo ? [self.rewardedVideo isReady] : NO;
}

- (void)showAdWithViewController:(nonnull UIViewController *)viewController
                          adData:(nonnull ISAdData *)adData
                        delegate:(nonnull id<ISRewardedVideoAdDelegate>)delegate {
    if (![self.rewardedVideo isReady]) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATAdTypeDes(self.placementId, @"rewardedVideo is not ready")];
        if ([delegate respondsToSelector:@selector(adDidFailToShowWithErrorCode:errorMessage:)]) {
            [delegate adDidFailToShowWithErrorCode:ISAdapterErrorInternal
                                      errorMessage:@"zMaticoo Adapter Error : rewardedVideo is not ready"];
        }
        return;
    }
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show" des:MATAdTypeDes(self.placementId, nil)];
    [self.rewardedVideo showAdFromViewController:viewController];
}

#pragma mark - MATRewardedVideoAdDelegate

- (void)rewardedVideoAdDidLoad:(nonnull MATRewardedVideoAd *)rewardedVideoAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success" des:MATAdTypeDes(self.placementId, nil)];
    id<ISRewardedVideoAdDelegate> del = self.iSDelegate;
    if (del && [del respondsToSelector:@selector(adDidLoad)]) {
        [del adDidLoad];
    }
}

- (void)rewardedVideoAd:(nonnull MATRewardedVideoAd *)rewardedVideoAd didFailWithError:(nonnull NSError *)error {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(self.placementId, error.localizedDescription)];
    ISAdapterErrorType type = ISAdapterErrorTypeInternal;
    NSInteger code = error.code;
    if (code == kMATLoadFailedNoFillCode) {
        type = ISAdapterErrorTypeNoFill;
    }
    id<ISRewardedVideoAdDelegate> del = self.iSDelegate;
    if (del && [del respondsToSelector:@selector(adDidFailToLoadWithErrorType:errorCode:errorMessage:)]) {
        [del adDidFailToLoadWithErrorType:type errorCode:code errorMessage:error.localizedDescription ?: @""];
    }
}

- (void)rewardedVideoAd:(nonnull MATRewardedVideoAd *)rewardedVideoAd displayFailWithError:(nonnull NSError *)error {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATAdTypeDes(self.placementId, error.localizedDescription)];
    id<ISRewardedVideoAdDelegate> del = self.iSDelegate;
    if (del && [del respondsToSelector:@selector(adDidFailToShowWithErrorCode:errorMessage:)]) {
        [del adDidFailToShowWithErrorCode:1 errorMessage:error.localizedDescription ?: @""];
    }
}

- (void)rewardedVideoAdStarted:(nonnull MATRewardedVideoAd *)rewardedVideoAd {}

- (void)rewardedVideoAdCompleted:(nonnull MATRewardedVideoAd *)rewardedVideoAd {}

- (void)rewardedVideoAdWillLogImpression:(nonnull MATRewardedVideoAd *)rewardedVideoAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp" des:MATAdTypeDes(self.placementId, nil)];
    id<ISRewardedVideoAdDelegate> del = self.iSDelegate;
    if (del && [del respondsToSelector:@selector(adDidOpen)]) {
        [del adDidOpen];
    }
}

- (void)rewardedVideoAdDidClick:(nonnull MATRewardedVideoAd *)rewardedVideoAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click" des:MATAdTypeDes(self.placementId, nil)];
    id<ISRewardedVideoAdDelegate> del = self.iSDelegate;
    if (del && [del respondsToSelector:@selector(adDidClick)]) {
        [del adDidClick];
    }
}

- (void)rewardedVideoAdWillClose:(nonnull MATRewardedVideoAd *)rewardedVideoAd {}

- (void)rewardedVideoAdDidClose:(nonnull MATRewardedVideoAd *)rewardedVideoAd {
    id<ISRewardedVideoAdDelegate> del = self.iSDelegate;
    if (del && [del respondsToSelector:@selector(adDidClose)]) {
        [del adDidClose];
    }
}

- (void)rewardedVideoAdReward:(nonnull MATRewardedVideoAd *)rewardedVideoAd rewardInfo:(nonnull MATRewardInfo *)rewardInfo {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_reward" des:MATAdTypeDes(self.placementId, nil)];
    id<ISRewardedVideoAdDelegate> del = self.iSDelegate;
    if (del && [del respondsToSelector:@selector(adRewarded)]) {
        [del adRewarded];
    }
}

- (void)rewardedVideoAdDidSkip:(nonnull MATRewardedVideoAd *)rewardedVideoAd {}
- (void)rewardedVideoAdEndCardShow:(nonnull MATRewardedVideoAd *)rewardedVideoAd {}

- (void)dealloc {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy" des:MATAdTypeDes(_placementId, nil)];
}

@end
