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


#import "GameShelfController.h"
#import "GamePack.h"
#import "GameDetailsController.h"
#import "SimpleGameListController.h"
#import "NewsletterSignUpViewController.h"
#import "ImageBarControl.h"

@interface GameShelfController()

- (void)valueChanged:(ImageBarControl*)sender;

@end

@implementation GameShelfController

#define kInnerViewFrame			CGRectMake(0, 33, 320, 398)

@synthesize gameBrowserController = _gameBrowserController;
@synthesize newsletterSignUpViewController = _newsletterSignUpViewController;

- (void)viewDidLoad {
    [super viewDidLoad];
	
	_gameBrowserController.detailsDelegate = self;
	
	NSArray *items = [NSArray arrayWithObjects:
					  @"btn_mygames.png", @"btn_mygames_active.png", 
					  @"btn_getupdated.png", @"btn_getupdated_active.png", nil];
	_imageBar = [[ImageBarControl alloc] initWithItems:items];
	[self.view addSubview:_imageBar];
	_imageBar.center = CGPointMake(160, 15);
	[_imageBar addTarget:self action:@selector(valueChanged:) forControlEvents:UIControlEventValueChanged];
	[_imageBar release];
	
	_gameBrowserController.view.frame = kInnerViewFrame;
	[self.view insertSubview:_gameBrowserController.view atIndex:0];
}

- (void)showDetails:(NSInteger)index {
    GameInfo *info = [[GamePack globalGamePack].gameInfoList objectAtIndex:index];
    GameDetailsController *view = [[GameDetailsController alloc] initWithGameId:info.gameId isShopView:NO];    
    [self.navigationController pushViewController:view animated:YES];
    [view release];
}

- (void)valueChanged:(ImageBarControl*)sender {
	BOOL gameBrowserHidden = (sender.selectedSegmentIndex == 1);
	if (gameBrowserHidden && !_newsletterSignUpViewController) {
		_newsletterSignUpViewController = [[NewsletterSignUpViewController alloc] initWithNibName:@"NewsletterSignUpView" 
																						   bundle:nil];
		_newsletterSignUpViewController.view.frame = kInnerViewFrame;
		[self.view insertSubview:_newsletterSignUpViewController.view atIndex:0];
	} else {
		[_newsletterSignUpViewController viewWillDisappear:NO];
	}

	self.gameBrowserController.view.hidden = gameBrowserHidden;
	self.newsletterSignUpViewController.view.hidden = !gameBrowserHidden;
}

- (void)dealloc {
	self.gameBrowserController = nil;
	self.newsletterSignUpViewController = nil;
    [super dealloc];
}

@end
