//
//  ISMaticooCustomInterstitial.m
//  IronSourceDemoApp
//
//  Created by root on 2023/7/13.
//  Copyright © 2023 supersonic. All rights reserved.
//

#import "ISMaticooCustomInterstitial.h"
#import "MaticooIronSourceAdapterDebugLog.h"
#import <MaticooSDK/MATInterstitialAd.h>
#import <MaticooSDK/MaticooAds.h>

static NSString * const kAdapterSource = @"ironsource";
static const NSInteger kAdTypeInterstitial = 2;
static const NSInteger kMATLoadFailedNoFillCode = 20105;

#define dispatch_main_MATASYNC_safe(block)\
        if ([NSThread isMainThread]) {\
        block();\
        } else {\
        dispatch_async(dispatch_get_main_queue(), block);\
        }

static NSString *MATInterstitialAdTypeDes(NSString * _Nullable placementId, NSString * _Nullable msg) {
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

#pragma mark - ISMaticooInterstitialBridge

@interface ISMaticooInterstitialBridge : NSObject <MATInterstitialAdDelegate>
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, strong, nullable) id<ISInterstitialAdDelegate> loadSmashDelegate;
@property (nonatomic, strong, nullable) id<ISInterstitialAdDelegate> showSmashDelegate;
@property (nonatomic, assign) BOOL isShowing;
@property (nonatomic, assign) BOOL didCallBackLoadResult;

+ (instancetype)bridgeForPlacementId:(NSString *)placementId;
- (void)prepareForLoadWithSmashDelegate:(id<ISInterstitialAdDelegate>)delegate;
- (void)prepareForShowWithSmashDelegate:(id<ISInterstitialAdDelegate>)delegate;
- (BOOL)isShowingSafe;
@end

@implementation ISMaticooInterstitialBridge

+ (NSMutableDictionary<NSString *, ISMaticooInterstitialBridge *> *)bridgeMap {
    static NSMutableDictionary<NSString *, ISMaticooInterstitialBridge *> *map;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = [NSMutableDictionary dictionary];
    });
    return map;
}

+ (instancetype)bridgeForPlacementId:(NSString *)placementId {
    if (placementId.length == 0) {
        return nil;
    }
    @synchronized (self.bridgeMap) {
        ISMaticooInterstitialBridge *bridge = self.bridgeMap[placementId];
        if (!bridge) {
            bridge = [[ISMaticooInterstitialBridge alloc] init];
            bridge.placementId = placementId;
            self.bridgeMap[placementId] = bridge;
            MaticooIronSourceAdapterDebugLog(@"Bridge created self=%@ placementId=%@", bridge, placementId);
        }
        return bridge;
    }
}

- (void)prepareForLoadWithSmashDelegate:(id<ISInterstitialAdDelegate>)delegate {
    @synchronized (self) {
        self.loadSmashDelegate = delegate;
        self.didCallBackLoadResult = NO;
    }
    MaticooIronSourceAdapterDebugLog(@"Bridge prepareForLoad self=%@ loadSmash=%@ isShowing=%d",
                                     self, delegate, self.isShowing);
}

- (void)prepareForShowWithSmashDelegate:(id<ISInterstitialAdDelegate>)delegate {
    @synchronized (self) {
        self.showSmashDelegate = delegate;
    }
    MaticooIronSourceAdapterDebugLog(@"Bridge prepareForShow self=%@ showSmash=%@", self, delegate);
}

- (BOOL)isShowingSafe {
    @synchronized (self) {
        return self.isShowing;
    }
}

