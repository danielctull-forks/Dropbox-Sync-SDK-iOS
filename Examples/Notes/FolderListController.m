/* Copyright (c) 2012 Dropbox, Inc. All rights reserved. */

#import "FolderListController.h"
#import "NoteController.h"
#import "Util.h"


@interface FolderListController () <UIActionSheetDelegate>

@property (nonatomic, retain) DBFilesystem *filesystem;
@property (nonatomic, retain) DBPath *root;
@property (nonatomic, retain) NSMutableArray *contents;
@property (nonatomic, assign) BOOL creatingFolder;
@property (nonatomic, retain) DBPath *fromPath;
@property (nonatomic, retain) UITableViewCell *loadingCell;
@property (nonatomic, assign) BOOL loadingFiles;
@property (nonatomic, assign, getter=isMoving) BOOL moving;

@end


@implementation FolderListController

- (id)initWithFilesystem:(DBFilesystem *)filesystem root:(DBPath *)root {
	if ((self = [super init])) {
		self.filesystem = filesystem;
		self.root = root;
		self.navigationItem.title = [root isEqual:[DBPath root]] ? @"Dropbox" : [root name];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_contents release];
	[_filesystem removeObserver:self];
	[_filesystem release];
	[_fromPath release];
	[_loadingCell release];
	[_root release];
	[super dealloc];
}


#pragma mark - UIViewController methods

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];

	[_filesystem addObserver:self forPathAndChildren:self.root block:^() { [self loadFiles]; }];
	[self.navigationController setToolbarHidden:NO];
	[self loadFiles];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	
	[_filesystem removeObserver:self];
}


#pragma mark - UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (!_contents) return 1;

	return [_contents count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!_contents) {
		return self.loadingCell;
	}

	static NSString *CellIdentifier = @"Cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (!cell) {
		cell = [[[UITableViewCell alloc]
				 initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier]
				autorelease];
	}

	DBFileInfo *info = [_contents objectAtIndex:[indexPath row]];
	cell.textLabel.text = [info.path name];
	if (info.isFolder) {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	} else {
		cell.accessoryType = UITableViewCellAccessoryNone;
	}

	return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
		forRowAtIndexPath:(NSIndexPath *)indexPath {

	DBFileInfo *info = [_contents objectAtIndex:[indexPath row]];
	if ([_filesystem deletePath:info.path error:nil]) {
		[_contents removeObjectAtIndex:[indexPath row]];
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
	} else {
		Alert(@"Error", @"There was an error deleting that file.");
		[self reload];
	}
}


#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([_contents count] <= [indexPath row]) return;

	DBFileInfo *info = [_contents objectAtIndex:[indexPath row]];

	if (!_moving) {
		UIViewController *controller = nil;
		if (info.isFolder) {
			controller = [[[FolderListController alloc] initWithFilesystem:_filesystem root:info.path] autorelease];
		} else {
			DBFile *file = [_filesystem openFile:info.path error:nil];
			if (!file) {
				Alert(@"Error", @"There was an error opening your note");
				return;
			}
			controller = [[[NoteController alloc] initWithFile:file] autorelease];
		}
		
		[self.navigationController pushViewController:controller animated:YES];
	} else {
		self.fromPath = info.path;

		UIAlertView *alertView =
			[[[UIAlertView alloc]
			  initWithTitle:@"Choose a destination" message:nil delegate:self
			  cancelButtonTitle:@"Cancel" otherButtonTitles:@"Move", nil]
			 autorelease];
		alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
		[alertView show];
	}
}


#pragma mark - UIActionSheetDelegate methods

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex != actionSheet.cancelButtonIndex) {
		_creatingFolder = buttonIndex > 0;
		NSString *title = _creatingFolder ? @"Create a folder" : @"Create a file";
		UIAlertView *alertView =
			[[[UIAlertView alloc]
			  initWithTitle:title message:nil delegate:self
			  cancelButtonTitle:@"Cancel" otherButtonTitles:@"Create", nil]
			 autorelease];
		alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
		[alertView show];
	}
}


#pragma mark - UIAlertViewDelegate methods

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex != alertView.cancelButtonIndex) {
		NSString *input = [alertView textFieldAtIndex:0].text;

		if (_moving) {
			[self moveTo:input];
		} else {
			[self createAt:input];
		}
	}

	_moving = NO;
	self.fromPath = nil;
	[self loadFiles];
}


