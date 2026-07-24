//
//  ISMaticooCustomRewardedVideo.m
//  MaticooIronSourceAdapter
//
//  Created by york.dong on 2026/4/18.
//

#import "ISMaticooCustomRewardedVideo.h"
#import "MaticooIronSourceAdapterDebugLog.h"
#import <MaticooSDK/MATRewardedVideoAd.h>
#import <MaticooSDK/MaticooAds.h>

static NSString * const kAdapterSource = @"ironsource";
static const NSInteger kAdTypeRewardedVideo = 3;
static const NSInteger kMATLoadFailedNoFillCode = 20105;

#define dispatch_main_MATASYNC_safe(block)\
        if ([NSThread isMainThread]) {\
        block();\
        } else {\
        dispatch_async(dispatch_get_main_queue(), block);\
        }

static NSString *MATRewardedAdTypeDes(NSString * _Nullable placementId, NSString * _Nullable msg) {
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

#pragma mark - ISMaticooRewardedBridge

@interface ISMaticooRewardedBridge : NSObject <MATRewardedVideoAdDelegate>
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, strong, nullable) id<ISRewardedVideoAdDelegate> loadSmashDelegate;
@property (nonatomic, strong, nullable) id<ISRewardedVideoAdDelegate> showSmashDelegate;
@property (nonatomic, assign) BOOL isShowing;
@property (nonatomic, assign) BOOL didCallBackLoadResult;

+ (instancetype)bridgeForPlacementId:(NSString *)placementId;
- (void)prepareForLoadWithSmashDelegate:(id<ISRewardedVideoAdDelegate>)delegate;
- (void)prepareForShowWithSmashDelegate:(id<ISRewardedVideoAdDelegate>)delegate;
- (BOOL)isShowingSafe;
@end

@implementation ISMaticooRewardedBridge

+ (NSMutableDictionary<NSString *, ISMaticooRewardedBridge *> *)bridgeMap {
    static NSMutableDictionary<NSString *, ISMaticooRewardedBridge *> *map;
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
        ISMaticooRewardedBridge *bridge = self.bridgeMap[placementId];
        if (!bridge) {
            bridge = [[ISMaticooRewardedBridge alloc] init];
            bridge.placementId = placementId;
            self.bridgeMap[placementId] = bridge;
            MaticooIronSourceAdapterDebugLog(@"Bridge created self=%@ placementId=%@", bridge, placementId);
        }
        return bridge;
    }
}

- (void)prepareForLoadWithSmashDelegate:(id<ISRewardedVideoAdDelegate>)delegate {
    @synchronized (self) {
        self.loadSmashDelegate = delegate;
        self.didCallBackLoadResult = NO;
    }
    MaticooIronSourceAdapterDebugLog(@"Bridge prepareForLoad self=%@ loadSmash=%@ isShowing=%d",
                                     self, delegate, self.isShowing);
}

- (void)prepareForShowWithSmashDelegate:(id<ISRewardedVideoAdDelegate>)delegate {
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

- (void)rewardedVideoAdDidLoad:(MATRewardedVideoAd *)rewardedVideoAd {
    id<ISRewardedVideoAdDelegate> del = nil;
    @synchronized (self) {
        if (self.didCallBackLoadResult) {
            MaticooIronSourceAdapterDebugLog(@"Bridge DidLoad ignored(already) self=%@ ad=%@", self, rewardedVideoAd);
            return;
        }
        self.didCallBackLoadResult = YES;
        del = self.loadSmashDelegate;
        self.loadSmashDelegate = nil;
    }
    MaticooIronSourceAdapterDebugLog(@"Bridge DidLoad self=%@ ad=%@ loadSmash=%@", self, rewardedVideoAd, del);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success"
                                                       des:MATRewardedAdTypeDes(self.placementId, nil)];
    if (del && [del respondsToSelector:@selector(adDidLoad)]) {
        [del adDidLoad];
    }
}

