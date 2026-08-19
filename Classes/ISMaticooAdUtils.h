//
//  ISMaticooAdUtils.h
//  MaticooIronSourceAdapter
//

#import <Foundation/Foundation.h>
#import "IronSource/IronSource.h"

NS_ASSUME_NONNULL_BEGIN

/// 读取 LevelPlay 透传的 `is_muted`（`getString`，仅认 `"true"`/`"false"`）；缺失或非法返回 nil。
FOUNDATION_EXPORT NSNumber * _Nullable ISMaticooMutedFromAdData(ISAdData *adData);

/// 与安卓 `putMutedConfig` + `source` 一致，供 `loadAdExtraMap:` 使用。
FOUNDATION_EXPORT NSDictionary<NSString *, id> *ISMaticooLoadExtraMapFromAdData(ISAdData * _Nullable adData);

NS_ASSUME_NONNULL_END
