//
//  ISMaticooCustomInterstitial.h
//  IronSourceDemoApp
//
//  Created by root on 2023/7/13.
//  Copyright © 2023 supersonic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IronSource/IronSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface ISMaticooCustomInterstitial : ISBaseInterstitial
- (void)loadAdWithAdData:(nonnull ISAdData *)adData
                delegate:(nonnull id<ISInterstitialAdDelegate>)delegate;

- (BOOL)isAdAvailableWithAdData:(nonnull ISAdData *)adData;

- (void)showAdWithViewController:(nonnull UIViewController *)viewController
                          adData:(nonnull ISAdData *)adData
                        delegate:(nonnull id<ISInterstitialAdDelegate>)delegate;
@end

NS_ASSUME_NONNULL_END
