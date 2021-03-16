//
//  ViewController.m
//  TDKVO
//
//  Created by xzkj on 2021/3/15.
//

#import "ViewController.h"
#import "TDPerson.h"
#import "NSObject+TDKVO.h"

@interface ViewController ()

@property (nonatomic, strong) TDPerson *person;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.person = [TDPerson new];
    [self.person td_addObserver:self forKeyPath:@"nickName" options:TDKeyValueObservingOptionNew context:nil];
    [self.person class];
    // Do any additional setup after loading the view.
}

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    self.person.nickName = [NSString stringWithFormat:@"+%@",self.person.nickName];
}


+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key{
    return YES;
}


-(void)td_observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    NSLog(@"sdf");
}

@end
