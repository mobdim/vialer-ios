//
//  DialerViewController.m
//  Vialer
//
//  Created by Reinier Wieringa on 15/11/13.
//  Copyright (c) 2014 VoIPGRID. All rights reserved.
//

#import "DialerViewController.h"
#import "AppDelegate.h"
#import "ConnectionStatusHandler.h"

#import "AFNetworkReachabilityManager.h"

#import <AudioToolbox/AudioServices.h>
#import <CoreTelephony/CTCallCenter.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCall.h>

@interface DialerViewController ()
@property (nonatomic, strong) NSArray *titles;
@property (nonatomic, strong) NSArray *subTitles;
@property (nonatomic, strong) NSArray *sounds;
@property (nonatomic, strong) CTCallCenter *callCenter;
@end

@implementation DialerViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = NSLocalizedString(@"Call", nil);
        self.tabBarItem.image = [UIImage imageNamed:@"call"];

        self.titles = @[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"", @"0", @""];
        self.subTitles = @[@"", @"ABC", @"DEF", @"GHI", @"JKL", @"MNO", @"PQRS", @"TUV", @"WXYZ", @"*", @"+", @"#"];
        
        NSMutableArray *sounds = [NSMutableArray array];
        for (NSString *sound in self.titles) {
            if (!sound.length) {
                [sounds addObject:@(0)];
                continue;
            }

            NSString *path = [[NSBundle mainBundle] pathForResource:sound ofType:@"wav"];
            NSURL *fileURL = [NSURL fileURLWithPath:path isDirectory:NO];
            if (fileURL) {
                SystemSoundID soundID;
                OSStatus error = AudioServicesCreateSystemSoundID((__bridge CFURLRef)fileURL, &soundID);
                if (error == kAudioServicesNoError) {
                    [sounds addObject:@(soundID)];
                } else {
                    [sounds addObject:@(0)];
                    NSLog(@"Error (%d) loading sound at path: %@", (int)error, path);
                }
            }
        }
        self.sounds = sounds;
        
        __weak typeof(self) weakSelf = self;
        self.callCenter = [[CTCallCenter alloc] init];
        [self.callCenter setCallEventHandler:^(CTCall *call) {
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.backButton.hidden = YES;
                weakSelf.numberTextView.text = @"";
            });
            NSLog(@"callEventHandler2: %@", call.callState);
        }];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionStatusChangedNotification:) name:ConnectionStatusChangedNotification object:nil];

    self.view.frame = CGRectMake(self.view.frame.origin.x, self.view.frame.origin.y, [[UIScreen mainScreen] bounds].size.width, [[UIScreen mainScreen] bounds].size.width);

    [self addDialerButtonsToView:self.buttonsView];
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(backButtonLongPress:)];
    [self.backButton addGestureRecognizer:longPress];
    
    self.backButton.hidden = YES;

    [self.callButton setTitle:([ConnectionStatusHandler sharedConnectionStatusHandler].connectionStatus == ConnectionStatusHigh ? [NSString stringWithFormat:@"%@ SIP", NSLocalizedString(@"Call", nil)] : NSLocalizedString(@"Call", nil)) forState:UIControlStateNormal];
//    [self.callButton setTitle:NSLocalizedString(@"Call", nil) forState:UIControlStateNormal];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGRect frame = [UIScreen mainScreen].bounds;
    frame.size.height -= 49.f;
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 7.0f) {
        frame.origin.y -= 20.0f;
    }
    self.view.frame = frame;
    
    if ([UIScreen mainScreen].bounds.size.height < 568.f) {
        self.callButton.frame = CGRectMake(0, frame.size.height - 46.f, self.view.frame.size.width, 46.f);
    }
}

- (void)addDialerButtonsToView:(UIView *)view {
    CGFloat buttonXSpace = [UIScreen mainScreen].bounds.size.width / 3.4f;
    CGFloat buttonYSpace = [UIScreen mainScreen].bounds.size.height > 480.f ? [UIScreen mainScreen].bounds.size.height / 6.45f : 78.f;
    CGFloat leftOffset = (view.frame.size.width - (3.f * buttonXSpace)) / 2.f;
    
    CGPoint offset = CGPointMake(0, [UIScreen mainScreen].bounds.size.height > 480.f ? 16.f : 0.f);
    for (int j = 0; j < 4; j++) {
        offset.x = leftOffset;
        for (int i = 0; i < 3; i++) {
            NSString *title = self.titles[j * 3 + i];
            NSString *subTitle = self.subTitles[j * 3 + i];
            UIButton *button = [self createDialerButtonWithTitle:title andSubTitle:subTitle];
            [button addTarget:self action:@selector(dialerButtonPressed:) forControlEvents:UIControlEventTouchDown];
            button.tag = j * 3 + i;

            button.frame = CGRectMake(offset.x, offset.y, buttonXSpace, buttonXSpace);
            [view addSubview:button];
            
            if ([title isEqualToString:@"0"]) {
                UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
                [button addGestureRecognizer:longPress];
            }

            offset.x += buttonXSpace;
        }
        offset.y += buttonYSpace;
    }
}

