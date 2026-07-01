//
//  ISMaticooCustomAdapter.m
//  IronSourceDemoApp
//
//  Created by root on 2023/7/13.
//  Copyright © 2023 supersonic. All rights reserved.
//

#import "ISMaticooCustomAdapter.h"
#import <MaticooSDK/MaticooAds.h>

@implementation ISMaticooCustomAdapter

- (void)init:(ISAdData *)adData delegate:(id<ISNetworkInitializationDelegate>)delegate {
    NSString *appKey = [adData getString:@"app_key"];
    if (appKey.length == 0) {
        if ([delegate respondsToSelector:@selector(onInitDidFailWithErrorCode:errorMessage:)]) {
            [delegate onInitDidFailWithErrorCode:ISAdapterErrorMissingParams errorMessage:@"zMaticoo Adapter Error: app key is empty"];
        }
        return;
    }

    [[MaticooAds shareSDK] setMediationName:@"ironsource"];
    [[MaticooAds shareSDK] initSDK:appKey onSuccess:^{
        if ([delegate respondsToSelector:@selector(onInitDidSucceed)]) {
            [delegate onInitDidSucceed];
        }
    } onError:^(NSError *error) {
        NSString *des = [NSString stringWithFormat:@"{\"source\":\"ironsource\",\"msg\":\"%@\"}", error.localizedDescription ?: @""];
        if ([delegate respondsToSelector:@selector(onInitDidFailWithErrorCode:errorMessage:)]) {
            [delegate onInitDidFailWithErrorCode:ISAdapterErrorInternal errorMessage:des];
        }
    }];
}

- (NSString *)networkSDKVersion {
    return [[MaticooAds shareSDK] getSDKVersion];
}

- (NSString *)adapterVersion {
    return [[MaticooAds shareSDK] getSDKVersion];
}

- (void)setMetaDataWithKey:(NSString *)key andValues:(NSMutableArray *)values {
}

- (void)setConsent:(BOOL)consent {
}

@end
