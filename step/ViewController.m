//
//  ViewController.m
//  step
//
//  Originally Created by crazypoo on 1/15/14.
//  Copyright (c) 2014 crazypoo. All rights reserved.
//  Modified by Chen Zhao

#import "ViewController.h"
#import <CoreMotion/CoreMotion.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "FCFileManager.h"


@interface ViewController ()
@property (nonatomic, strong) CMStepCounter *stepCounter;
@property (nonatomic, strong) CMMotionActivityManager *activityManager;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, weak) IBOutlet UILabel *stepsLabel;
@property (nonatomic, weak) IBOutlet UILabel *statusLabel;
@property (nonatomic, weak) IBOutlet UILabel *confidenceLabel;
@property (nonatomic, weak) IBOutlet UITextView *records;
@property (nonatomic,retain) IBOutlet UITableView *tableView;



@end

@implementation ViewController
{
    NSArray *filelist;
    NSString *seletedFileName;
}

@synthesize tableView=_tableView;


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
                     
                     NSString *text = [NSString stringWithFormat:@"Steps: %ld", (long)numberOfSteps];
                     
                     weakSelf.stepsLabel.text = text;
                 }
             });
         }];
    }
    
//Start
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
                 
                 
                 
                 NSString *content = [NSString stringWithFormat:@"%@,%@,%@,%@\n", weakSelf.stepsLabel.text, status, confidence, [self getCurrentTime]];
                 
                 
                 
                 [self writeFile:content :filename];
                 
                 NSLog(@"%@",content);
                 
                 weakSelf.records.text = [weakSelf.records.text stringByAppendingString:content];
                 NSRange range = NSMakeRange(weakSelf.records.text.length - 1, 1); //auto scroll
                 [weakSelf.records scrollRangeToVisible:range];
                 
             });
         }];
    }
    
    
    filelist = [self listFile];

//    recipes = [NSArray arrayWithObjects:@"Egg Benedict", @"Mushroom Risotto", @"Full Breakfast", @"Hamburger", @"Ham and Egg Sandwich", @"Creme Brelee", @"White Chocolate Donut", @"Starbucks Coffee", @"Vegetable Curry", @"Instant Noodle with Egg", @"Noodle with BBQ Pork", @"Japanese Noodle with Pork", @"Green Tea", @"Thai Shrimp Cake", @"Angry Birds Cake", @"Ham and Cheese Panini", nil];
//    //self.items = list;
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
        NSLog(@"Succeed");
    }else
        NSLog(@"Failed");
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
        NSLog(@"Succeed: %@" ,testPath);
    }else
        NSLog(@"Failed");
}

- (NSString*)getCurrentTime{
    NSDate* date = [NSDate date];
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    
    NSString* str = [formatter stringFromDate:date];
    return str;
}


- (void)tik{
    

    
    NSTimeInterval timeLeft = [UIApplication sharedApplication].backgroundTimeRemaining;
    NSLog(@"Background time remaining2222: %.0f seconds (%d mins)", timeLeft, (int)(timeLeft / 60) );
    
    //Remote control
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    
    //Play background music
    NSString *musicPath = [[NSBundle mainBundle] pathForResource:@"background" ofType:@"wav"];
    NSURL *url = [[NSURL alloc] initFileURLWithPath:musicPath];
    
    // Create player
    static AVAudioPlayer *player = nil;
    if (player == nil)
    {
            player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    }
    [player prepareToPlay];
    [player setVolume:0];
    player.numberOfLoops = 1; //Set loops.   -1 is infinite loop
    [player play]; //play
    
    
    [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
        
  //  }
    
}

-(NSArray *)listFile{
    NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDir = [documentPaths objectAtIndex:0];
    documentDir = [documentDir stringByAppendingString:@"/test"];
    
    NSArray *array = [FCFileManager listItemsInDirectoryAtPathRelative:documentDir deep:NO];
    
    return array;
}





#pragma mark - TableView Methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [filelist count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *simpleTableIdentifier = @"SimpleTableCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
    }
    
    cell.textLabel.text = [filelist objectAtIndex:indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    
    UIAlertView *messageAlert = [[UIAlertView alloc]
                                 initWithTitle:@"Row Selected" message:[filelist objectAtIndex:indexPath.row] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:@"Delete", nil];
    seletedFileName = [filelist objectAtIndex:indexPath.row];
    // Display Alert Message
    [messageAlert setTag:0];
    [messageAlert show];
    
}

#pragma mark - Alert view delegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:
    (NSInteger)buttonIndex{
    switch (alertView.tag) {
        case 0: // Delete single item
            switch (buttonIndex) {
                case 0:
                    NSLog(@"Cancel button clicked");
                    break;
                case 1:{
                    NSLog(@"Delete button clicked");
                    NSString *filePath = [@"test/" stringByAppendingString:seletedFileName];
                    NSString *fullFilePath = [FCFileManager pathForDocumentsDirectoryWithPath:filePath];
                    BOOL result = [FCFileManager removeItemAtPath:fullFilePath];
                    //[self deleteFile:fullFilePath];
                    filelist = [self listFile];
                    [self.tableView reloadData];
                    
                    
                    break;
                    }
                    
                default:
                    break;
            }
            break;
        
        case 1: // Delete All files
            switch (buttonIndex) {
                case 0:
                    NSLog(@"Cancel button clicked");
                    break;
                case 1:{
                    UITextField *answer = [alertView textFieldAtIndex:0];
                    
                    if ([answer.text isEqualToString:@"yes"]){
                        
                        NSString *fullFilePath = [[FCFileManager pathForDocumentsDirectory] stringByAppendingString:@"/test"] ;
                        NSFileManager *fileManager = [NSFileManager defaultManager];
                        [fileManager removeItemAtPath:fullFilePath error:nil];
                        filelist = [self listFile];
                        
                        [self.tableView reloadData];
                        [self createDir];
                        
                    }
                    else {
                        break;
                    }
                    
                    break;
                }
                    
                default:
                    break;
            }
            break;
        
        default:
            break;
            
    }
}

- (IBAction) deleteAllFiles: (id)sender
{
    UIAlertView *messageAlert = [[UIAlertView alloc]
                                 initWithTitle:@"Warning!!" message:@"Delete all files?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Delete", nil];
    // Display Alert Message
    [messageAlert setAlertViewStyle:UIAlertViewStylePlainTextInput];
    [messageAlert setTag:1];
    [messageAlert show];
}



@end
