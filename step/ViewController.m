//
//  ViewController.m
//  step
//
//  Created by crazypoo on 1/15/14.
//  Copyright (c) 2014 crazypoo. All rights reserved.
//

#import "ViewController.h"
#import <CoreMotion/CoreMotion.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>


@interface ViewController ()
@property (nonatomic, strong) CMStepCounter *stepCounter;
@property (nonatomic, strong) CMMotionActivityManager *activityManager;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, weak) IBOutlet UILabel *stepsLabel;
@property (nonatomic, weak) IBOutlet UILabel *statusLabel;
@property (nonatomic, weak) IBOutlet UILabel *confidenceLabel;
@property (nonatomic, weak) IBOutlet UITextView *records;


@end

@implementation ViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    if (!([CMStepCounter isStepCountingAvailable] || [CMMotionActivityManager isActivityAvailable])) {
        
        NSString *msg = @"Only suppoert iPhone 5s (M7 is needed)";
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Opps!!!"
                                                        message:msg
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        
        [alert show];
        
        return;
    }
    __weak ViewController *weakSelf = self;
    
    self.operationQueue = [[NSOperationQueue alloc] init];
    
    [self createDir];
    
    NSString *filename = [self getCurrentTime]; //use app in
    
    
    NSTimer *_timer;
    _timer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(tik) userInfo:nil repeats:YES];
    
    [self tik];
    
    //更新label
    if ([CMStepCounter isStepCountingAvailable]) {
        
        self.stepCounter = [[CMStepCounter alloc] init];
        
        [self.stepCounter startStepCountingUpdatesToQueue:self.operationQueue
                                                 updateOn:1
                                              withHandler:
         ^(NSInteger numberOfSteps, NSDate *timestamp, NSError *error) {
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 
                 if (error) {
                     UIAlertView *error = [[UIAlertView alloc] initWithTitle:@"Opps!" message:@"error" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
                     [error show];
                 }
                 else {
                     
                     NSString *text = [NSString stringWithFormat:@"步數: %ld", (long)numberOfSteps];
                     
                     weakSelf.stepsLabel.text = text;
                 }
             });
         }];
    }
    
//開波
    if ([CMMotionActivityManager isActivityAvailable]) {
        
        self.activityManager = [[CMMotionActivityManager alloc] init];
        
        [self.activityManager startActivityUpdatesToQueue:self.operationQueue
                                              withHandler:
         ^(CMMotionActivity *activity) {
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 
                 NSString *status = [weakSelf statusForActivity:activity];
                 NSString *confidence = [weakSelf stringFromConfidence:activity.confidence];
                 
                 weakSelf.statusLabel.text = [NSString stringWithFormat:@"Status: %@", status];
                 weakSelf.confidenceLabel.text = [NSString stringWithFormat:@"Speed: %@", confidence];
                 
                 
                 
                 NSString *content = [NSString stringWithFormat:@"%@,%@,%@\n", status, confidence, [self getCurrentTime]];
                 
                 
                 
                 [self writeFile:content :filename];
                 
                 NSLog(@"%@",content);
                 
                 weakSelf.records.text = [weakSelf.records.text stringByAppendingString:content];
                 NSRange range = NSMakeRange(weakSelf.records.text.length - 1, 1); //auto scroll
                 [weakSelf.records scrollRangeToVisible:range];
                 
             });
         }];
    }
}
- (NSString *)statusForActivity:(CMMotionActivity *)activity {
    
    NSMutableString *status = @"".mutableCopy;
    
    if (activity.stationary) {
        
        [status appendString:@"not moving"];
    }
    
    if (activity.walking) {
        
        if (status.length) [status appendString:@", "];
        
        [status appendString:@"on a walking person"];
    }
    
    if (activity.running) {
        
        if (status.length) [status appendString:@", "];
        
        [status appendString:@"on a running person"];
    }
    
    if (activity.automotive) {
        
        if (status.length) [status appendString:@", "];
        
        [status appendString:@"in a vehicle"];
    }
    
    if (activity.unknown || !status.length) {
        
        [status appendString:@"unknown"];
    }
    
    return status;
}
- (NSString *)stringFromConfidence:(CMMotionActivityConfidence)confidence {
    
    switch (confidence) {
            
        case CMMotionActivityConfidenceLow:
            
            return @"Low";
            
        case CMMotionActivityConfidenceMedium:
            
            return @"Medium";
            
        case CMMotionActivityConfidenceHigh:
            
            return @"High";
            
        default:
            
            return nil;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//Creat Dir
- (void)createDir{
    NSString *documentsPath =[self dirDoc];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *testDirectory = [documentsPath stringByAppendingPathComponent:@"test"];
    // 创建目录
    BOOL res=[fileManager createDirectoryAtPath:testDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    if (res) {
        NSLog(@"文件夹创建成功");
    }else
        NSLog(@"文件夹创建失败");
}

//Get Documents path
- (NSString *)dirDoc{
    //[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSLog(@"app_home_doc: %@",documentsDirectory);
    return documentsDirectory;
}

//Write to file
- (void)writeFile:(NSString *)content : (NSString *)filename{
    NSString *documentsPath =[self dirDoc];
    NSString *testDirectory = [documentsPath stringByAppendingPathComponent:@"test"];
    NSString *testPath = [testDirectory stringByAppendingPathComponent:filename];
    
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if(![fileManager fileExistsAtPath:testPath])
    {
        [content writeToFile:testPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    else
    {
        NSFileHandle *myHandle = [NSFileHandle fileHandleForWritingAtPath:testPath];
        [myHandle seekToEndOfFile];
        [myHandle writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
    }
}

- (void)createFile{
    NSString *documentsPath =[self dirDoc];
    NSString *testDirectory = [documentsPath stringByAppendingPathComponent:@"test"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *testPath = [testDirectory stringByAppendingPathComponent:@"test.txt"];
    BOOL res=[fileManager createFileAtPath:testPath contents:nil attributes:nil];
    if (res) {
        NSLog(@"文件创建成功: %@" ,testPath);
    }else
        NSLog(@"文件创建失败");
}

- (NSString*)getCurrentTime{
    NSDate* date = [NSDate date];
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    
    NSString* str = [formatter stringFromDate:date];
    return str;
}


- (void)tik{
    
//    if ([[UIApplication sharedApplication] backgroundTimeRemaining] < 610.0) {
        
//        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil]
//        
//        
//        [[CKAudioTool sharedInstance] playSound];
//        
//
    //后台播放音频设置
//    AVAudioSession *session = [AVAudioSession sharedInstance];
//    [session setActive:YES error:nil];
//    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
//    
    
    NSTimeInterval timeLeft = [UIApplication sharedApplication].backgroundTimeRemaining;
    NSLog(@"Background time remaining2222: %.0f seconds (%d mins)", timeLeft, (int)(timeLeft / 60) );
    
    //让app支持接受远程控制事件
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    
    //播放背景音乐
    NSString *musicPath = [[NSBundle mainBundle] pathForResource:@"background" ofType:@"wav"];
    NSURL *url = [[NSURL alloc] initFileURLWithPath:musicPath];
    
    // 创建播放器
    static AVAudioPlayer *player = nil;
    if (player == nil)
    {
            player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    }
    [player prepareToPlay];
    [player setVolume:1];
    player.numberOfLoops = 1; //设置音乐播放次数  -1为一直循环
    [player play]; //播放
    
    
    [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
        
  //  }
    
}






@end