- (void)rewardedVideoAd:(MATRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *)error {
    id<ISRewardedVideoAdDelegate> del = nil;
    @synchronized (self) {
        if (self.didCallBackLoadResult) {
            MaticooIronSourceAdapterDebugLog(@"Bridge DidFail ignored(already) self=%@ ad=%@", self, rewardedVideoAd);
            return;
        }
        self.didCallBackLoadResult = YES;
        del = self.loadSmashDelegate;
        self.loadSmashDelegate = nil;
    }
    MaticooIronSourceAdapterDebugLog(@"Bridge DidFail self=%@ ad=%@ loadSmash=%@ code=%ld",
                                     self, rewardedVideoAd, del, (long)error.code);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                       des:MATRewardedAdTypeDes(self.placementId, error.localizedDescription)];
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

- (void)rewardedVideoAd:(MATRewardedVideoAd *)rewardedVideoAd displayFailWithError:(NSError *)error {
    id<ISRewardedVideoAdDelegate> del = nil;
    @synchronized (self) {
        del = self.showSmashDelegate ?: self.loadSmashDelegate;
        self.isShowing = NO;
        self.showSmashDelegate = nil;
        self.loadSmashDelegate = nil;
    }
    MaticooIronSourceAdapterDebugLog(@"Bridge DisplayFail self=%@ ad=%@ showSmash=%@ code=%ld",
                                     self, rewardedVideoAd, del, (long)error.code);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed"
                                                       des:MATRewardedAdTypeDes(self.placementId, error.localizedDescription)];
    if (del && [del respondsToSelector:@selector(adDidFailToShowWithErrorCode:errorMessage:)]) {
        [del adDidFailToShowWithErrorCode:ISAdapterErrorInternal
                             errorMessage:error.localizedDescription ?: @""];
    }
}

- (void)rewardedVideoAdStarted:(MATRewardedVideoAd *)rewardedVideoAd {
    id<ISRewardedVideoAdDelegate> del = nil;
    @synchronized (self) {
        del = self.showSmashDelegate;
    }
    MaticooIronSourceAdapterDebugLog(@"Bridge Started self=%@ ad=%@ showSmash=%@", self, rewardedVideoAd, del);
    if (del && [del respondsToSelector:@selector(adDidStart)]) {
        [del adDidStart];
    }
}

- (void)rewardedVideoAdCompleted:(MATRewardedVideoAd *)rewardedVideoAd {
    id<ISRewardedVideoAdDelegate> del = nil;
    @synchronized (self) {
        del = self.showSmashDelegate;
    }
    MaticooIronSourceAdapterDebugLog(@"Bridge Completed self=%@ ad=%@ showSmash=%@", self, rewardedVideoAd, del);
    if (del && [del respondsToSelector:@selector(adDidEnd)]) {
        [del adDidEnd];
    }
}

- (void)rewardedVideoAdWillLogImpression:(MATRewardedVideoAd *)rewardedVideoAd {
    id<ISRewardedVideoAdDelegate> del = nil;
    @synchronized (self) {
        self.isShowing = YES;
        del = self.showSmashDelegate;
    }
    MaticooIronSourceAdapterDebugLog(@"Bridge Impression self=%@ ad=%@ showSmash=%@", self, rewardedVideoAd, del);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp"
                                                       des:MATRewardedAdTypeDes(self.placementId, nil)];
    if (del && [del respondsToSelector:@selector(adDidOpen)]) {
        [del adDidOpen];
    }
}

- (void)rewardedVideoAdDidClick:(MATRewardedVideoAd *)rewardedVideoAd {
    id<ISRewardedVideoAdDelegate> del = nil;
    @synchronized (self) {
        del = self.showSmashDelegate;
    }
    MaticooIronSourceAdapterDebugLog(@"Bridge Click self=%@ ad=%@ showSmash=%@", self, rewardedVideoAd, del);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click"
                                                       des:MATRewardedAdTypeDes(self.placementId, nil)];
    if (del && [del respondsToSelector:@selector(adDidClick)]) {
        [del adDidClick];
    }
}

- (void)rewardedVideoAdWillClose:(MATRewardedVideoAd *)rewardedVideoAd {}

