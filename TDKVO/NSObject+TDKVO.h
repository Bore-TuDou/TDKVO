//
//  NSObject+TDKVO.h
//  TDKVO
//
//  Created by xzkj on 2021/3/15.
//

#import <Foundation/Foundation.h>
#import "TDKVOInfo.h"

NS_ASSUME_NONNULL_BEGIN
@interface NSObject (TDKVO)

- (void)td_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(TDKeyValueObservingOptions)options context:(nullable void *)context;

- (void)td_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath;

@end

NS_ASSUME_NONNULL_END
