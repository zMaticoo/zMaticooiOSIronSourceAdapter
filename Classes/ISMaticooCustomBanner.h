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

@interface ISMaticooCustomBanner : ISBaseBanner
- (void)loadAdWithAdData:(nonnull ISAdData *)adData
          viewController:(UIViewController *)viewController
                    size:(ISBannerSize *)size
                delegate:(nonnull id<ISBannerAdDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