- (void)rewardedVideoAdDidClose:(MATRewardedVideoAd *)rewardedVideoAd {
    id<ISRewardedVideoAdDelegate> del = nil;
    @synchronized (self) {
        del = self.showSmashDelegate;
        self.isShowing = NO;
        self.showSmashDelegate = nil;
    }
    MaticooIronSourceAdapterDebugLog(@"Bridge Close self=%@ ad=%@ showSmash=%@", self, rewardedVideoAd, del);
    if (del && [del respondsToSelector:@selector(adDidClose)]) {
        [del adDidClose];
    }
}

- (void)rewardedVideoAdReward:(MATRewardedVideoAd *)rewardedVideoAd rewardInfo:(MATRewardInfo *)rewardInfo {
    id<ISRewardedVideoAdDelegate> del = nil;
    @synchronized (self) {
        del = self.showSmashDelegate;
    }
    MaticooIronSourceAdapterDebugLog(@"Bridge Reward self=%@ ad=%@ showSmash=%@", self, rewardedVideoAd, del);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_reward"
                                                       des:MATRewardedAdTypeDes(self.placementId, nil)];
    if (del && [del respondsToSelector:@selector(adRewarded)]) {
        [del adRewarded];
    }
}

- (void)rewardedVideoAdDidSkip:(MATRewardedVideoAd *)rewardedVideoAd {}

- (void)rewardedVideoAdEndCardShow:(MATRewardedVideoAd *)rewardedVideoAd {}

@end

#pragma mark - ISMaticooCustomRewardedVideo

@interface ISMaticooCustomRewardedVideo ()
@property (nonatomic, strong) MATRewardedVideoAd *rewardedVideo;
@property (nonatomic, strong) ISMaticooRewardedBridge *bridge;
@property (nonatomic, copy) NSString *placementId;
@end

@implementation ISMaticooCustomRewardedVideo

#pragma mark - Rewarded Methods

- (void)loadAdWithAdData:(nonnull ISAdData *)adData
                delegate:(nonnull id<ISRewardedVideoAdDelegate>)delegate {
    MaticooIronSourceAdapterDebugLog(@"loadAdWithAdData self=%@ smashDelegate=%@", self, delegate);
    dispatch_main_MATASYNC_safe(^{
        id placementIdValue = [adData getString:@"placement_id"];
        NSString *placementId = [placementIdValue isKindOfClass:[NSString class]] ? (NSString *)placementIdValue : nil;
        if (placementId.length == 0) {
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                               des:MATRewardedAdTypeDes(nil, @"placement_id is nil")];
            if ([delegate respondsToSelector:@selector(adDidFailToLoadWithErrorType:errorCode:errorMessage:)]) {
                [delegate adDidFailToLoadWithErrorType:ISAdapterErrorTypeInternal
                                             errorCode:ISAdapterErrorMissingParams
                                          errorMessage:@"zMaticoo Adapter RewardedVideo Error: placementId is nil"];
            }
            return;
        }

        self.placementId = placementId;
        self.bridge = [ISMaticooRewardedBridge bridgeForPlacementId:placementId];
        self.rewardedVideo = [[MATRewardedVideoAd alloc] initWithPlacementID:placementId];
        if (!self.rewardedVideo || !self.bridge) {
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                               des:MATRewardedAdTypeDes(placementId, @"ad or bridge is nil")];
            if ([delegate respondsToSelector:@selector(adDidFailToLoadWithErrorType:errorCode:errorMessage:)]) {
                [delegate adDidFailToLoadWithErrorType:ISAdapterErrorTypeInternal
                                             errorCode:ISAdapterErrorInternal
                                          errorMessage:@"zMaticoo Adapter RewardedVideo Error: ad init failed"];
            }
            return;
        }

        MaticooIronSourceAdapterDebugLog(@"loadAdWithAdData self=%@ ad=%@ bridge=%@ isReady=%d isShowing=%d",
                                         self, self.rewardedVideo, self.bridge,
                                         self.rewardedVideo.isReady, [self.bridge isShowingSafe]);

        // zMaticoo 不支持同一 pid 在 show 时去 load
        if ([self.bridge isShowingSafe]) {
            MaticooIronSourceAdapterDebugLog(@"load skipped(showing) self=%@ bridge=%@ smash=%@", self, self.bridge, delegate);
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                               des:MATRewardedAdTypeDes(placementId, @"placement is showing")];
            if ([delegate respondsToSelector:@selector(adDidFailToLoadWithErrorType:errorCode:errorMessage:)]) {
                [delegate adDidFailToLoadWithErrorType:ISAdapterErrorTypeInternal
                                             errorCode:ISAdapterErrorInternal
                                          errorMessage:@"zMaticoo Adapter RewardedVideo Error: ad is currently showing"];
            }
            return;
        }

        if (self.rewardedVideo.isReady) {
            @synchronized (self.bridge) {
                self.bridge.didCallBackLoadResult = YES;
                self.bridge.loadSmashDelegate = nil;
            }
            MaticooIronSourceAdapterDebugLog(@"loadAdWithAdData ready hit self=%@ ad=%@ smash=%@", self, self.rewardedVideo, delegate);
            if ([delegate respondsToSelector:@selector(adDidLoad)]) {
                [delegate adDidLoad];
            }
            return;
        }

        [self.bridge prepareForLoadWithSmashDelegate:delegate];
        self.rewardedVideo.delegate = self.bridge;

        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load"
                                                           des:MATRewardedAdTypeDes(placementId, nil)];
        [self.rewardedVideo loadAd];
    });
}

