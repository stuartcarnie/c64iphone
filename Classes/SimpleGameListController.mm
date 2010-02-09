/*
 Frodo, Commodore 64 emulator for the iPhone
 Copyright (C)	
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


#import "SimpleGameListController.h"
#import "EMUFileGroup.h"
#import "GamePack.h"
#import "SimpleGameListCell.h"

@interface SimpleGameListController()
- (GameInfo*)gameInfoFromIndexPath:(NSIndexPath *)indexPath;
- (void)gamePackChanged;
- (void)loadData;
- (void)releaseData;
@end

@implementation SimpleGameListController

- (void)viewDidLoad {
    [super viewDidLoad];
	
	[self loadData];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(gamePackChanged)
												 name:kGamePackListUpdatedNotification 
											   object:nil];
}

- (void)loadData {
	indexTitles = [[NSMutableArray alloc] initWithObjects:@"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H", @"I", 
				   @"J", @"K", @"L", @"M", @"N", @"O", @"P", @"Q", @"R", @"S", @"T", @"U", @"V",
				   @"W", @"X", @"Y", @"Z", @"#", nil];
	
	NSMutableArray *sections = [[NSMutableArray alloc] init];
	for (int i = 0; i < 27; i++) {
		EMUFileGroup *g = [[EMUFileGroup alloc] initWithSectionName:[indexTitles objectAtIndex:i]];
		[sections addObject:g];
	}
	
	for (GameInfo *info in [GamePack globalGamePack].gameInfoList) {
		unichar c = [[info gameTitle] characterAtIndex:0];
		if (isdigit(c)) {
			EMUFileGroup *g = (EMUFileGroup*)[sections objectAtIndex:26];
			[g.files addObject:info];
		} else {
			c = toupper(c) - 65;
			EMUFileGroup *g = (EMUFileGroup*)[sections objectAtIndex:c];
			[g.files addObject:info];
		}
	}
	
	int i = 0;
	while (i < sections.count) {
		if ([[[sections objectAtIndex:i] files] count] == 0) {
			[sections removeObjectAtIndex:i];
			[indexTitles removeObjectAtIndex:i];
		} else {
			i++;
		}
	}
	
	roms = sections;
}

- (void)releaseData {
	[indexTitles release];
	[roms release];
}

- (void)gamePackChanged {
	[self releaseData];
	[self loadData];
	[self.tableView reloadData];
}

/*
- (void)viewWillAppear:(BOOL)animated {
	
    [super viewWillAppear:animated];
}
*/

/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
}
*/

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return roms.count;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return indexTitles;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	EMUFileGroup *g = (EMUFileGroup*)[roms objectAtIndex:section];
	return g.sectionName;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    unichar c = [title characterAtIndex:0];
	if (c > 64 && c < 91)
		return c - 65;
	
    return 26;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    EMUFileGroup *g = (EMUFileGroup*)[roms objectAtIndex:section];
    return g.files.count;
}

- (SimpleGameListCell*)getNewCell {
	[[NSBundle mainBundle] loadNibNamed:@"SimpleGameListCell" owner:self options:nil];
	return newCell;
}

#define CELL_ID @"DiskCell"

- (GameInfo*)gameInfoFromIndexPath:(NSIndexPath *)indexPath {
	EMUFileGroup *g = (EMUFileGroup*)[roms objectAtIndex:indexPath.section];
	GameInfo *gi = (GameInfo *)[g.files objectAtIndex:indexPath.row];
	return gi;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	SimpleGameListCell *cell = (SimpleGameListCell*)[tableView dequeueReusableCellWithIdentifier:CELL_ID];
	if (cell == nil) {
		cell = [self getNewCell];
	}
		
	GameInfo *gi = [self gameInfoFromIndexPath:indexPath];
	[cell setLabelText:gi.gameTitle];
	cell.favourite = [[GamePack globalGamePack] isFavourite:gi];
	
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
	
	GameInfo *gi = [self gameInfoFromIndexPath:indexPath];
	[gi launchGame];
}

- (IBAction)favouriteSelected:(UIButton *)sender {
	SimpleGameListCell *cell = (SimpleGameListCell*)sender.superview.superview;
	NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
	GameInfo *gi = [self gameInfoFromIndexPath:indexPath];
	BOOL newValue = (cell.favourite = !cell.favourite);
	if (newValue)
		[[GamePack globalGamePack] addFavourite:gi];
	else
		[[GamePack globalGamePack] removeFavourite:gi];
}

- (void)dealloc {
	[self releaseData];
    [super dealloc];
}


@end

