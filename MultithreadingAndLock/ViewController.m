//
//  ViewController.m
//  MultithreadingAndLock
//
//  Created by 🍎应俊杰🍎 doublej on 2017/6/14.
//  Copyright © 2017年 doublej. All rights reserved.
//
#ifdef DEBUG
#   define DEBUGLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DEBUGLog(...)
#endif
#define Screen_Width ([UIScreen mainScreen].bounds.size.width)
#define Screen_Height ([UIScreen mainScreen].bounds.size.height)

#import "ViewController.h"
#import <objc/runtime.h>
#import <pthread.h>
#import <libkern/OSAtomic.h>

@interface ViewController ()
{
    NSLock * _lock;
    NSComparator sort;
    UILabel *lab;
    NSMutableString *mutLogStr;
    NSArray *nameArray;
}
//剩余票数
@property(nonatomic,assign) int leftTicketsCount;
@property(nonatomic,assign) int leftTicketsCount0;
@property(nonatomic,strong)NSMutableArray *threadArr;//存放线程数组
@property(nonatomic,strong)NSMutableArray *methodsArr;//存放方法名数组

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    // Do any additional setup after loading the view, typically from a nib.
    /**
     1. @synchronized 关键字加锁
     2. NSLock 对象锁
     3. NSCondition 条件锁1
     4. NSConditionLock 条件锁2
     5. NSRecursiveLock 递归锁
     6. pthread_mutex 互斥锁（C语言）
     7. pthread_mutex(recursive) 互斥锁（C语言）2
     8. dispatch_semaphore 信号量实现加锁（GCD）
     9. OSSpinLock 自旋锁！！！！！（已不安全）
     
     **/
    /**
     数据对象初始化
     **/
    _threadArr      = [[NSMutableArray alloc]init];
    _methodsArr     = [[NSMutableArray alloc]init];
    _lock           = [[NSLock alloc] init];
    mutLogStr       = [[NSMutableString alloc]init];
    
    /**
     界面UI按钮初始化
     **/
    nameArray=[NSArray arrayWithObjects:@"关键字锁-@synchronized",@"对象锁-NSLock",@"条件锁-1NSCondition",@"条件锁2-NSConditionLock",@"递归锁-NSRecursiveLock",@"互斥锁-pthread_mutex",@"互斥锁2-pthread_mutex(recursive)",@"信号量实现加锁-dispatch_semaphore",@"自旋锁-OSSpinLock自旋锁",@"一千万次线程锁空操作性能对比-runLock", nil];

    for (int i=0;i<[nameArray count];i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        button.tag       = i+1;
        [button setTitle:[nameArray objectAtIndex:i] forState:UIControlStateNormal];
        [button setFrame:CGRectMake(20,30+35*i,Screen_Width-40, 25)];
        [self.view addSubview:button];
        [button addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
        CALayer *layer    = [button layer];
        layer.borderColor = [UIColor purpleColor].CGColor;
        layer.borderWidth = 1;
        
    }

    lab  = [[UILabel alloc]init];
    lab.numberOfLines = 0;
    lab.textColor     = [UIColor whiteColor];
    [lab setFrame:CGRectMake(0,30+(35*[nameArray count]),Screen_Width,Screen_Height-(30+35*[nameArray count]))];
    [self.view addSubview:lab];
    CALayer *layer    = [lab layer];
    layer.borderColor = [UIColor whiteColor].CGColor;
    layer.borderWidth = 3;
    /**
     获取所有锁方法
     **/
    unsigned int count;
    Method *methods = class_copyMethodList([self class], &count);
    for (int i = 0; i < count; i++)
    {
        Method method = methods[i];
        SEL selector = method_getName(method);
        NSString *name = NSStringFromSelector(selector);
        
        if ([name hasPrefix:@"sellTickets"]) {
            [_methodsArr addObject:name];
        }
        NSLog(@"方法 名字 ==== %@",name);
        NSLog(@"Test '%@' completed successfuly", [name substringFromIndex:4]);
    }
    /**
     字符串数组排序
     **/
    NSStringCompareOptions comparisonOptions = NSCaseInsensitiveSearch|NSNumericSearch|
    NSWidthInsensitiveSearch|NSForcedOrderingSearch;
    sort = ^(NSString *obj1,NSString *obj2){
        NSRange range = NSMakeRange(0,obj1.length);
        return [obj1 compare:obj2 options:comparisonOptions range:range];
    };
    NSArray *resultArray = [_methodsArr sortedArrayUsingComparator:sort];
    [_methodsArr setArray:resultArray];
    NSLog(@"字符串数组排序结果%@",resultArray);
    
    
    self.leftTicketsCount=100;
}