- (void)interstitialAdDidLoad:(MATInterstitialAd *)interstitialAd {
    id<ISInterstitialAdDelegate> del = nil;
    @synchronized (self) {
        if (self.didCallBackLoadResult) {
            MaticooIronSourceAdapterDebugLog(@"Bridge DidLoad ignored(already) self=%@ ad=%@", self, interstitialAd);
            return;
        }
        self.didCallBackLoadResult = YES;
        del = self.loadSmashDelegate;
        self.loadSmashDelegate = nil;
    }
    MaticooIronSourceAdapterDebugLog(@"Bridge DidLoad self=%@ ad=%@ loadSmash=%@", self, interstitialAd, del);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success"
                                                       des:MATInterstitialAdTypeDes(self.placementId, nil)];
    if (del && [del respondsToSelector:@selector(adDidLoad)]) {
        [del adDidLoad];
    }
}

- (void)interstitialAd:(MATInterstitialAd *)interstitialAd didFailWithError:(NSError *)error {
    id<ISInterstitialAdDelegate> del = nil;
    @synchronized (self) {
        if (self.didCallBackLoadResult) {
            MaticooIronSourceAdapterDebugLog(@"Bridge DidFail ignored(already) self=%@ ad=%@", self, interstitialAd);
            return;
        }
        self.didCallBackLoadResult = YES;
        del = self.loadSmashDelegate;
        self.loadSmashDelegate = nil;
    }
    MaticooIronSourceAdapterDebugLog(@"Bridge DidFail self=%@ ad=%@ loadSmash=%@ code=%ld",
                                     self, interstitialAd, del, (long)error.code);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                       des:MATInterstitialAdTypeDes(self.placementId, error.localizedDescription)];
    ISAdapterErrorType type = ISAdapterErrorTypeInternal;
    NSInteger code = error.code;
    if (code == kMATLoadFailedNoFillCode) {
        type = ISAdapterErrorTypeNoFill;
    }
    if (del && [del respondsToSelector:@selector(adDidFailToLoadWithErrorType:errorCode:errorMessage:)]) {
        [del adDidFailToLoadWithErrorType:type
                                errorCode:code
                             errorMessage:error.localizedDescription ?: @""];
    }
}

- (void)interstitialAd:(MATInterstitialAd *)interstitialAd displayFailWithError:(NSError *)error {
    id<ISInterstitialAdDelegate> del = nil;
    @synchronized (self) {
        del = self.showSmashDelegate ?: self.loadSmashDelegate;
        self.isShowing = NO;
        self.showSmashDelegate = nil;
        self.loadSmashDelegate = nil;
    }
    MaticooIronSourceAdapterDebugLog(@"Bridge DisplayFail self=%@ ad=%@ showSmash=%@ code=%ld",
                                     self, interstitialAd, del, (long)error.code);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed"
                                                       des:MATInterstitialAdTypeDes(self.placementId, error.localizedDescription)];
    if (del && [del respondsToSelector:@selector(adDidFailToShowWithErrorCode:errorMessage:)]) {
        [del adDidFailToShowWithErrorCode:ISAdapterErrorInternal
                             errorMessage:error.localizedDescription ?: @""];
    }
}

- (void)interstitialAdWillLogImpression:(MATInterstitialAd *)interstitialAd {
    id<ISInterstitialAdDelegate> del = nil;
    @synchronized (self) {
        self.isShowing = YES;
        del = self.showSmashDelegate;
    }
    MaticooIronSourceAdapterDebugLog(@"Bridge Impression self=%@ ad=%@ showSmash=%@", self, interstitialAd, del);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp"
                                                       des:MATInterstitialAdTypeDes(self.placementId, nil)];
    if (del && [del respondsToSelector:@selector(adDidOpen)]) {
        [del adDidOpen];
    }
}

- (void)interstitialAdDidClick:(MATInterstitialAd *)interstitialAd {
    id<ISInterstitialAdDelegate> del = nil;
    @synchronized (self) {
        del = self.showSmashDelegate;
    }
    MaticooIronSourceAdapterDebugLog(@"Bridge Click self=%@ ad=%@ showSmash=%@", self, interstitialAd, del);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click"
                                                       des:MATInterstitialAdTypeDes(self.placementId, nil)];
    if (del && [del respondsToSelector:@selector(adDidClick)]) {
        [del adDidClick];
    }
}