- (BOOL)isAdAvailableWithAdData:(nonnull ISAdData *)adData {
    MATRewardedVideoAd *ad = self.rewardedVideo;
    return ad != nil && [ad isReady];
}

- (void)showAdWithViewController:(nonnull UIViewController *)viewController
                          adData:(nonnull ISAdData *)adData
                        delegate:(nonnull id<ISRewardedVideoAdDelegate>)delegate {
    MaticooIronSourceAdapterDebugLog(@"showAdWithViewController self=%@ ad=%@ bridge=%@ smashDelegate=%@",
                                     self, self.rewardedVideo, self.bridge, delegate);

    dispatch_main_MATASYNC_safe(^{
        if (!self.bridge) {
            NSString *placementId = self.placementId;
            if (placementId.length == 0) {
                id placementIdValue = [adData getString:@"placement_id"];
                placementId = [placementIdValue isKindOfClass:[NSString class]] ? (NSString *)placementIdValue : nil;
            }
            if (placementId.length > 0) {
                self.bridge = [ISMaticooRewardedBridge bridgeForPlacementId:placementId];
                self.placementId = placementId;
            }
        }
        if (!self.bridge || !self.rewardedVideo) {
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed"
                                                               des:MATRewardedAdTypeDes(self.placementId, @"bridge or ad is nil")];
            if ([delegate respondsToSelector:@selector(adDidFailToShowWithErrorCode:errorMessage:)]) {
                [delegate adDidFailToShowWithErrorCode:ISAdapterErrorInternal
                                          errorMessage:@"zMaticoo Adapter Error : rewardedVideo is not ready"];
            }
            return;
        }

        if (![self.rewardedVideo isReady]) {
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed"
                                                               des:MATRewardedAdTypeDes(self.placementId, @"rewardedVideo is not ready")];
            if ([delegate respondsToSelector:@selector(adDidFailToShowWithErrorCode:errorMessage:)]) {
                [delegate adDidFailToShowWithErrorCode:ISAdapterErrorInternal
                                          errorMessage:@"zMaticoo Adapter Error : rewardedVideo is not ready"];
            }
            return;
        }

        [self.bridge prepareForShowWithSmashDelegate:delegate];
        @synchronized (self.bridge) {
            self.bridge.isShowing = YES;
        }
        self.rewardedVideo.delegate = self.bridge;

        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show"
                                                           des:MATRewardedAdTypeDes(self.placementId, nil)];
        [self.rewardedVideo showAdFromViewController:viewController];
    });
}

- (void)dealloc {
    MaticooIronSourceAdapterDebugLog(@"Adapter dealloc self=%@ ad=%@ bridge=%@ placementId=%@ isShowing=%d",
                                     self, _rewardedVideo, _bridge, _placementId, [_bridge isShowingSafe]);
    if (_placementId.length > 0) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy"
                                                           des:MATRewardedAdTypeDes(_placementId, nil)];
    }
}

@end