-(void)meathodGet:(SEL)selector
{
    if (_threadArr.count>0) {
        for (int i=0; i<_threadArr.count; i++) {
            NSThread *thread=[_threadArr objectAtIndex:i];
            [thread  cancel];
            thread = nil;
        }
    }
    [_threadArr removeAllObjects];
    for (int i=0; i<10; i++) {
        NSThread *thread=[[NSThread alloc]initWithTarget:self selector:selector object:nil];
        char chStr = i + 'A';
        thread.name=[NSString stringWithFormat:@"售票员%c",chStr];
        [_threadArr addObject:thread];
        [thread start];
    }
}

/**
 1. @synchronized 关键字加锁
 @synchronized指令实现锁的优点就是我们不需要在代码中显式的创建锁对象，便可以实现锁的机制，但作为一种预防措施，
 @synchronized块会隐式的添加一个异常处理例程来保护代码，该处理例程会在异常抛出的时候自动的释放互斥锁。所以如果不想让隐
 式的异常处理例程带来额外的开销，你可以考虑使用锁对象。
 **/
-(void)sellTickets
 {
        while (1) {
         @synchronized(self){//只能加一把锁 ['sɪŋkrənaɪzd]
             //1.先检查票数
             int count=self.leftTicketsCount;
             if (count>0) {
                    //休眠一段时间
                    sleep(1);
                    //2.票数-1
                    self.leftTicketsCount= count-1;
                    //获取当前线程
                    NSThread *current=[NSThread currentThread];
                 
                 [self logGetStr:[NSString stringWithFormat:@"%@--卖了一张票，还剩余%d张票",current.name,self.leftTicketsCount]];
                 DEBUGLog(@"%@--卖了一张票，还剩余%d张票",current.name,self.leftTicketsCount);
                 }else{
                     //退出线程
                     [NSThread exit];
                 }
             }
        }
}

/**
 2. NSLock 对象锁
 NSLock是我们经常所使用的，除lock和unlock方法外，NSLock还提供了tryLock,lockBeforeDate:两个方法
 tryLock:会尝试加锁，如果锁不可用(已经被锁住)，刚并不会阻塞线程，并返回NO。
 lockBeforeDate:方法会在所指定Date之前尝试加锁，如果在指定时间之前都不能加锁，则返回NO。
 **/
- (void)sellTickets2
{
    while (1) {
        [_lock lock];
        int count=self.leftTicketsCount;
        if (count>0) {
            //休眠一段时间
            sleep(1);
            //2.票数-1
            self.leftTicketsCount= count-1;
            //获取当前线程
            NSThread *current=[NSThread currentThread];
            [self logGetStr:[NSString stringWithFormat:@"%@--卖了一张票，还剩余%d张票",current.name,self.leftTicketsCount]];
            NSLog(@"%@--卖了一张票，还剩余%d张票",current.name,self.leftTicketsCount);
        }else{
            //退出线程
            [NSThread exit];
        }
        [_lock unlock];
    }
}

/**
 3 NSCondition 条件锁1
 一种最基本的条件锁。手动控制线程wait和signal。当我们在使用多线程的时候，普通的锁只是直接的锁与不锁，而我们在处理资源
 共享的时候很多情况下下需要满足一定条件的情况下才能打开这把锁
 
 [condition lock];多用于多线程同时访问、修改同一个数据源，保证在同一时间内数据源只被访问、修改一次，其他线程
 要在lock外等待，只到unlock才可访问

 [condition unlock];与lock 同时使用
 
 [condition wait];让当前线程处于等待状态
 
 [condition signal];CPU发信号告诉线程不用在等待，可以继续执行
 
 使用场1：景图片消息：
 当接受到图片消息的时候，需要异步下载，等到图片下载完成之后，同步数据库，方可通知前端更新UI。此时就需要使用
 NSCondition 的wait
 
 使用场2：数据加载上传：
 位置变化收集经纬度数据，当达到500个点时上传服务器成功后清空（当然这里还有中间层数据中转）。此时就需要使用
 NSCondition 的wait
 
 ，方可通知前端更新UI。此时就需要使用
 NSCondition 的wait
 **/

- (void)sellTickets3
{
    NSCondition *condition   = [[NSCondition alloc] init];
    NSMutableArray *products = [NSMutableArray array];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (1) {
            [condition lock];
            if ([products count] < self.leftTicketsCount) {
                NSLog(@"等待经纬度数据收集...");
                [condition wait];
            }else{
                NSLog(@"经纬度数据满载处理");
                [products removeAllObjects];
            }
            [condition unlock];
        }
        
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (1) {
            [condition lock];
            [products addObject:@"+1"];
            NSLog(@"经纬度数据,点个数:%zi",products.count);
            [condition signal];
            [condition unlock];
            sleep(1);
        }
        
    });

}

