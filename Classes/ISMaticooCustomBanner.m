//
//  ISMaticooCustomBanner.m
//  IronSourceDemoApp
//
//  Created by root on 2023/7/13.
//  Copyright © 2023 supersonic. All rights reserved.
//

#import "ISMaticooCustomBanner.h"
#import <MaticooSDK/MATBannerAd.h>
#import <MaticooSDK/MaticooAds.h>

/// 与 Android `AdUtils.getAdTypeDes(1, ...)` 一致：adType=1 为 Banner；`source` 与 `Constant.KEY_AD_MEDIATION` 一致。
static NSString * const kAdapterSource = @"ironsource";
static const NSInteger kAdTypeBanner = 1;
/// Maticoo 无填充错误码，用于映射到 IronSource `ISAdapterErrorTypeNoFill`。
static const NSInteger kMATLoadFailedNoFillCode = 20105;

#define dispatch_main_MATASYNC_safe(block)\
        if ([NSThread isMainThread]) {\
        block();\
        } else {\
        dispatch_async(dispatch_get_main_queue(), block);\
        }

static NSString *MATBannerAdTypeDes(NSString * _Nullable placementId, NSString * _Nullable msg) {
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    dic[@"placementId"] = placementId ?: @"";
    dic[@"adType"] = @(kAdTypeBanner);
    dic[@"source"] = kAdapterSource;
    if (msg.length) {
        dic[@"msg"] = msg;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
}

@interface ISMaticooCustomBanner () <MATBannerAdDelegate>
@property (nonatomic, strong) MATBannerAd *banner;
@property (nonatomic, strong) ISBannerSize *bannerSize;
@property (nonatomic, weak) id<ISBannerAdDelegate> iSDelegate;
@property (nonatomic, copy) NSString *placementId;
@end

@implementation ISMaticooCustomBanner

// load / destroy 虽 hop 到主线程，IronSource 不保证在主线程释放 adapter。
// ARC 并发读写 nonatomic strong 会读到哨兵指针 0x400000000000bad0，读写必须同锁。
// 持锁只保护指针交换；拿到局部变量后再调 SDK。
@synthesize banner = _banner;

- (MATBannerAd *)banner {
    @synchronized (self) {
        return _banner;
    }
}

- (void)setBanner:(MATBannerAd *)banner {
    @synchronized (self) {
        _banner = banner;
    }
}

- (void)loadAdWithAdData:(nonnull ISAdData *)adData
          viewController:(UIViewController *)viewController
                    size:(ISBannerSize *)size
                delegate:(nonnull id<ISBannerAdDelegate>)delegate {
    dispatch_main_MATASYNC_safe(^{
        if (adData == nil || viewController == nil) {
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATBannerAdTypeDes(nil, @"params is error")];
            if ([delegate respondsToSelector:@selector(adDidFailToLoadWithErrorType:errorCode:errorMessage:)]) {
                [delegate adDidFailToLoadWithErrorType:ISAdapterErrorTypeInternal errorCode:-1 errorMessage:@"params is error"];
            }
            return;
        }

        id placementIdValue = [adData getString:@"placement_id"];
        NSString *placementId = [placementIdValue isKindOfClass:[NSString class]] ? (NSString *)placementIdValue : nil;
        if (placementId.length == 0) {
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATBannerAdTypeDes(nil, @"placement_id is nil")];
            if ([delegate respondsToSelector:@selector(adDidFailToLoadWithErrorType:errorCode:errorMessage:)]) {
                [delegate adDidFailToLoadWithErrorType:ISAdapterErrorTypeInternal errorCode:1 errorMessage:@"zMaticoo Adapter Banner Error: placementId is nil"];
            }
            return;
        }

        self.placementId = placementId;
        self.iSDelegate = delegate;
        self.bannerSize = size;

        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load" des:MATBannerAdTypeDes(placementId, nil)];

        MATBannerAd *banner = [[MATBannerAd alloc] initWithPlacementID:placementId];
        banner.delegate = self;
        banner.localExtra = @{ @"source" : kAdapterSource };
        if ([adData getBoolean:@"can_close_ad"]) {
            banner.canCloseAd = YES;
        }
        self.banner = banner;
        [banner loadAd];
    });
}

