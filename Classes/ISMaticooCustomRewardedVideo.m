//
//  ISMaticooCustomRewardedVideo.m
//  MaticooIronSourceAdapter
//
//  Created by york.dong on 2026/4/18.
//

#import "ISMaticooCustomRewardedVideo.h"
#import "ISMaticooAdUtils.h"
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

// IronSource 在自己的线程调 isAdAvailableWithAdData: / showAdWithViewController:，而这两个属性是在主线程写的。
// ARC 并发读写 strong 属性会读到哨兵指针 0x400000000000bad0，读写必须同锁。
// 注意：持锁顺序统一为 self → bridge，用到 bridge 时先取局部变量，不要在 @synchronized(bridge) 内再走 self 的 getter。
@synthesize rewardedVideo = _rewardedVideo;
@synthesize bridge = _bridge;

- (MATRewardedVideoAd *)rewardedVideo {
    @synchronized (self) {
        return _rewardedVideo;
    }
}

- (void)setRewardedVideo:(MATRewardedVideoAd *)rewardedVideo {
    @synchronized (self) {
        _rewardedVideo = rewardedVideo;
    }
}

- (ISMaticooRewardedBridge *)bridge {
    @synchronized (self) {
        return _bridge;
    }
}

- (void)setBridge:(ISMaticooRewardedBridge *)bridge {
    @synchronized (self) {
        _bridge = bridge;
    }
}

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

        ISMaticooRewardedBridge *bridge = [ISMaticooRewardedBridge bridgeForPlacementId:placementId];
        MATRewardedVideoAd *rewardedVideo = [[MATRewardedVideoAd alloc] initWithPlacementID:placementId];
        self.placementId = placementId;
        self.bridge = bridge;
        self.rewardedVideo = rewardedVideo;
        if (!rewardedVideo || !bridge) {
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
                                         self, rewardedVideo, bridge,
                                         rewardedVideo.isReady, [bridge isShowingSafe]);

        // zMaticoo 不支持同一 pid 在 show 时去 load
        if ([bridge isShowingSafe]) {
            MaticooIronSourceAdapterDebugLog(@"load skipped(showing) self=%@ bridge=%@ smash=%@", self, bridge, delegate);
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                               des:MATRewardedAdTypeDes(placementId, @"placement is showing")];
            if ([delegate respondsToSelector:@selector(adDidFailToLoadWithErrorType:errorCode:errorMessage:)]) {
                [delegate adDidFailToLoadWithErrorType:ISAdapterErrorTypeInternal
                                             errorCode:ISAdapterErrorInternal
                                          errorMessage:@"zMaticoo Adapter RewardedVideo Error: ad is currently showing"];
            }
            return;
        }

        if (rewardedVideo.isReady) {
            @synchronized (bridge) {
                bridge.didCallBackLoadResult = YES;
                bridge.loadSmashDelegate = nil;
            }
            MaticooIronSourceAdapterDebugLog(@"loadAdWithAdData ready hit self=%@ ad=%@ smash=%@", self, rewardedVideo, delegate);
            if ([delegate respondsToSelector:@selector(adDidLoad)]) {
                [delegate adDidLoad];
            }
            return;
        }

        [bridge prepareForLoadWithSmashDelegate:delegate];
        rewardedVideo.delegate = bridge;

        NSDictionary *extraMap = ISMaticooLoadExtraMapFromAdData(adData);
        NSNumber *isMuted = extraMap[@"is_muted"];
        if ([isMuted isKindOfClass:[NSNumber class]]) {
            rewardedVideo.videoMute = isMuted.boolValue;
        }

        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load"
                                                           des:MATRewardedAdTypeDes(placementId, nil)];
        [rewardedVideo loadAdExtraMap:extraMap];
    });
}

- (BOOL)isAdAvailableWithAdData:(nonnull ISAdData *)adData {
    MATRewardedVideoAd *ad = self.rewardedVideo;
    return ad != nil && [ad isReady];
}

- (void)showAdWithViewController:(nonnull UIViewController *)viewController
                          adData:(nonnull ISAdData *)adData
                        delegate:(nonnull id<ISRewardedVideoAdDelegate>)delegate {
    // 广告对象与 bridge 的读取一律放到主线程 hop 之后，避免在 IronSource 线程上跨线程读 strong 属性。
    dispatch_main_MATASYNC_safe(^{
        ISMaticooRewardedBridge *bridge = self.bridge;
        if (!bridge) {
            NSString *placementId = self.placementId;
            if (placementId.length == 0) {
                id placementIdValue = [adData getString:@"placement_id"];
                placementId = [placementIdValue isKindOfClass:[NSString class]] ? (NSString *)placementIdValue : nil;
            }
            if (placementId.length > 0) {
                bridge = [ISMaticooRewardedBridge bridgeForPlacementId:placementId];
                self.bridge = bridge;
                self.placementId = placementId;
            }
        }
        MATRewardedVideoAd *rewardedVideo = self.rewardedVideo;
        MaticooIronSourceAdapterDebugLog(@"showAdWithViewController self=%@ ad=%@ bridge=%@ smashDelegate=%@",
                                         self, rewardedVideo, bridge, delegate);
        if (!bridge || !rewardedVideo) {
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed"
                                                               des:MATRewardedAdTypeDes(self.placementId, @"bridge or ad is nil")];
            if ([delegate respondsToSelector:@selector(adDidFailToShowWithErrorCode:errorMessage:)]) {
                [delegate adDidFailToShowWithErrorCode:ISAdapterErrorInternal
                                          errorMessage:@"zMaticoo Adapter Error : rewardedVideo is not ready"];
            }
            return;
        }

        if (![rewardedVideo isReady]) {
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed"
                                                               des:MATRewardedAdTypeDes(self.placementId, @"rewardedVideo is not ready")];
            if ([delegate respondsToSelector:@selector(adDidFailToShowWithErrorCode:errorMessage:)]) {
                [delegate adDidFailToShowWithErrorCode:ISAdapterErrorInternal
                                          errorMessage:@"zMaticoo Adapter Error : rewardedVideo is not ready"];
            }
            return;
        }

        [bridge prepareForShowWithSmashDelegate:delegate];
        @synchronized (bridge) {
            bridge.isShowing = YES;
        }
        rewardedVideo.delegate = bridge;

        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show"
                                                           des:MATRewardedAdTypeDes(self.placementId, nil)];
        [rewardedVideo showAdFromViewController:viewController];
    });
}

- (void)dealloc {
    MATRewardedVideoAd *ad = nil;
    @synchronized (self) {
        ad = _rewardedVideo;
        _rewardedVideo = nil;
    }
    MaticooIronSourceAdapterDebugLog(@"Adapter dealloc self=%@ ad=%@ bridge=%@ placementId=%@ isShowing=%d",
                                     self, ad, _bridge, _placementId, [_bridge isShowingSafe]);
    if (_placementId.length > 0) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy"
                                                           des:MATRewardedAdTypeDes(_placementId, nil)];
    }
}

@end
