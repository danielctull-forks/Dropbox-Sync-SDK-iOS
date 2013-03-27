/* Copyright (c) 2012 Dropbox, Inc. All rights reserved. */

#import <UIKit/UIKit.h>

@class DBFilesystem;


@interface AppDelegate : UIResponder <UIApplicationDelegate>

+ (AppDelegate *)sharedDelegate;

@property (strong, nonatomic) UIWindow *window;

@end