- (UIButton *)createDialerButtonWithTitle:(NSString *)title andSubTitle:(NSString *)subTitle {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setImage:[self stateImageForState:UIControlStateNormal andTitle:title andSubTitle:subTitle] forState:UIControlStateNormal];
    [button setImage:[self stateImageForState:UIControlStateHighlighted andTitle:title andSubTitle:subTitle] forState:UIControlStateHighlighted];
    button.frame = CGRectMake(0, 0, button.imageView.image.size.width, button.imageView.image.size.height);
    return button;
}

- (UIImage *)stateImageForState:(UIControlState)state andTitle:(NSString *)title andSubTitle:(NSString *)subTitle {
    UIImage *image = [UIImage imageNamed:state == UIControlStateHighlighted ? @"dialer-button-highlighted" : @"dialer-button"];
    
    UIImageView *buttonGraphic = [[UIImageView alloc] initWithImage:image];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont systemFontOfSize:39.f];
    titleLabel.textColor = state == UIControlStateHighlighted ? [UIColor blackColor] : [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.text = title;
    [titleLabel sizeToFit];
    
    UILabel *subTitleLabel = [[UILabel alloc] init];
    subTitleLabel.backgroundColor = [UIColor clearColor];
    subTitleLabel.font = title.length ? [UIFont fontWithName:@"Avenir" size:10.f] : [UIFont fontWithName:@"Avenir" size:39.f];
    subTitleLabel.textColor = state == UIControlStateHighlighted ? [UIColor blackColor] : [UIColor colorWithRed:0xed green:0xed blue:0xed alpha:1.f];
    subTitleLabel.textAlignment = NSTextAlignmentCenter;
    subTitleLabel.text = subTitle;
    [subTitleLabel sizeToFit];
    
    if (title.length) {
        titleLabel.frame = CGRectMake(0.f, 10.f, image.size.width, titleLabel.frame.size.height);
        subTitleLabel.frame = CGRectMake(0.f, titleLabel.frame.origin.y + titleLabel.frame.size.height - 6.f, image.size.width, subTitleLabel.frame.size.height);
    } else {
        subTitleLabel.frame = CGRectMake(0.f, 14.f, image.size.width, subTitleLabel.frame.size.height);
    }
    
    [buttonGraphic addSubview:titleLabel];
    [buttonGraphic addSubview:subTitleLabel];
    
    CGRect rect = [buttonGraphic bounds];
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, [UIScreen mainScreen].scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [buttonGraphic.layer renderInContext:context];
    UIImage *capturedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return capturedImage;
}

- (void)connectionStatusChangedNotification:(NSNotification *)notification {
    [self.callButton setTitle:([ConnectionStatusHandler sharedConnectionStatusHandler].connectionStatus == ConnectionStatusHigh ? [NSString stringWithFormat:@"%@ SIP", NSLocalizedString(@"Call", nil)] : NSLocalizedString(@"Call", nil)) forState:UIControlStateNormal];
}

#pragma mark - TextView delegate

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    NSString *newString = [textView.text stringByReplacingCharactersInRange:range withString:text];
    NSMutableCharacterSet *characterSet = [NSMutableCharacterSet characterSetWithCharactersInString:@"0123456789+#*() "];
    if (newString.length != [[newString componentsSeparatedByCharactersInSet:[characterSet invertedSet]] componentsJoinedByString:@""].length) {
        return NO;
    }

    self.backButton.hidden = NO;

    return YES;
}

#pragma mark - Actions

- (void)longPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        if (self.numberTextView.text.length) {
            self.numberTextView.text = [self.numberTextView.text substringToIndex:self.numberTextView.text.length - 1];
        }
        self.numberTextView.text = [self.numberTextView.text stringByAppendingString:@"+"];
    }
}

- (void)backButtonLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.numberTextView.text = @"";
        self.backButton.hidden = YES;
    }
}

- (IBAction)dialerBackButtonPressed:(UIButton *)sender {
    if (self.numberTextView.text.length) {
        self.numberTextView.text = [self.numberTextView.text substringToIndex:self.numberTextView.text.length - 1];
    }
    self.backButton.hidden = (self.numberTextView.text.length == 0);
}

- (IBAction)callButtonPressed:(UIButton *)sender {
    NSString *phoneNumber = self.numberTextView.text;
    if (!phoneNumber.length) {
        return;
    }

    AppDelegate *appDelegate = ((AppDelegate *)[UIApplication sharedApplication].delegate);
    [appDelegate handlePhoneNumber:phoneNumber];
}

- (void)dialerButtonPressed:(UIButton *)sender {
    SystemSoundID soundID = (SystemSoundID)[[self.sounds objectAtIndex:sender.tag] integerValue];
    if (soundID > 0) {
        AudioServicesPlaySystemSound(soundID);
    }
    
    if (!self.numberTextView.text) {
        self.numberTextView.text = @"";
    }

    NSString *cipher = [self.titles objectAtIndex:sender.tag];
    if (cipher.length) {
        self.numberTextView.text = [self.numberTextView.text stringByAppendingString:cipher];
    } else {
        NSString *character = [self.subTitles objectAtIndex:sender.tag];
        if (character.length) {
            self.numberTextView.text = [self.numberTextView.text stringByAppendingString:character];
        }
    }
    
    self.backButton.hidden = NO;
}

@end
