//
//  ViewController.h
//  step
//
//  Created by crazypoo on 1/15/14.
//  Copyright (c) 2014 crazypoo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <PebbleKit/PebbleKit.h>
#import "GraphView.h"



@class GraphView;

@interface ViewController : UIViewController<UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate>{

    GraphView *graphViewX;
    GraphView *graphViewY;
    GraphView *graphViewZ;
    
    IBOutlet UIView *viewX;
    IBOutlet UIView *viewY;
    IBOutlet UIView *viewZ;
    IBOutlet UISegmentedControl *activitySelector;
    IBOutlet UISegmentedControl *envirSelector;

    
}


@property (strong, nonatomic) GraphView *graphViewX;
@property (strong, nonatomic) GraphView *graphViewY;
@property (strong, nonatomic) GraphView *graphViewZ;



@end


