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
#import "FCFileManager.h"  //for listing and deleting, not for saving file and creating dir
#import <PebbleKit/PebbleKit.h>
#import "CorePlot-CocoaTouch.h"
#import <CoreLocation/CoreLocation.h>

@interface ViewController () <PBDataLoggingServiceDelegate>

@property (nonatomic, strong) CMStepCounter *stepCounter;
@property (nonatomic, strong) CMMotionActivityManager *activityManager;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, weak) IBOutlet UILabel *stepsLabel;
@property (nonatomic, weak) IBOutlet UILabel *statusLabel;
@property (nonatomic, weak) IBOutlet UILabel *pebbleBat;
@property (nonatomic, weak) IBOutlet UILabel *GPSSpeed;
@property (nonatomic, weak) IBOutlet UILabel *sampleRate;
@property (nonatomic, weak) IBOutlet UIButton *startPebble;
@property (nonatomic, weak) IBOutlet UILabel *confidenceLabel;
@property (nonatomic, weak) IBOutlet UITextView *records;
@property (nonatomic,retain) IBOutlet UITableView *tableView;




@end

@implementation ViewController
{
    CPTXYGraph * _graph;
    NSMutableArray * _dataForPlot;
    
    NSArray *filelist;
    NSString *seletedFileName;
    PBWatch *connectedWatch;
    int32_t totalData;
    int32_t sampleCount;
    NSMutableArray *latest_data;
    NSString *fileName_acc_data;
    NSString *current_Activity;
    NSString *current_Environment;
    long long lastTimeInterval;
    BOOL isAccRecording;
    id appMessageHandle;
    long steps;
    CLLocationManager *locationManager;
    CLLocation *checkinLocation;
}

@synthesize tableView=_tableView;



- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    //------------------------------------init
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
    
    current_Activity = @"Sit\n";
    current_Environment = @"indoor\n";
    
    //--------------------------------Create directory for saving data
    [self createDir];
    
    NSString *filename = [self getCurrentTime];
    
    
    NSTimer *_timer;
    _timer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(tik) userInfo:nil repeats:YES];
    
    [self tik];
    //---------------------------------Pebble init
    connectedWatch = [[PBPebbleCentral defaultCentral] lastConnectedWatch];

    
    [connectedWatch appMessagesLaunch:^(PBWatch *watch, NSError *error) {
        if (!error) {
            NSLog(@"Successfully launched app.");
        }
        else {
            NSLog(@"Error launching app - Error: %@", error);
        }
    }];
     
    isAccRecording = false;
    
    //--------------------------------Graph

    graphViewX = [[GraphView alloc]initWithFrame:CGRectMake(0, 0, viewX.frame.size.width, viewX.frame.size.height)];
    [graphViewX setBackgroundColor:[UIColor clearColor]];
    [graphViewX setSpacing:500];
    [graphViewX setFill:NO];
    [graphViewX setStrokeColor:[UIColor redColor]];
    [graphViewX setZeroLineStrokeColor:[UIColor greenColor]];
    //[graphViewX setFillColor:[UIColor orangeColor]];
    [graphViewX setNumberOfPointsInGraph:(int)50];
    [graphViewX setLineWidth:2];
    [graphViewX setCurvedLines:YES];
    //[self.view addSubview:graphViewX];
    [viewX setBackgroundColor:[UIColor clearColor]];
    [viewX setAlpha:0.8];
    [viewX addSubview:graphViewX];

    graphViewY = [[GraphView alloc]initWithFrame:CGRectMake(0, 0, viewY.frame.size.width, viewY.frame.size.height)];
    [graphViewY setBackgroundColor:[UIColor clearColor]];
    [graphViewY setSpacing:500];
    [graphViewY setFill:NO];
    [graphViewY setStrokeColor:[UIColor blueColor]];
    [graphViewY setZeroLineStrokeColor:[UIColor greenColor]];
    //[graphViewY setFillColor:[UIColor orangeColor]];
    [graphViewY setNumberOfPointsInGraph:(int)50];
    [graphViewY setLineWidth:2];
    [graphViewY setCurvedLines:YES];
    //[self.view addSubview:graphViewY];
    [viewY setBackgroundColor:[UIColor clearColor]];
    [viewY setAlpha:0.8];
    [viewY addSubview:graphViewY];
    
    graphViewZ = [[GraphView alloc]initWithFrame:CGRectMake(0, 0, viewZ.frame.size.width, viewZ.frame.size.height)];
    [graphViewZ setBackgroundColor:[UIColor clearColor]];
    [graphViewZ setSpacing:500];
    [graphViewZ setFill:NO];
    [graphViewZ setStrokeColor:[UIColor yellowColor]];
    [graphViewZ setZeroLineStrokeColor:[UIColor greenColor]];
    //[graphViewZ setFillColor:[UIColor orangeColor]];
    [graphViewZ setNumberOfPointsInGraph:(int)50];
    [graphViewZ setLineWidth:2];
    [graphViewZ setCurvedLines:YES];
    //[self.view addSubview:graphViewZ];
    [viewZ setAlpha:0.8];
    [viewZ setBackgroundColor:[UIColor clearColor]];
    [viewZ addSubview:graphViewZ];
    
    


        
    //--------------------------------M7
    
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
                     steps = (long)numberOfSteps;
                     
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
                 
                 
                 NSLog(@"%@",content);
                 [self writeFile:content :filename];
                 weakSelf.records.text = [weakSelf.records.text stringByAppendingString:content];
                 NSRange range = NSMakeRange(weakSelf.records.text.length - 1, 1); //auto scroll
                 [weakSelf.records scrollRangeToVisible:range];
                 
             });
         }];
    }
    
    
    filelist = [self listFile];

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

