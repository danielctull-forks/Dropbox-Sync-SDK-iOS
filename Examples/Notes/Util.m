/* Copyright (c) 2012 Dropbox, Inc. All rights reserved. */

#import "Util.h"

void Alert(NSString *title, NSString *msg) {
	[[[[UIAlertView alloc]
	   initWithTitle:title message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil]
	  autorelease]
	 show];
}