- (void)destroyAdWithAdData:(nonnull ISAdData *)adData {
    dispatch_main_MATASYNC_safe(^{
        MATBannerAd *ad = nil;
        @synchronized (self) {
            ad = _banner;
            _banner = nil;
        }
        if (ad) {
            ad.delegate = nil;
            [ad destroy];
        }
        self.iSDelegate = nil;
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy" des:MATBannerAdTypeDes(self.placementId, nil)];
    });
}

#pragma mark - MATBannerAdDelegate

- (void)bannerAdDidLoad:(MATBannerAd *)nativeBannerAd {
    CGFloat w = self.bannerSize.width;
    CGFloat h = self.bannerSize.height;
    if (w > 0 && h > 0) {
        nativeBannerAd.frame = CGRectMake(0, 0, w, h);
    }
    id<ISBannerAdDelegate> del = self.iSDelegate;
    if (del && [del respondsToSelector:@selector(adDidLoadWithView:)]) {
        [del adDidLoadWithView:nativeBannerAd];
    }
    NSString *msg = del ? @"" : @" ironsourceListener is null";
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success" des:MATBannerAdTypeDes(self.placementId, msg)];
}

- (void)bannerAd:(nonnull MATBannerAd *)nativeBannerAd didFailWithError:(nonnull NSError *)error {
    ISAdapterErrorType type = ISAdapterErrorTypeInternal;
    NSInteger code = error.code;
    if (code == kMATLoadFailedNoFillCode) {
        type = ISAdapterErrorTypeNoFill;
    }
    id<ISBannerAdDelegate> del = self.iSDelegate;
    if (del && [del respondsToSelector:@selector(adDidFailToLoadWithErrorType:errorCode:errorMessage:)]) {
        [del adDidFailToLoadWithErrorType:type errorCode:code errorMessage:error.localizedDescription ?: @""];
    }
    NSString *msg = del ? @"" : @" ironsourceListener is null";
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATBannerAdTypeDes(self.placementId, msg)];
}

- (void)bannerAdDidClick:(nonnull MATBannerAd *)nativeBannerAd {
    id<ISBannerAdDelegate> del = self.iSDelegate;
    if (del && [del respondsToSelector:@selector(adDidClick)]) {
        [del adDidClick];
    }
    NSString *msg = del ? @"" : @" ironsourceListener is null";
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click" des:MATBannerAdTypeDes(self.placementId, msg)];
}

- (void)bannerAdDidImpression:(nonnull MATBannerAd *)nativeBannerAd {
    id<ISBannerAdDelegate> del = self.iSDelegate;
    if (del && [del respondsToSelector:@selector(adDidOpen)]) {
        [del adDidOpen];
    }
    NSString *msg = del ? @"" : @" maxLister is null";
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp" des:MATBannerAdTypeDes(self.placementId, msg)];
}

- (void)bannerAdDismissed:(nonnull MATBannerAd *)nativeBannerAd {
}

- (void)bannerAd:(MATBannerAd *)bannerAd showFailWithError:(NSError *)error {
    NSString *errMsg = error.localizedDescription ?: @"";
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATBannerAdTypeDes(self.placementId, errMsg)];
    id<ISBannerAdDelegate> del = self.iSDelegate;
    if (del && [del respondsToSelector:@selector(adDidFailToShowWithErrorCode:errorMessage:)]) {
        [del adDidFailToShowWithErrorCode:error.code errorMessage:errMsg];
    }
}

- (void)bannerAdDidLeaveApp:(MATBannerAd *)nativeBannerAd {
    id<ISBannerAdDelegate> del = self.iSDelegate;
    if (del && [del respondsToSelector:@selector(adWillLeaveApplication)]) {
        [del adWillLeaveApplication];
    }
}

- (void)dealloc {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy" des:MATBannerAdTypeDes(_placementId, nil)];
    // IronSource 不保证在主线程释放 adapter；MATBannerAd 是 UIView 子类，destroy 会拆 subview / 改 layer，
    // 子线程触碰会触发 _UIViewWillDestructorAssertion。先把强引用搬出来再异步到主线程 destroy。
    MATBannerAd *ad = nil;
    @synchronized (self) {
        ad = _banner;
        _banner = nil;
    }
    ad.delegate = nil;
    if (ad) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ad destroy];
        });
    }
}

@end
