//
//  ISMaticooCustomAdapter.h
//  IronSourceDemoApp
//
//  Created by root on 2023/7/13.
//  Copyright © 2023 supersonic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IronSource/IronSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface ISMaticooCustomAdapter : ISBaseNetworkAdapter
- (void)init:(ISAdData *)adData delegate:(id<ISNetworkInitializationDelegate>)delegate;
- (NSString *) networkSDKVersion;
- (NSString *) adapterVersion;
@end

NS_ASSUME_NONNULL_END