//----------------------------------------Start Button
- (IBAction) connect: (id)sender
{
    
    if (!isAccRecording){
        
        int NUM_SAMPLES = 15;
        
        [activitySelector setEnabled:false];
        [envirSelector setEnabled:false];
        
        //-------------------------------GPS
        
        locationManager = [[CLLocationManager alloc] init];
        if ([CLLocationManager locationServicesEnabled]) {
            NSLog( @"Starting CLLocationManager" );
            locationManager.delegate = self;
            locationManager.distanceFilter = 50;
            locationManager.desiredAccuracy = kCLLocationAccuracyBest;
            [locationManager startUpdatingLocation]; //Start GPS
        }
        else
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Opps!!!"
                                                            message:@"Please enable the location service."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            
            [alert show];
            return;
        }
        
        //--------------------------------Pebble
        [self.startPebble setAttributedTitle:nil forState:UIControlStateNormal];
        [self.startPebble setTitle:@"Stop" forState:UIControlStateNormal];

        isAccRecording = true;
        
        fileName_acc_data = [[self getCurrentTime] stringByAppendingString:@"_acc"]; // get the file name for saving acc data
        
        [self writeFile:current_Environment :fileName_acc_data];
        [self writeFile:current_Activity :fileName_acc_data];
        
        
        NSDictionary *update = @{ @(0):[NSNumber numberWithUint8:0],
                                  @(1):[NSNumber numberWithUint8:0]};   //send commands to Pebble to start the app
        
        [connectedWatch appMessagesPushUpdate:update onSent:^(PBWatch *watch, NSDictionary *update, NSError *error) {
            if (!error) {
                NSLog(@"Successfully sent message.");
            }
            else {
                NSLog(@"Error sending message: %@", error);
            }
        }];
        
        
        appMessageHandle = [connectedWatch appMessagesAddReceiveUpdateHandler:^BOOL(PBWatch *watch, NSDictionary *update) {


            totalData += 3 * NUM_SAMPLES * 4; //Count total data
            latest_data = [NSMutableArray arrayWithCapacity:totalData];
            
            
            //Get data
            [latest_data removeAllObjects]; // empty the array
            
            
            
            for (int i = 0; i< NUM_SAMPLES ; i++){
                for (int j =0; j<3 ; j++) {
                    @try {
                        long key = (3*i)+j;
                        int value = [[update objectForKey:@(key)] int32Value];
                        NSNumber *valueWrapped = [NSNumber numberWithInt:value];
                        [latest_data addObject:valueWrapped];
                        
                    }
                    @catch (NSException *exception){
                        NSLog(@"error");
                    }
                }
                int x = [[latest_data objectAtIndex:(i*3)] intValue];
                int y = [[latest_data objectAtIndex:(i*3+1)] intValue];
                int z = [[latest_data objectAtIndex:(i*3+2)] intValue];
                
            
                [graphViewX setPoint:(float)x];
                [graphViewY setPoint:(float)y];
                [graphViewZ setPoint:(float)z];
                
                NSString *temp = [NSString stringWithFormat:@"x:%d, y:%d, z:%d, steps:%ld, latitude:%f, longitude:%f, speed:%f, horizontal accuracy:%f, %@\n",x,y,z,steps,checkinLocation.coordinate.latitude, checkinLocation.coordinate.longitude, checkinLocation.speed,checkinLocation.horizontalAccuracy, [self getCurrentTime]];
                
                NSLog(temp);
                [self writeFile:temp :fileName_acc_data];
                
                NSString *text = [NSString stringWithFormat:@"Speed: %.2f", checkinLocation.speed];
                self.GPSSpeed.text = text;


            }
            int battery = [[update objectForKey:@(3*NUM_SAMPLES)] int32Value];
            NSString *text = [NSString stringWithFormat:@"Pebble's battery: %d", (int) battery];
            self.pebbleBat.text = text;
            //--------------------------------calculate sample rate
            long long sec = [[NSDate date] timeIntervalSince1970] * 1000;
            if (lastTimeInterval){
                int timediff = (int) sec - lastTimeInterval;
                NSLog(@"timedelay: %d",(int)timediff);
                
                NSString *text = [NSString stringWithFormat:@"Sample Rate:%.1f Sps", (float)NUM_SAMPLES*1000.0/(float)timediff];
                self.sampleRate.text = text;
            }
            
            lastTimeInterval = [[NSDate date] timeIntervalSince1970] * 1000;
            
            
            return YES;
        }];
    }
    else
    {
        [activitySelector setEnabled:true];
        [envirSelector setEnabled:true];
        [self.startPebble setAttributedTitle:nil forState:UIControlStateNormal];
        [self.startPebble setTitle:@"Start Pebble" forState:UIControlStateNormal];
        isAccRecording = false;
        [connectedWatch appMessagesRemoveUpdateHandler:appMessageHandle];
    }
}

//----------------------------------------Segmented Control

- (IBAction)ActivitySelect:(id)sender {
    switch(activitySelector.selectedSegmentIndex) {
        case 0: //sit
            current_Activity = @"Sit\n";
            break;
        case 1: //Walk
            current_Activity = @"Walk\n";
            break;
        case 2: //Run
            current_Activity = @"Run\n";
            break;
        case 3: //Bicycle
            current_Activity = @"Bicycle\n";
            break;
    }
}

- (IBAction)EnvironmentSlect:(id)sender {
    switch(envirSelector.selectedSegmentIndex) {
        case 0: //indoor
            current_Environment = @"indoor\n";
            break;
        case 1: //Walk
            current_Environment = @"outdoor\n";
            break;

    }
}

//-------------------------------------------Location
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation {
    checkinLocation = newLocation;
    //do something else
}


@end
