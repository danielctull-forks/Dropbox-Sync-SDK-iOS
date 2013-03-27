/* Copyright (c) 2012 Dropbox, Inc. All rights reserved. */

#import "NoteController.h"


@interface NoteController () <UITextViewDelegate>

@property (nonatomic, retain) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, retain) DBFile *file;
@property (nonatomic, retain) UITextView *textView;
@property (nonatomic, assign) BOOL textViewLoaded;
@property (nonatomic, retain) NSTimer *writeTimer;

@end


@implementation NoteController

- (id)initWithFile:(DBFile *)file {
	if (!(self = [super init])) return nil;
	
	_file = [file retain];
	self.navigationItem.title = [_file.info.path name];
	self.navigationItem.rightBarButtonItem =
		[[[UIBarButtonItem alloc]
		  initWithBarButtonSystemItem:UIBarButtonSystemItemFastForward
		  target:self action:@selector(didPressUpdate)]
		 autorelease];
	
	return self;
}

- (void)unloadViews {
	self.activityIndicator = nil;
	self.textView = nil;
}

- (void)dealloc {
	[self unloadViews];
	[_file release];
	[_writeTimer invalidate];
	[_writeTimer release];
	[super dealloc];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.textView = [[[UITextView alloc] initWithFrame:self.view.bounds] autorelease];
	self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.textView.delegate = self;
	[self.view addSubview:self.textView];
	
	self.activityIndicator = [[[UIActivityIndicatorView alloc]
							   initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray]
							  autorelease];
	CGRect frame = self.activityIndicator.frame;
	frame.origin.x = floorf(self.view.bounds.size.width/2 - frame.size.width/2);
	frame.origin.y = floorf(self.view.bounds.size.height/2 - frame.size.height/2);
	self.activityIndicator.frame = frame;
	[self.view addSubview:self.activityIndicator];
}

- (void)viewDidUnload {
	[super viewDidUnload];
	[self unloadViews];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

	[_file addObserver:self block:^() { [self reload]; }];
	[self.navigationController setToolbarHidden:YES];
	[self reload];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	
	[_file removeObserver:self];
	[self saveChanges];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


#pragma mark - UITextViewDelegate methods

- (void)textViewDidChange:(UITextView *)textView {
	[_writeTimer invalidate];
	self.writeTimer = [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(saveChanges)
							userInfo:nil repeats:NO];
}


#pragma mark - private methods

- (void)reload {
	BOOL updateEnabled = NO;
	if (_file.status.cached) {
		if (!_textViewLoaded) {
			_textViewLoaded = YES;
			NSString *contents = [_file readString:nil];
			self.textView.text = contents;
		}
		
		[self.activityIndicator stopAnimating];
		self.textView.hidden = NO;
		
		if (_file.newerStatus.cached) {
			updateEnabled = YES;
		}
	} else {
		[self.activityIndicator startAnimating];
		self.textView.hidden = YES;
	}
	
	self.navigationItem.rightBarButtonItem.enabled = updateEnabled;
}

- (void)saveChanges {
	if (!_writeTimer) return;
	[_writeTimer invalidate];
	self.writeTimer = nil;
	
	[_file writeString:self.textView.text error:nil];
}

- (void)didPressUpdate {
	[_file update:nil];
	_textViewLoaded = NO;
	[self reload];
}

@end
