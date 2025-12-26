//
//  ISMaticooCustomBanner.m
//  IronSourceDemoApp
//
//  Created by root on 2023/7/13.
//  Copyright © 2023 supersonic. All rights reserved.
//

#import "ISMaticooCustomBanner.h"
#import <MaticooSDK/MATBannerAd.h>
#import "MaticooMediationTrackManager.h"
#import <MaticooSDK/MaticooAds.h>


#define dispatch_main_MATASYNC_safe(block)\
        if ([NSThread isMainThread]) {\
        block();\
        } else {\
        dispatch_async(dispatch_get_main_queue(), block);\
        }


@interface ISMaticooCustomBanner()<MATBannerAdDelegate>
@property (nonatomic, strong) MATBannerAd *banner;
@property (nonatomic, strong) ISBannerSize *bannerSize;
@property (nonatomic, weak) id<ISBannerAdDelegate> iSDelegate;
@end

@implementation ISMaticooCustomBanner

- (void)loadAdWithAdData:(nonnull ISAdData *)adData
          viewController:(UIViewController *)viewController
                    size:(ISBannerSize *)size
                delegate:(nonnull id<ISBannerAdDelegate>)delegate {
    dispatch_main_MATASYNC_safe(^{
        NSString *placementId = [adData getString:@"placement_id"];
        if (placementId == nil){
            [delegate adDidFailToLoadWithErrorType:ISAdapterErrorTypeInternal errorCode:1 errorMessage:@"zMaticoo Adapter Banner Error: placementId is nil"];
            return;
        }
        self.iSDelegate = delegate;
        self.bannerSize = size;
        [MaticooMediationTrackManager trackMediationAdRequest:placementId adType:BANNER isAutoRefresh:NO];
        self.banner = [[MATBannerAd alloc] initWithPlacementID:placementId];
        self.banner.delegate = self;
        [self.banner loadAd];
    });
}

- (void)bannerAdDidLoad:(MATBannerAd *)nativeBannerAd{
    nativeBannerAd.frame = CGRectMake(0, 0, self.bannerSize.width, self.bannerSize.height);
    [self.iSDelegate adDidLoadWithView:nativeBannerAd];
    [MaticooMediationTrackManager trackMediationAdRequestFilled:nativeBannerAd.placementID adType:BANNER];
    
}

- (void)bannerAd:(nonnull MATBannerAd *)nativeBannerAd didFailWithError:(nonnull NSError *)error {
    [self.iSDelegate adDidFailToLoadWithErrorType:ISAdapterErrorTypeInternal errorCode:2 errorMessage:error.description];
    [MaticooMediationTrackManager trackMediationAdRequestFailed:nativeBannerAd.placementID adType:BANNER msg:error.description];
}

- (void)bannerAdDidClick:(nonnull MATBannerAd *)nativeBannerAd {
    [self.iSDelegate adDidClick];
    [MaticooMediationTrackManager trackMediationAdClick:nativeBannerAd.placementID adType:BANNER];
}

- (void)bannerAdDidImpression:(nonnull MATBannerAd *)nativeBannerAd {
    [self.iSDelegate adDidOpen];
    [MaticooMediationTrackManager trackMediationAdImp:nativeBannerAd.placementID adType:BANNER];
}

- (void)bannerAdDismissed:(nonnull MATBannerAd *)nativeBannerAd{
//    [self.iSDelegate adDidClose];
}

- (void)bannerAd:(MATBannerAd *)bannerAd showFailWithError:(NSError *)error {
    //Show Failed
    
}
@end
