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


#import "MMC64SimpleShelfController.h"
#import "MMStoreManager.h"
#import "MMProduct.h"
#import "MMC64SimpleShelfCell.h"
#import "MMC64SimpleDetailsController.h"
#import "EGOCache.h"
#import "ImageBarControl.h"
#import "GoodiesViewController.h"
#import "Reachability.h"

@interface MMC64SimpleShelfController()

@property (nonatomic, retain) NSArray*	products;

- (void)reloadDataFromServer;
- (void)imageBarValueChanged:(ImageBarControl*)bar;

@end

@implementation MMC64SimpleShelfController


- (void)viewDidLoad {
    [super viewDidLoad];

	_cellBackground = [UIImage imageNamed:@"shelf2.png"];
	
	// load image bar
	NSArray *items = [NSArray arrayWithObjects:
					  @"tab_paid_off.png", @"tab_paid_on.png", 
					  @"tab_free_off.png", @"tab_free_on.png", nil];
	_imageBar = [[ImageBarControl alloc] initWithItems:items];
	[self.topBar addSubview:_imageBar];
	_imageBar.center = CGPointMake(160, 16);
	[_imageBar addTarget:self action:@selector(imageBarValueChanged:) forControlEvents:UIControlEventValueChanged];
	
	self.tableView.tableHeaderView = self.topBar;
    [self.view addSubview:_activityIndicator];
	_activityIndicator.center = CGPointMake(160, 240);
	
	self.products = [NSArray array];
	
#if !defined(_DISTRIBUTION)
	UIControl* refreshButton = (UIControl*)[self.view viewWithTag:1000];
	refreshButton.hidden = NO;
#endif
	
}

- (void)dealloc {
	self.activityIndicator = nil;
	self.topBar = nil;
	self.products = nil;
	self.noInternetWarning = nil;
	[_allProducts release];
	[_productDetails release];
	[_imageBar release];
    [super dealloc];
}

- (void)viewWillAppear:(BOOL)animated {
	[self reloadDataFromServer];
}

NSMutableArray* selectMatching(NSArray* src, BOOL(^pred)(id item)) {
	NSMutableArray *rows = [NSMutableArray array];
	int i = 0;
	NSMutableArray *row = nil;
	
	for (id item in src) {
		if (!pred(item)) continue;
		
		if (i==0) {
			row = [NSMutableArray array];
			[rows addObject:row];
			i = 3;
		}
		i--;
		
		[row addObject:item];
	}
	
	return rows;
}

- (void)reloadDataFromServer {
	if (_dataLoaded) return;
	
	if ([[Reachability sharedReachability] internetConnectionStatus] == NotReachable) {
		[self.navigationController.view addSubview:self.noInternetWarning];
	} else {
		[self.noInternetWarning removeFromSuperview];
	}

	
	[_activityIndicator startAnimating];
	
	[[MMStoreManager defaultStore] getAvailableProducts:^(NSArray* prods, BOOL succeeded) {
		NSMutableArray *paidItems, *freeItems;
		
		if (succeeded) {
			paidItems = selectMatching(prods, ^(id item) {
				MMProduct* p = (MMProduct *)item;
				if (p.isFree) return NO;
				return YES;
			});
			freeItems = selectMatching(prods, ^(id item) {
				MMProduct* p = (MMProduct *)item;
				if (p.isFree) return YES;
				return NO;
			});
			
			_dataLoaded = YES;
		} else {
			// failed to load from server
			freeItems = [NSMutableArray array]; 
			paidItems = [NSMutableArray array];
		}
		
		int remaining = 3 - [freeItems count];
		while (remaining-- > 0) {
			[freeItems addObject:[NSArray array]];
		}
		
		remaining = 3 - [paidItems count];
		while (remaining-- > 0) {
			[paidItems addObject:[NSArray array]];
		}
		
		_allProducts = [[NSMutableArray arrayWithObjects:paidItems, freeItems, nil] retain];
		self.products = [_allProducts objectAtIndex:_imageBar.selectedSegmentIndex];
		[self.tableView reloadData];
		[_activityIndicator stopAnimating];
	}];
}

- (IBAction)clearAndReload:(id)sender {
	[[EGOCache currentCache] clearCache];
	_dataLoaded = NO;
	[self reloadDataFromServer];
}

- (IBAction)more:(id)sender {
	GoodiesViewController* v = [[GoodiesViewController alloc] init];
	[self.navigationController pushViewController:v animated:YES];
	[v release];
}

- (void)imageBarValueChanged:(ImageBarControl*)bar {
	self.products = [_allProducts objectAtIndex:bar.selectedSegmentIndex];
	[self.tableView reloadData];

}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_products count];
}

- (MMC64SimpleShelfCell*)getNewCell {
	[[NSBundle mainBundle] loadNibNamed:@"MMC64SimpleShellCell" owner:self options:nil];
	return newCell;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"SimpleShelfCell";
    
    MMC64SimpleShelfCell *cell = (MMC64SimpleShelfCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [self getNewCell];
		cell.delegate = self;
    }
    
	NSUInteger row = indexPath.row;
	[cell setProductArray:[_products objectAtIndex:row]];
	
    return cell;
}

- (MMC64SimpleDetailsController*)getDetailsController {
	if (!_productDetails) {	
		_productDetails = [[MMC64SimpleDetailsController alloc] initWithNibName:@"MMC64SimpleDetails" bundle:nil];
	}
	return _productDetails;
}

- (void)presentProductDetails:(MMProduct*)product {
	MMC64SimpleDetailsController *v = [self getDetailsController];
	[v setProduct:product];
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.5];
	[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:self.navigationController.view cache:YES];
	[self.navigationController pushViewController:v animated:NO];
	[UIView commitAnimations];
}

@synthesize activityIndicator=_activityIndicator;
@synthesize topBar=_topBar;
@synthesize products=_products;
@synthesize noInternetWarning=_noInternetWarning;
@end

