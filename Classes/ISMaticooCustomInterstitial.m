//
//  ISMaticooCustomInterstitial.m
//  IronSourceDemoApp
//
//  Created by root on 2023/7/13.
//  Copyright © 2023 supersonic. All rights reserved.
//

#import "ISMaticooCustomInterstitial.h"
#import <MaticooSDK/MATInterstitialAd.h>
#import <MaticooSDK/MaticooAds.h>

static NSString * const kAdapterSource = @"ironsource";
static const NSInteger kAdTypeInterstitial = 2;
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
    dic[@"adType"] = @(kAdTypeInterstitial);
    dic[@"source"] = kAdapterSource;
    if (msg.length) {
        dic[@"msg"] = msg;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
}

@interface ISMaticooCustomInterstitial()<MATInterstitialAdDelegate>
@property (nonatomic, strong) MATInterstitialAd *interstitial;
@property (nonatomic, weak) id<ISInterstitialAdDelegate> iSDelegate;
@property (nonatomic, copy) NSString *placementId;
@end

@implementation ISMaticooCustomInterstitial

- (void)loadAdWithAdData:(nonnull ISAdData *)adData
                delegate:(nonnull id<ISInterstitialAdDelegate>)delegate {
    // 与同目录 Banner 对齐：IronSource mediation 不保证在主线程回调 loadAdWithAdData:，
    // 统一切主线程执行 alloc / delegate / loadAd，规避 Main Thread Checker 报警及潜在时序问题。
    dispatch_main_MATASYNC_safe(^{
        NSString *placementId = [adData getString:@"placement_id"];
        if (placementId.length == 0) {
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(placementId, @"placement_id is nil")];
            if ([delegate respondsToSelector:@selector(adDidFailToLoadWithErrorType:errorCode:errorMessage:)]) {
                [delegate adDidFailToLoadWithErrorType:ISAdapterErrorTypeInternal errorCode:1 errorMessage:@"zMaticoo Adapter Interstitial Error: placementId is nil"];
            }
            return;
        }
        self.placementId = placementId;
        self.iSDelegate = delegate;

        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load" des:MATAdTypeDes(placementId, nil)];

        self.interstitial = [[MATInterstitialAd alloc] initWithPlacementID:placementId];
        self.interstitial.delegate = self;
        [self.interstitial loadAd];
    });
}

- (BOOL)isAdAvailableWithAdData:(nonnull ISAdData *)adData {
    return self.interstitial ? [self.interstitial isReady] : NO;
}

- (void)showAdWithViewController:(nonnull UIViewController *)viewController
                          adData:(nonnull ISAdData *)adData
                        delegate:(nonnull id<ISInterstitialAdDelegate>)delegate {
    if (![self.interstitial isReady]) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATAdTypeDes(self.placementId, @"interstitial is not ready")];
        if ([delegate respondsToSelector:@selector(adDidFailToShowWithErrorCode:errorMessage:)]) {
            [delegate adDidFailToShowWithErrorCode:ISAdapterErrorInternal
                                      errorMessage:@"zMaticoo Adapter Error : interstitial is not ready"];
        }
        return;
    }
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show" des:MATAdTypeDes(self.placementId, nil)];
    [self.interstitial showAdFromViewController:viewController];
}

#pragma mark - MATInterstitialAdDelegate

- (void)interstitialAdDidLoad:(nonnull MATInterstitialAd *)interstitialAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success" des:MATAdTypeDes(self.placementId, nil)];
    id<ISInterstitialAdDelegate> del = self.iSDelegate;
    if (del && [del respondsToSelector:@selector(adDidLoad)]) {
        [del adDidLoad];
    }
}

- (void)interstitialAd:(nonnull MATInterstitialAd *)interstitialAd didFailWithError:(nonnull NSError *)error {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(self.placementId, error.localizedDescription)];
    ISAdapterErrorType type = ISAdapterErrorTypeInternal;
    NSInteger code = error.code;
    if (code == kMATLoadFailedNoFillCode) {
        type = ISAdapterErrorTypeNoFill;
    }
    id<ISInterstitialAdDelegate> del = self.iSDelegate;
    if (del && [del respondsToSelector:@selector(adDidFailToLoadWithErrorType:errorCode:errorMessage:)]) {
        [del adDidFailToLoadWithErrorType:type errorCode:code errorMessage:error.localizedDescription ?: @""];
    }
}

- (void)interstitialAd:(nonnull MATInterstitialAd *)interstitialAd displayFailWithError:(nonnull NSError *)error {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATAdTypeDes(self.placementId, error.localizedDescription)];
    id<ISInterstitialAdDelegate> del = self.iSDelegate;
    if (del && [del respondsToSelector:@selector(adDidFailToShowWithErrorCode:errorMessage:)]) {
        [del adDidFailToShowWithErrorCode:1 errorMessage:error.localizedDescription ?: @""];
    }
}

- (void)interstitialAdDidClick:(nonnull MATInterstitialAd *)interstitialAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click" des:MATAdTypeDes(self.placementId, nil)];
    id<ISInterstitialAdDelegate> del = self.iSDelegate;
    if (del && [del respondsToSelector:@selector(adDidClick)]) {
        [del adDidClick];
    }
}

- (void)interstitialAdDidClose:(nonnull MATInterstitialAd *)interstitialAd {
    id<ISInterstitialAdDelegate> del = self.iSDelegate;
    if (del && [del respondsToSelector:@selector(adDidClose)]) {
        [del adDidClose];
    }
}

- (void)interstitialAdWillClose:(nonnull MATInterstitialAd *)interstitialAd {}

- (void)interstitialAdWillLogImpression:(nonnull MATInterstitialAd *)interstitialAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp" des:MATAdTypeDes(self.placementId, nil)];
    id<ISInterstitialAdDelegate> del = self.iSDelegate;
    if (del && [del respondsToSelector:@selector(adDidOpen)]) {
        [del adDidOpen];
    }
}

- (void)interstitialAdDidSkip:(nonnull MATInterstitialAd *)interstitialAd {}
- (void)interstitialAdEndCardShow:(nonnull MATInterstitialAd *)interstitialAd {}

- (void)dealloc {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy" des:MATAdTypeDes(_placementId, nil)];
}

@end