/**
 4 NSConditionLock 条件锁 2
 
 **/

- (void)sellTickets4
{
    NSMutableArray *products = [NSMutableArray array];
    NSConditionLock *lock    = [[NSConditionLock alloc]init];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (1) {
            [lock lockWhenCondition:0];
            for (int i=0; i<self.leftTicketsCount; i++) {
                sleep(1);
                [products addObject:@"+1"];
                NSLog(@"正在收集经纬度数据...,点个数:%zi",products.count);
                [self logGetStr:[NSString stringWithFormat:@"正在收集经纬度数据...,点个数:%zi",products.count]];
            }
            [lock unlockWithCondition:[products count]];
            sleep(1);
        }
        
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (1) {
            NSLog(@"等待经纬度数据收集...");
            [self logGetStr:[NSString stringWithFormat:@"等待经纬度数据收集..."]];
            [lock lockWhenCondition:self.leftTicketsCount];
            [products removeAllObjects];
            NSLog(@"经纬度数据收集满载处理");
            [self logGetStr:[NSString stringWithFormat:@"经纬度数据收集满载处理"]];
            [lock unlockWithCondition:[products count]];
        }
        
    });
    
}

/**
 5. NSRecursiveLock 递归锁
 NSRecursiveLock 递归锁 主要用在循环或递归操作中,它可以被同一线程多次请求，而不会引起死锁。
 <NSLock>这是一个典型的死锁情况。在我们的线程中，recursionMethod是递归调用。所以每次进入这个block时，都会去加一次
 锁，从第二次开始，由于锁已经被使用并且没有解锁，所以它要等待锁被解除，这样就导致了死锁，线程被阻塞住了。
 bugLog输出如下信息：
 *** -[NSLock lock]: deadlock (<NSLock: 0x1740daf60> '(null)')
 *** Break on _NSLockError() to debug.
 <NSRecursiveLock>换成递归锁一切正常了
 **/
- (void)sellTickets5
{
//    NSLock *recursiveLock = [[NSLock alloc] init];
    NSRecursiveLock *recursiveLock = [[NSRecursiveLock alloc] init];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        static void (^recursionMethod)(int);
        recursionMethod = ^(int value) {
            
            [recursiveLock lock];
            if (value > 0) {
                
                NSLog(@"value = %d", value);
                [self logGetStr:[NSString stringWithFormat:
                                 @"value = %d", value]];
                sleep(1);
                recursionMethod(value - 1);
            }
            [recursiveLock unlock];
        };
        recursionMethod(5);
    });
}
/**
 6. pthread_mutex 互斥锁（C语言）
 c语言定义下多线程加锁方式。
 
 1：pthread_mutex_init(pthread_mutex_t mutex,const pthread_mutexattr_t attr);
    初始化锁变量mutex。attr为锁属性，NULL值为默认属性。
 2：pthread_mutex_lock(pthread_mutex_t mutex);加锁
 3：pthread_mutex_tylock(*pthread_mutex_t *mutex);加锁，当锁已经在使用的时候，返回为
    EBUSY，而不是挂起等待。
 4：pthread_mutex_unlock(pthread_mutex_t *mutex);释放锁
 5：pthread_mutex_destroy(pthread_mutex_t* mutex);使用完后释放
 **/
- (void)sellTickets6
{
    __block pthread_mutex_t theLock;
    pthread_mutex_init(&theLock, NULL);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        pthread_mutex_lock(&theLock);
        NSLog(@"电脑开机...");
        sleep(1);
        NSLog(@"输入密码...");
        pthread_mutex_unlock(&theLock);
        
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(2);
        pthread_mutex_lock(&theLock);
        NSLog(@"进入桌面");
        pthread_mutex_unlock(&theLock);
        
    });
}

/**
 7. pthread_mutex(recursive) 互斥锁（C语言）2
 **/
-(void)sellTickets7
{
    __block pthread_mutex_t theLock;
//    pthread_mutex_init(&theLock, NULL);
    
    pthread_mutex_t Mutex;
    pthread_mutexattr_t Attr;
    
    pthread_mutexattr_init(&Attr);
    pthread_mutexattr_settype(&Attr, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&Mutex, &Attr);
    pthread_mutexattr_destroy(&Attr);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        static void (^recursionMethod)(int);
        
        recursionMethod = ^(int value) {
            
            pthread_mutex_lock(&theLock);
            if (value > 0) {
                
                NSLog(@"value = %d", value);
                sleep(1);
                recursionMethod(value - 1);
            }
            pthread_mutex_unlock(&theLock);
        };
        
        recursionMethod(self.leftTicketsCount);
    });

}

