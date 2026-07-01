//
//  MaticooIronSourceAdapterDebugLog.h
//  Optional NSLog-style traces for MaticooIronSourceAdapter (off unless MATICOO_IRONSOURCE_ADAPTER_LOG is set).
//

#ifndef MaticooIronSourceAdapterDebugLog_h
#define MaticooIronSourceAdapterDebugLog_h

#ifdef MATICOO_IRONSOURCE_ADAPTER_LOG
#define MaticooIronSourceAdapterDebugLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#define MaticooIronSourceAdapterDebugLog(...)
#endif

#endif /* MaticooIronSourceAdapterDebugLog_h */
