/*
 Frodo, Commodore 64 emulator for the iPhone
 Copyright (C) 2007-2010 Stuart Carnie
 See gpl.txt for license information.
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "GameBrowserController.h"
#import "GamePack.h"
#import "debug.h"
#import "Prefs.h"
#import "Frodo.h"
#import "C64.h"
#import "i64ApplicationDelegate.h"

@interface GameBrowserController(Private)

- (void)gamePackChanged;

@end

@implementation GameBrowserController

@synthesize gamePack, detailsDelegate;

- (void)loadView {
	[super loadView];
	
	UITableView *table = self.tableView;
	table.separatorStyle = UITableViewCellSeparatorStyleNone;
	table.backgroundColor = [UIColor blackColor];
	
	topCellImage	= [UIImage imageNamed:@"bookshelf_top.png"];
	cellImage		= [UIImage imageNamed:@"bookshelf_rest.png"];
	
	self.gamePack = [GamePack globalGamePack];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(gamePackChanged)
												 name:kGamePackListUpdatedNotification 
											   object:nil];
}

- (void)gamePackChanged {
	[self.tableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}

/*
- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
}
*/

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return gamePack.gameInfoList.count;
}

- (GameBrowserListViewCell*)getNewCell {
	[[NSBundle mainBundle] loadNibNamed:@"GameBrowserListViewCell" owner:self options:nil];
	return newCell;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"GameBrowserListViewCell";
    
    GameBrowserListViewCell *cell = (GameBrowserListViewCell*)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [self getNewCell];
    }
    
	int row = indexPath.row;
	if (row == 0) {
		cell.backgroundView = [[UIImageView alloc] initWithImage:topCellImage];
	} else {
		cell.backgroundView = [[UIImageView alloc] initWithImage:cellImage];
	}
	
	GameInfo *info = [gamePack.gameInfoList objectAtIndex:row];
	//[cell setGameTitle:info.gameTitle row:row coverArtPath:info.coverArtPath];
	[cell setGameInfo:info row:row];
		
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	int row = indexPath.row;
	if (row == 0)
		return (CGFloat)topCellImage.size.height;
	
	return (CGFloat)cellImage.size.height;
}

#pragma mark Actions

- (IBAction)runGame:(UIButton*)sender {
	GameInfo *info = [gamePack.gameInfoList objectAtIndex:sender.tag];
	
	[info launchGame];
}

- (IBAction)showDetails:(UIButton*)sender {
	[self.detailsDelegate showDetails:sender.tag];
}

- (void)dealloc {
	[topCellImage release];
	[cellImage release];
	self.detailsDelegate = nil;
    [super dealloc];
}


@end

