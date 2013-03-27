/* Copyright (c) 2012 Dropbox, Inc. All rights reserved. */

#import <Dropbox/Dropbox.h>
#import <UIKit/UIKit.h>

@interface SettingsController : UITableViewController

- (id)initWithAccountManager:(DBAccountManager *)manager;

@end
