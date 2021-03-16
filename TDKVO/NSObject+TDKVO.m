//
//  NSObject+TDKVO.m
//  TDKVO
//
//  Created by xzkj on 2021/3/15.
//

#import "NSObject+TDKVO.h"
//#import <objc/runtime.h>
#import <objc/message.h>

static NSString *const kTDKVOPrefix = @"TDKVONotifying_";
static NSString *const kTDKVOAssiociateKey = @"kTDKVO_AssiociateKey";
static NSString *const kTDKVOAssiociateNewValues = @"kTDKVO_AssiociateNewValue";

@implementation NSObject (TDKVO)

- (void)td_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(TDKeyValueObservingOptions)options context:(nullable void *)context{
    
    // 自定义KVO
    // 1: 模拟系统
    // 2: 移除观察者 - 自动移除
    // 3: 响应式+函数式
    
    // 1: 验证是否存在setter方法 : 不让实例进来
    [self judgeSetterMethodFromKeyPath:keyPath];
    // 2: 动态生成子类
    Class newClass = [self createChildClassWithKeyPath:keyPath];
    //  2.1 申请类
    //  2.2 注册
    //  2.3 添加方法
    // 3: isa 指向
    object_setClass(self, newClass);
    
    // 4: 保存观察者信息
    TDKVOInfo * info = [[TDKVOInfo alloc] initWitObserver:observer forKeyPath:keyPath options:options];
    //因为分类无法添加属性，所以这里使用关联对象
    NSMutableArray * observerArray = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(kTDKVOAssiociateKey));
    //先查看关联对象中是否已经存在改键值的观察信息如果不存在则添加关联对象
    if(!observerArray){
        observerArray = [NSMutableArray arrayWithCapacity:1];
        [observerArray addObject:info];
        objc_setAssociatedObject(self, (__bridge const void * _Nonnull)(kTDKVOAssiociateKey), observerArray, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

}

//验证是否有setter方法，没有的话直接抛出异常
-(void)judgeSetterMethodFromKeyPath:(NSString *)keyPath{
    //因为当前还没有更改isa的指向所以这里获取的是调用该方法的类并非中间类
    Class currentClass = object_getClass(self);
    //setter方法sel
    SEL setterSeleter = NSSelectorFromString(setterForGetter(keyPath));
    //从类中获取setter方法
    Method setterMethod = class_getInstanceMethod(currentClass, setterSeleter);
    if(!setterMethod){
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"找不到%@对应的setter方法",keyPath] userInfo:nil];
    }
}

//创建中间类
-(Class)createChildClassWithKeyPath:(NSString *)keyPath{
    //获取使用类的名称
    NSString * oldClassName = NSStringFromClass([self class]);
    //拼接中间类的名称
    NSString * newClassName = [NSString stringWithFormat:@"%@%@",kTDKVOPrefix,oldClassName];
    //先尝试获取中间类，如果能获取到则直接返回
    //应为中间类一旦创建是不会销毁的，所以第一次创建之后再使用可以直接从内存中读取
    Class newClass = NSClassFromString(newClassName);
    if(newClass) return  newClass;
    
    //1.申请类
    newClass = objc_allocateClassPair([self class], newClassName.UTF8String, 0);
    //2.注册类
    objc_registerClassPair(newClass);
    //3.添加属性、方法（主要是添加setter方法）
    SEL setterMethod = NSSelectorFromString(setterForGetter(keyPath));
    Method method = class_getInstanceMethod([self class], setterMethod);
    const char * types = method_getTypeEncoding(method);
    class_addMethod(newClass, setterMethod, (IMP)td_setter, types);
    
    //4. 添加class方法
    SEL classSEL = NSSelectorFromString(@"class");
    Method classMethod = class_getInstanceMethod([self class], classSEL);
    const char *classTypes = method_getTypeEncoding(classMethod);
    class_addMethod(newClass, classSEL, (IMP)td_class, classTypes);
    return newClass;
}

