//
//  ISMaticooCustomAdapter.m
//  IronSourceDemoApp
//
//  Created by root on 2023/7/13.
//  Copyright © 2023 supersonic. All rights reserved.
//

#import "ISMaticooCustomAdapter.h"
#import "ISMaticooAdUtils.h"
#import <MaticooSDK/MaticooAds.h>

NSNumber *ISMaticooMutedFromAdData(ISAdData *adData) {
    if (!adData) {
        return nil;
    }
    NSString *value = [adData getString:@"is_muted"];
    if (![value isKindOfClass:[NSString class]]) {
        return nil;
    }
    value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([value caseInsensitiveCompare:@"true"] == NSOrderedSame) {
        return @YES;
    }
    if ([value caseInsensitiveCompare:@"false"] == NSOrderedSame) {
        return @NO;
    }
    return nil;
}

NSDictionary<NSString *, id> *ISMaticooLoadExtraMapFromAdData(ISAdData *adData) {
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    map[@"source"] = @"ironsource";
    NSNumber *isMuted = ISMaticooMutedFromAdData(adData);
    if (isMuted != nil) {
        map[@"is_muted"] = isMuted;
    }
    return [map copy];
}

@implementation ISMaticooCustomAdapter

- (void)init:(ISAdData *)adData delegate:(id<ISNetworkInitializationDelegate>)delegate {
    id appKeyValue = [adData getString:@"app_key"];
    NSString *appKey = [appKeyValue isKindOfClass:[NSString class]] ? (NSString *)appKeyValue : nil;
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