/**
 8. dispatch_semaphore 信号量实现加锁（GCD）
 dispatch_semaphore是GCD用来同步的一种方式，与他相关的共有三个函数，分别是
 dispatch_semaphore_create，
 dispatch_semaphore_signal，dispatch_semaphore_wait。
 **/

-(void)sellTickets8
{
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(1);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0; i < self.leftTicketsCount0; i++)
        {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                int count=self.leftTicketsCount;
                if (count>0) {
                    //休眠一段时间
                    sleep(1);
                    //2.票数-1
                    self.leftTicketsCount= count-1;
                    NSThread *current=[NSThread currentThread];
                    //获取当前线程
                    NSLog(@"%@--卖了一张票，还剩余%d张票",current,self.leftTicketsCount);
                }
                dispatch_semaphore_signal(semaphore);
            });
            
        }
    });
        NSLog(@"我是主线程");
}
/**
 9. OSSpinLock 自旋锁！！！！！（已不安全不推荐使用,谨慎使用）
 OSSpinLock 自旋锁，性能最高的锁.因为其是一直等待状态，因此对CUP要求很高，消耗大量CPU资源
 不适宜长时使用，耗电，好资源发热高
 OSSpinLock已经不再安全@"http://blog.ibireme.com/2016/01/16/spinlock_is_unsafe_in_ios/"
  **/

- (void)sellTickets9
{
    __block OSSpinLock theLock = OS_SPINLOCK_INIT;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        OSSpinLockLock(&theLock);
        NSLog(@"电脑开机...");
        sleep(2);
        NSLog(@"输入密码...");
        OSSpinLockUnlock(&theLock);
        
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        OSSpinLockLock(&theLock);
        sleep(1);
        NSLog(@"进入桌面");
        OSSpinLockUnlock(&theLock);
        
    });
    
}

-(void)buttonClicked:(UIButton*)btAction
{
    [mutLogStr setString:[NSString stringWithFormat:@"** %@\n",[nameArray objectAtIndex:btAction.tag-1]]];
    self.leftTicketsCount  = 5;
    self.leftTicketsCount0 = 5;
    
    if (btAction.tag<=2) {//1. @synchronized 关键字加锁
        
        SEL selector = NSSelectorFromString([_methodsArr objectAtIndex:btAction.tag-1]);
        [self meathodGet:selector];
        
    }else{
        SEL selector = NSSelectorFromString([_methodsArr objectAtIndex:btAction.tag-1]);
        [self performSelector:selector];
    }
    
}

/**
 一千万次线程锁空操作性能对比-sellTickets10
 **/
