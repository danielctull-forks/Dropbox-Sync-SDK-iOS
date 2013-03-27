/* Copyright (c) 2012 Dropbox, Inc. All rights reserved. */

#import "SettingsController.h"
#import "Util.h"
#import "FolderListController.h"

typedef enum {
	LinkRow,
	UnlinkRow,
	AccountRow
} RowType;

@interface SettingsController ()

@property (nonatomic, retain) UITableViewCell *accountCell;
@property (nonatomic, retain) UITableViewCell *linkCell;
@property (nonatomic, retain) DBAccountManager *manager;

@end


@implementation SettingsController

- (id)initWithAccountManager:(DBAccountManager *)manager {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped])) return nil;
	
	self.manager = manager;

	self.title = @"Settings";

	[_manager addObserver:self block: ^(DBAccount *account) {
		[self accountUpdated:account];
	}];

	return self;
}

- (void)dealloc {
	[_manager removeObserver:self];
	[_manager release];
	[super dealloc];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.accountCell =
		[[[UITableViewCell alloc]
		  initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil]
		 autorelease];
	_accountCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

	self.linkCell =
		[[[UITableViewCell alloc]
		  initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil]
		 autorelease];
	_linkCell.textLabel.textAlignment = UITextAlignmentCenter;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];

	[self reload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return _manager.linkedAccount ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	switch ([self rowTypeForIndexPath:indexPath]) {
		case AccountRow: {
			NSString *text = @"Dropbox";
			DBAccountInfo *info = _manager.linkedAccount.info;
			if (info) {
				text = [text stringByAppendingFormat:@" (%@)", info.displayName];
			}

			_accountCell.textLabel.text = text;
			return _accountCell;
		}
		case LinkRow:
			_linkCell.textLabel.text = @"Link";
			return _linkCell;
		case UnlinkRow:
			_linkCell.textLabel.text = @"Unlink";
			return _linkCell;
	}
}


#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	switch ([self rowTypeForIndexPath:indexPath]) {
		case AccountRow: {
			DBAccount *account = _manager.linkedAccount;
			DBFilesystem *filesystem = [[[DBFilesystem alloc] initWithAccount:account] autorelease];
			FolderListController *controller =
				[[[FolderListController alloc]
				  initWithFilesystem:filesystem root:[DBPath root]]
				 autorelease];
			[self.navigationController pushViewController:controller animated:YES];
			break;
		}
		case LinkRow:
			[self didPressAdd];
			break;
		case UnlinkRow:
			[_manager.linkedAccount unlink];
			break;
	}
}

- (void)didPressAdd {
	[_manager linkFromController:self.navigationController];
}


#pragma mark - private methods

- (void)reload {
	[self.tableView reloadData];
}

- (void)accountUpdated:(DBAccount *)account {
	if (!account.linked && [self.currentAccount isEqual:account]) {
		[self.navigationController popToViewController:self animated:YES];
		Alert(@"Your account was unlinked!", nil);
/*	} else if (!account.linked && [_accounts containsObject:account]) {
		NSInteger index = [_accounts indexOfObject:account];
		[_accounts removeObjectAtIndex:index];
		NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
		[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
 */
	} else {
		[self reload];
	}
}

- (DBAccount *)currentAccount {
	NSArray *viewControllers = self.navigationController.viewControllers;
	if ([viewControllers count] < 2) return nil;

	FolderListController *folderController =
		(FolderListController *)[viewControllers objectAtIndex:1];
	return folderController.account;
}

- (RowType)rowTypeForIndexPath:(NSIndexPath *)indexPath {
	if ([indexPath section] == 0) {
		if (_manager.linkedAccount) {
			return AccountRow;
		} else {
			return LinkRow;
		}
	} else {
		return UnlinkRow;
	}
}

@end