#pragma mark - private methods

NSInteger sortFileInfos(id obj1, id obj2, void *ctx) {
	return [[obj1 path] compare:[obj2 path]];
}

- (void)loadFiles {
	if (_loadingFiles) return;
	_loadingFiles = YES;

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^() {
		NSArray *immContents = [_filesystem listFolder:_root error:nil];
		NSMutableArray *mContents = [NSMutableArray arrayWithArray:immContents];
		[mContents sortUsingFunction:sortFileInfos context:NULL];
		dispatch_async(dispatch_get_main_queue(), ^() {
			self.contents = mContents;
			_loadingFiles = NO;
			[self reload];
		});
	});
}

- (void)reload {
	[self.tableView reloadData];

	UIBarButtonItem *moveItem =
		[[[UIBarButtonItem alloc]
		  initWithTitle:@"Move" style:UIBarButtonItemStyleBordered
		  target:self action:@selector(didPressMove)]
		 autorelease];
	moveItem.enabled = (_contents != nil);

	if (_moving) {
		moveItem.enabled = NO;
		UIBarButtonItem *messageItem =
			[[[UIBarButtonItem alloc]
			  initWithTitle:@"Select a file to move" style:UIBarButtonItemStylePlain
			  target:nil action:nil]
			 autorelease];
		self.toolbarItems = [NSArray arrayWithObjects:moveItem, messageItem, nil];
		
		self.navigationItem.rightBarButtonItem =
			[[[UIBarButtonItem alloc]
			  initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
			  target:self action:@selector(didPressCancel)]
			 autorelease];
	} else {
		self.toolbarItems = [NSArray arrayWithObject:moveItem];
		
		self.navigationItem.rightBarButtonItem =
			[[[UIBarButtonItem alloc]
			  initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
			  target:self action:@selector(didPressAdd)]
			 autorelease];
	}
}

- (void)didPressAdd {
	UIActionSheet *actionSheet =
		[[[UIActionSheet alloc]
		  initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil
		  otherButtonTitles:@"Create File", @"Create Folder", nil]
		 autorelease];
	[actionSheet showInView:self.navigationController.view];
}

- (void)didPressCancel {
	_moving = NO;
	[self reload];
}

- (void)didPressMove {
	_moving = YES;
	[self reload];
}

- (void)createAt:(NSString *)input {
	if (!_creatingFolder) {
		NSString *noteFilename = [NSString stringWithFormat:@"%@.txt", input];
		DBPath *path = [_root childPath:noteFilename];
		DBFile *file = [_filesystem createFile:path error:nil];
		
		if (!file) {
			Alert(@"Unable to create note", @"An error has occurred");
		} else {
			NoteController *controller = [[[NoteController alloc] initWithFile:file] autorelease];
			[self.navigationController pushViewController:controller animated:YES];
		}
	} else {
		DBPath *path = [_root childPath:input];
		BOOL success = [_filesystem createFolder:path error:nil];
		if (!success) {
			Alert(@"Unable to be create folder", @"An error has occurred");
		} else {
			FolderListController *controller = [[[FolderListController alloc] initWithFilesystem:_filesystem root:path] autorelease];
			[self.navigationController pushViewController:controller animated:YES];
		}
	}
}

- (void)moveTo:(NSString *)input {
	NSArray *components = [input componentsSeparatedByString:@"/"];

	DBPath *path = _root;
	if ([[components objectAtIndex:0] length] == 0) {
		path = [DBPath root];
	}

	for (NSString *component in components) {
		if ([component isEqual:@".."]) {
			path = [path parent];
		} else {
			path = [path childPath:component];
		}
	}

	[_filesystem movePath:_fromPath toPath:path error:nil];

	_moving = NO;
	self.fromPath = nil;
}

- (DBAccount *)account {
	return _filesystem.account;
}

- (UITableViewCell *)loadingCell {
	if (!_loadingCell) {
		_loadingCell =
			[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
		_loadingCell.textLabel.text = @"Loading...";
		_loadingCell.textLabel.textAlignment = UITextAlignmentCenter;
	}
	return _loadingCell;
}

@end
