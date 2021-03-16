//
//  TDKVOInfo.h
//  TDKVO
//
//  Created by xzkj on 2021/3/15.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, TDKeyValueObservingOptions) {

    TDKeyValueObservingOptionNew = 0x01,
    TDKeyValueObservingOptionOld = 0x02,
};
@interface TDKVOInfo : NSObject

@property (nonatomic, weak) NSObject  *observer;
@property (nonatomic, copy) NSString    *keyPath;
@property (nonatomic, assign) TDKeyValueObservingOptions options;

- (instancetype)initWitObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(TDKeyValueObservingOptions)options;
@end

NS_ASSUME_NONNULL_END
