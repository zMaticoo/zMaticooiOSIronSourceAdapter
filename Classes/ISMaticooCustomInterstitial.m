//
//  ISMaticooCustomInterstitial.m
//  IronSourceDemoApp
//
//  Created by root on 2023/7/13.
//  Copyright © 2023 supersonic. All rights reserved.
//

#import "ISMaticooCustomInterstitial.h"
#import <MaticooSDK/MATInterstitialAd.h>
#import "MaticooMediationTrackManager.h"
#import <MaticooSDK/MaticooAds.h>

@interface ISMaticooCustomInterstitial()<MATInterstitialAdDelegate>
@property (nonatomic, strong) MATInterstitialAd *interstitial;
@property (nonatomic, weak) id<ISInterstitialAdDelegate> iSDelegate;
@end

@implementation ISMaticooCustomInterstitial

- (void)loadAdWithAdData:(nonnull ISAdData *)adData
                delegate:(nonnull id<ISInterstitialAdDelegate>)delegate {
    NSString *placementId = [adData getString:@"placement_id"];
    if (placementId == nil){
        [delegate adDidFailToLoadWithErrorType:ISAdapterErrorTypeInternal errorCode:1 errorMessage:@"zMaticoo Adapter Interstitial Error: placementId is nil"];
        return;
    }
    self.iSDelegate = delegate;
    [MaticooMediationTrackManager trackMediationAdRequest:placementId adType:INTERSTITIAL isAutoRefresh:NO];
    self.interstitial = [[MATInterstitialAd alloc] initWithPlacementID:placementId];
    self.interstitial.delegate = self;
    [self.interstitial loadAd];
}

- (BOOL)isAdAvailableWithAdData:(nonnull ISAdData *)adData {
    if (self.interstitial){
        return [self.interstitial isReady];
    }else{
        return NO;
    }
}

- (void)showAdWithViewController:(nonnull UIViewController *)viewController
                          adData:(nonnull ISAdData *)adData
                        delegate:(nonnull id<ISInterstitialAdDelegate>)delegate {
    if (![self.interstitial isReady]){
        [delegate adDidFailToShowWithErrorCode:ISAdapterErrorInternal
                                        errorMessage:@"zMaticoo Adapter Error : interstitial is not ready"];
        return;
    }
    [self.interstitial showAdFromViewController:viewController];
    [MaticooMediationTrackManager trackMediationAdShow:self.interstitial.placementID adType:INTERSTITIAL];
}

- (void)interstitialAdDidLoad:(nonnull MATInterstitialAd *)interstitialAd {
    [self.iSDelegate adDidLoad];
    [MaticooMediationTrackManager trackMediationAdRequestFilled:interstitialAd.placementID adType:INTERSTITIAL];
}

- (void)interstitialAd:(nonnull MATInterstitialAd *)interstitialAd didFailWithError:(nonnull NSError *)error {
    [self.iSDelegate adDidFailToLoadWithErrorType:ISAdapterErrorTypeInternal errorCode:2 errorMessage:error.description];
    [MaticooMediationTrackManager trackMediationAdRequestFailed:interstitialAd.placementID adType:INTERSTITIAL msg:error.description];
}

- (void)interstitialAd:(nonnull MATInterstitialAd *)interstitialAd displayFailWithError:(nonnull NSError *)error {
    [self.iSDelegate adDidFailToShowWithErrorCode:1 errorMessage:error.description];
    [MaticooMediationTrackManager trackMediationAdImpFailed:interstitialAd.placementID adType:INTERSTITIAL msg:error.description];
}

- (void)interstitialAdDidClick:(nonnull MATInterstitialAd *)interstitialAd {
    [self.iSDelegate adDidClick];
    [MaticooMediationTrackManager trackMediationAdClick:interstitialAd.placementID adType:INTERSTITIAL];
}

- (void)interstitialAdDidClose:(nonnull MATInterstitialAd *)interstitialAd {
    [self.iSDelegate adDidClose];
}

- (void)interstitialAdWillClose:(nonnull MATInterstitialAd *)interstitialAd {
    
}

- (void)interstitialAdWillLogImpression:(nonnull MATInterstitialAd *)interstitialAd {
    [self.iSDelegate adDidOpen];

    [MaticooMediationTrackManager trackMediationAdImp:interstitialAd.placementID adType:INTERSTITIAL];
}

@end