- (void)sellTickets10{

    NSMutableDictionary *sortDic   = [[NSMutableDictionary alloc]init];
    NSString *timestr;
    CFTimeInterval timeBefore;
    CFTimeInterval timeCurrent;
    NSUInteger i;
    NSUInteger count = 1000*10000;//执行一千万次
    
    //OSSpinLockLock自旋锁  ！！！！！（已不安全）CFAbsoluteTimeGetCurrent
    OSSpinLock spinlock = OS_SPINLOCK_INIT;
    timeBefore = CACurrentMediaTime();
    for(i=0; i<count; i++){
        OSSpinLockLock(&spinlock);
        OSSpinLockUnlock(&spinlock);
    }
    timeCurrent = CACurrentMediaTime();
    timestr = [NSString stringWithFormat:@"%f",timeCurrent-timeBefore];
    [sortDic setValue:@"OSSpinLock" forKey:timestr];
    
    //@synchronized关键字加锁
    id obj = [[NSObject alloc]init];;
    timeBefore = CACurrentMediaTime();
    for(i=0; i<count; i++){
        @synchronized(obj){
        }
    }
    timeCurrent = CACurrentMediaTime();
    timestr = [NSString stringWithFormat:@"%f",timeCurrent-timeBefore];
    [sortDic setValue:@"@synchronized" forKey:timestr];
    
    //NSLock对象锁
    NSLock *lock = [[NSLock alloc]init];
    timeBefore = CACurrentMediaTime();
    for(i=0; i<count; i++){
        [lock lock];
        [lock unlock];
    }
    timeCurrent = CACurrentMediaTime();
    timestr = [NSString stringWithFormat:@"%f",timeCurrent-timeBefore];
    [sortDic setValue:@"NSLock" forKey:timestr];
    
    //NSCondition条件锁1
    NSCondition *condition = [[NSCondition alloc]init];
    timeBefore = CACurrentMediaTime();
    for(i=0; i<count; i++){
        [condition lock];
        [condition unlock];
    }
    timeCurrent = CACurrentMediaTime();
    timestr = [NSString stringWithFormat:@"%f",timeCurrent-timeBefore];
    [sortDic setValue:@"NSCondition" forKey:timestr];

    //NSConditionLock条件锁2
    NSConditionLock *conditionLock = [[NSConditionLock alloc]init];
    timeBefore = CACurrentMediaTime();
    for(i=0; i<count; i++){
        [conditionLock lock];
        [conditionLock unlock];
    }
    timeCurrent = CACurrentMediaTime();
    timestr = [NSString stringWithFormat:@"%f",timeCurrent-timeBefore];
    [sortDic setValue:@"NSConditionLock" forKey:timestr];

    //NSRecursiveLock递归锁
    NSRecursiveLock *recursiveLock = [[NSRecursiveLock alloc]init];
    timeBefore = CACurrentMediaTime();
    for(i=0; i<count; i++){
        [recursiveLock lock];
        [recursiveLock unlock];
    }
    timeCurrent = CACurrentMediaTime();
    timestr = [NSString stringWithFormat:@"%f",timeCurrent-timeBefore];
    [sortDic setValue:@"NSRecursiveLock" forKey:timestr];
    
    //pthread_mutex互斥锁1（C语言）
    pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
    timeBefore = CACurrentMediaTime();
    for(i=0; i<count; i++){
        pthread_mutex_lock(&mutex);
        pthread_mutex_unlock(&mutex);
    }
    timeCurrent = CACurrentMediaTime();
    timestr = [NSString stringWithFormat:@"%f",timeCurrent-timeBefore];
    [sortDic setValue:@"pthread_mutexpthread_mutex" forKey:timestr];
    
    //pthread_mutex(recursive)互斥锁2（C语言）
    
    pthread_mutex_t lockrecursive;
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&lockrecursive, &attr);
    pthread_mutexattr_destroy(&attr);
    timeBefore = CACurrentMediaTime();
    for (int i = 0; i < count; i++) {
        pthread_mutex_lock(&lockrecursive);
        pthread_mutex_unlock(&lockrecursive);
    }
    timeCurrent = CACurrentMediaTime();
    timestr = [NSString stringWithFormat:@"%f",timeCurrent-timeBefore];
    [sortDic setValue:@"pthread_mutex(recursive)" forKey:timestr];
    
    
    
    //dispatch_semaphore信号量实现加锁（GCD）
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(1);
    timeBefore = CACurrentMediaTime();
    for(i=0; i<count; i++){
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        dispatch_semaphore_signal(semaphore);
    }
    timeCurrent = CACurrentMediaTime();
    timestr = [NSString stringWithFormat:@"%f",timeCurrent-timeBefore];
    [sortDic setValue:@"dispatch_semaphore" forKey:timestr];

    DEBUGLog(@"sortDic===%@",sortDic);
    NSArray *resultArray = [[sortDic allKeys] sortedArrayUsingComparator:sort];
    NSMutableAttributedString *contentForgeta  = [[NSMutableAttributedString alloc]initWithString:mutLogStr];
    for (int i=0;i<[resultArray count];i++) {
     
     NSMutableAttributedString *contentForget = [[NSMutableAttributedString alloc]initWithString:[NSString stringWithFormat:@"** %i.%@----%@\n",i+1,[sortDic objectForKey:[resultArray objectAtIndex:i]],[resultArray objectAtIndex:i]]];
     NSRange contentRange = {contentForget.length-9,8};
     [contentForget addAttribute:NSForegroundColorAttributeName
                           value:[UIColor redColor]
                           range:contentRange];
     [contentForget addAttribute:NSUnderlineStyleAttributeName
                           value:[NSNumber numberWithInteger:NSUnderlineStyleSingle]
                           range:contentRange];
    [contentForgeta appendAttributedString:contentForget];
     
    }
    lab.attributedText = contentForgeta;
    DEBUGLog(@"%@",lab.text);

}

-(void)logGetStr:(NSString*)logStr
{
    [mutLogStr appendString:[NSString stringWithFormat:@"** %@\n",logStr]];
    dispatch_async(dispatch_get_main_queue(), ^{
        lab.text = mutLogStr;
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