- (void)interstitialAdWillClose:(MATInterstitialAd *)interstitialAd {}

- (void)interstitialAdDidClose:(MATInterstitialAd *)interstitialAd {
    id<ISInterstitialAdDelegate> del = nil;
    @synchronized (self) {
        del = self.showSmashDelegate;
        self.isShowing = NO;
        self.showSmashDelegate = nil;
    }
    MaticooIronSourceAdapterDebugLog(@"Bridge Close self=%@ ad=%@ showSmash=%@", self, interstitialAd, del);
    if (del && [del respondsToSelector:@selector(adDidClose)]) {
        [del adDidClose];
    }
}

- (void)interstitialAdEndCardShow:(MATInterstitialAd *)interstitialAd {}

@end

#pragma mark - ISMaticooCustomInterstitial

@interface ISMaticooCustomInterstitial ()
@property (nonatomic, strong) MATInterstitialAd *interstitial;
@property (nonatomic, strong) ISMaticooInterstitialBridge *bridge;
@property (nonatomic, copy) NSString *placementId;
@end

@implementation ISMaticooCustomInterstitial

#pragma mark - Interstitial Methods

- (void)loadAdWithAdData:(nonnull ISAdData *)adData
                delegate:(nonnull id<ISInterstitialAdDelegate>)delegate {
    MaticooIronSourceAdapterDebugLog(@"loadAdWithAdData self=%@ smashDelegate=%@", self, delegate);
    dispatch_main_MATASYNC_safe(^{
        id placementIdValue = [adData getString:@"placement_id"];
        NSString *placementId = [placementIdValue isKindOfClass:[NSString class]] ? (NSString *)placementIdValue : nil;
        if (placementId.length == 0) {
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                               des:MATInterstitialAdTypeDes(nil, @"placement_id is nil")];
            if ([delegate respondsToSelector:@selector(adDidFailToLoadWithErrorType:errorCode:errorMessage:)]) {
                [delegate adDidFailToLoadWithErrorType:ISAdapterErrorTypeInternal
                                             errorCode:ISAdapterErrorMissingParams
                                          errorMessage:@"zMaticoo Adapter Interstitial Error: placementId is nil"];
            }
            return;
        }

        self.placementId = placementId;
        self.bridge = [ISMaticooInterstitialBridge bridgeForPlacementId:placementId];
        self.interstitial = [[MATInterstitialAd alloc] initWithPlacementID:placementId];
        if (!self.interstitial || !self.bridge) {
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                               des:MATInterstitialAdTypeDes(placementId, @"ad or bridge is nil")];
            if ([delegate respondsToSelector:@selector(adDidFailToLoadWithErrorType:errorCode:errorMessage:)]) {
                [delegate adDidFailToLoadWithErrorType:ISAdapterErrorTypeInternal
                                             errorCode:ISAdapterErrorInternal
                                          errorMessage:@"zMaticoo Adapter Interstitial Error: ad init failed"];
            }
            return;
        }

        MaticooIronSourceAdapterDebugLog(@"loadAdWithAdData self=%@ ad=%@ bridge=%@ isReady=%d isShowing=%d",
                                         self, self.interstitial, self.bridge,
                                         self.interstitial.isReady, [self.bridge isShowingSafe]);

        // zMaticoo 不支持同一 pid 在 show 时去 load
        if ([self.bridge isShowingSafe]) {
            MaticooIronSourceAdapterDebugLog(@"load skipped(showing) self=%@ bridge=%@ smash=%@", self, self.bridge, delegate);
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                               des:MATInterstitialAdTypeDes(placementId, @"placement is showing")];
            if ([delegate respondsToSelector:@selector(adDidFailToLoadWithErrorType:errorCode:errorMessage:)]) {
                [delegate adDidFailToLoadWithErrorType:ISAdapterErrorTypeInternal
                                             errorCode:ISAdapterErrorInternal
                                          errorMessage:@"zMaticoo Adapter Interstitial Error: ad is currently showing"];
            }
            return;
        }

        if (self.interstitial.isReady) {
            @synchronized (self.bridge) {
                self.bridge.didCallBackLoadResult = YES;
                self.bridge.loadSmashDelegate = nil;
            }
            MaticooIronSourceAdapterDebugLog(@"loadAdWithAdData ready hit self=%@ ad=%@ smash=%@", self, self.interstitial, delegate);
            if ([delegate respondsToSelector:@selector(adDidLoad)]) {
                [delegate adDidLoad];
            }
            return;
        }

        [self.bridge prepareForLoadWithSmashDelegate:delegate];
        self.interstitial.delegate = self.bridge;

        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load"
                                                           des:MATInterstitialAdTypeDes(placementId, nil)];
        [self.interstitial loadAd];
    });
}

