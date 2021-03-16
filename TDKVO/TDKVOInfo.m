//
//  TDKVOInfo.m
//  TDKVO
//
//  Created by xzkj on 2021/3/15.
//

#import "TDKVOInfo.h"

@implementation TDKVOInfo

- (instancetype)initWitObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(TDKeyValueObservingOptions)options{
    self = [super init];
    if (self) {
        self.observer = observer;
        self.keyPath  = keyPath;
        self.options  = options;
    }
    return self;
}

@end