// 子类重写的imp
static void td_setter(id self,SEL _cmd,id newValue){
    //通知监听者并执行父类set方法
    NSLog(@"来了:%@",newValue);
    /**
     两种情况
     1. automaticallyNotifiesObserversForKey:方法返回YES则自动键值观察
     2.automaticallyNotifiesObserversForKey:方法返回NO则需要用户自己实现键值观察方法
     */
    //准备工作
    //获取key
    NSString * setterMethodName = NSStringFromSelector(_cmd);
    NSString * keyPath = getterForSetter(setterMethodName);
    
    //1.从关联对象中拿到观察者信息(可能存在多个观察者所以这里遍历数组获取观察者对象信息)
    NSMutableArray * observerArray = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(kTDKVOAssiociateKey));
    for (NSUInteger i = 0, len = observerArray.count; i < len; i ++) {
        TDKVOInfo * info = observerArray[i];
        if([info.keyPath isEqualToString:keyPath]){
            //先判断是否是当前key值对应的观察对象信息
            //获取观察类automaticallyNotifiesObserversForKey方法的返回值

            SEL automaticallySel = NSSelectorFromString(@"automaticallyNotifiesObserversForKey:");
            /**
             注意点：
             1. 需要在Build Settings中搜索objc_msgSend对应的value修改成NO否则objc_msgSend调用报错
             2. 应为automaticallyNotifiesObserversForKey是类方法所以objc_msgSend的第一个参数也就是
             接受对象应该是对应的类而不是实例对象，所以第一个参数需要传[info.observer class]
             */
            //将新值存储到关联对象中
            NSMutableDictionary * values = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(kTDKVOAssiociateNewValues));
            //先查看关联对象中是否已经存在改键值的观察信息如果不存在则添加关联对象
            if(!values){
                values = [[NSMutableDictionary alloc]init];
            }
            values[keyPath] = newValue;
            values[[NSString stringWithFormat:@"old_%@",keyPath]] = [self valueForKey:keyPath];
            objc_setAssociatedObject(self, (__bridge const void * _Nonnull)(kTDKVOAssiociateNewValues), values, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            BOOL isAuto = objc_msgSend([info.observer class],automaticallySel,keyPath);
            if(isAuto){
                //自动实现键值观察
                [self td_willChangeValueForKey:keyPath];
            }
            
            //最后再调用父类的setter方法
            //注意必须调用父类的setter的方法应为子类的setter方法被重写
            struct objc_super superStruct = {
                .receiver = self,
                .super_class = class_getSuperclass(object_getClass(self)),
            };
            SEL setterSel = NSSelectorFromString(setterForGetter(keyPath));
            objc_msgSendSuper(&superStruct, setterSel,newValue);

        }
        
    }
}

-(void)td_willChangeValueForKey:(NSString *)keyPath{
    //1. 从关联对象中查找出所有的键值观察信息
    NSMutableArray * observerArray = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(kTDKVOAssiociateKey));
    for (NSUInteger i = 0, len = observerArray.count; i < len; i ++) {
        TDKVOInfo * info = observerArray[i];
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSMutableDictionary<NSKeyValueChangeKey,id> *change = [NSMutableDictionary dictionaryWithCapacity:1];
            // 对新旧值进行处理
            NSMutableDictionary * values = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(kTDKVOAssiociateNewValues));
            id newValue = values[keyPath];
            id oldValue = values[[NSString stringWithFormat:@"old_%@",keyPath]];
            if (info.options & TDKeyValueObservingOptionNew) {
                [change setObject:newValue forKey:NSKeyValueChangeNewKey];
            }
            if (info.options & TDKeyValueObservingOptionOld) {
                [change setObject:@"" forKey:NSKeyValueChangeOldKey];
                if (oldValue) {
                    [change setObject:oldValue forKey:NSKeyValueChangeOldKey];
                }
            }
            // 2: 消息发送给观察者
            SEL observerSEL = NSSelectorFromString(@"td_observeValueForKeyPath:ofObject:change:context:");
            objc_msgSend(info.observer,observerSEL,keyPath,[self superclass],change,NULL);
        });
        
    }
}

Class td_class(id self,SEL _cmd){
    return class_getSuperclass(object_getClass(self));
}

- (void)td_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath{
    //1.清除关联对象
    NSMutableArray *observerArr = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(kTDKVOAssiociateKey));
    if (observerArr.count<=0) {
        return;
    }
    
    for (TDKVOInfo *info in observerArr) {
        if ([info.keyPath isEqualToString:keyPath]) {
            [observerArr removeObject:info];
            objc_setAssociatedObject(self, (__bridge const void * _Nonnull)(kTDKVOAssiociateKey), observerArr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            break;
        }
    }

    //2.改变isa的指向
    if (observerArr.count<=0) {
        // 指回给父类
        Class superClass = [self class];
        object_setClass(self, superClass);
    }
    
}

#pragma mark - 遍历方法-ivar-property
- (void)printClassAllMethod:(Class)cls{
    unsigned int count = 0;
    Method *methodList = class_copyMethodList(cls, &count);
    for (int i = 0; i<count; i++) {
        Method method = methodList[i];
        SEL sel = method_getName(method);
        IMP imp = class_getMethodImplementation(cls, sel);
        NSLog(@"%@-%p",NSStringFromSelector(sel),imp);
    }
    free(methodList);
}


//从getter方法命中获取setter方法名key => set<Key>
static NSString * setterForGetter(NSString *getter){
    if(getter.length <= 0) return  nil;
    //获取大写首字母
    NSString * firstString = [[getter substringToIndex:1] uppercaseString];
    //获取首字母后面的字符串
    NSString * otherString = [getter substringFromIndex:1];
    return [NSString stringWithFormat:@"set%@%@:",firstString,otherString];
}

#pragma mark - 从set方法获取getter方法的名称 set<Key>:===> key
static NSString *getterForSetter(NSString *setter){
    
    if (setter.length <= 0 || ![setter hasPrefix:@"set"] || ![setter hasSuffix:@":"]) { return nil;}
    
    NSRange range = NSMakeRange(3, setter.length-4);
    NSString *getter = [setter substringWithRange:range];
    NSString *firstString = [[getter substringToIndex:1] lowercaseString];
    return  [getter stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:firstString];
}

@end