- (BOOL)isAdAvailableWithAdData:(nonnull ISAdData *)adData {
    MATInterstitialAd *ad = self.interstitial;
    return ad != nil && [ad isReady];
}

- (void)showAdWithViewController:(nonnull UIViewController *)viewController
                          adData:(nonnull ISAdData *)adData
                        delegate:(nonnull id<ISInterstitialAdDelegate>)delegate {
    MaticooIronSourceAdapterDebugLog(@"showAdWithViewController self=%@ ad=%@ bridge=%@ smashDelegate=%@",
                                     self, self.interstitial, self.bridge, delegate);

    dispatch_main_MATASYNC_safe(^{
        if (!self.bridge) {
            NSString *placementId = self.placementId;
            if (placementId.length == 0) {
                id placementIdValue = [adData getString:@"placement_id"];
                placementId = [placementIdValue isKindOfClass:[NSString class]] ? (NSString *)placementIdValue : nil;
            }
            if (placementId.length > 0) {
                self.bridge = [ISMaticooInterstitialBridge bridgeForPlacementId:placementId];
                self.placementId = placementId;
            }
        }
        if (!self.bridge || !self.interstitial) {
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed"
                                                               des:MATInterstitialAdTypeDes(self.placementId, @"bridge or ad is nil")];
            if ([delegate respondsToSelector:@selector(adDidFailToShowWithErrorCode:errorMessage:)]) {
                [delegate adDidFailToShowWithErrorCode:ISAdapterErrorInternal
                                          errorMessage:@"zMaticoo Adapter Error : interstitial is not ready"];
            }
            return;
        }

        if (![self.interstitial isReady]) {
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed"
                                                               des:MATInterstitialAdTypeDes(self.placementId, @"interstitial is not ready")];
            if ([delegate respondsToSelector:@selector(adDidFailToShowWithErrorCode:errorMessage:)]) {
                [delegate adDidFailToShowWithErrorCode:ISAdapterErrorInternal
                                          errorMessage:@"zMaticoo Adapter Error : interstitial is not ready"];
            }
            return;
        }

        [self.bridge prepareForShowWithSmashDelegate:delegate];
        @synchronized (self.bridge) {
            self.bridge.isShowing = YES;
        }
        self.interstitial.delegate = self.bridge;

        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show"
                                                           des:MATInterstitialAdTypeDes(self.placementId, nil)];
        [self.interstitial showAdFromViewController:viewController];
    });
}

- (void)dealloc {
    MaticooIronSourceAdapterDebugLog(@"Adapter dealloc self=%@ ad=%@ bridge=%@ placementId=%@ isShowing=%d",
                                     self, _interstitial, _bridge, _placementId, [_bridge isShowingSafe]);
    if (_placementId.length > 0) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy"
                                                           des:MATInterstitialAdTypeDes(_placementId, nil)];
    }
}

@end
