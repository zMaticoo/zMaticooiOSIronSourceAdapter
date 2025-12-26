//
//  ISMaticooCustomRewardedVideo.h
//  IronSourceDemoApp
//
//  Created by root on 2023/7/13.
//  Copyright © 2023 supersonic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IronSource/IronSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface ISMaticooCustomRewardedVideo : ISBaseRewardedVideo
- (void)loadAdWithAdData:(nonnull ISAdData *)adData
                delegate:(nonnull id<ISRewardedVideoAdDelegate>)delegate;

- (BOOL)isAdAvailableWithAdData:(nonnull ISAdData *)adData;

- (void)showAdWithViewController:(nonnull UIViewController *)viewController
                          adData:(nonnull ISAdData *)adData
                        delegate:(nonnull id<ISRewardedVideoAdDelegate>)delegate;
@end

NS_ASSUME_NONNULL_END
