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

#import "GameDetailsController.h"
#import "debug.h"
#import "GamePack.h"
#import "UIApplication-Network.h"

@interface GameDetailsController(PrivateImplementation)

- (void)navigateTo:(NSString*)path;

@end

@implementation GameDetailsController

@synthesize gameId, webView;

static NSString*	gameInfoBaseUrl = @"http://c64.manomio.com/index.php/iphone/gameDetails/";

- (id)initWithGameId:(NSString*)theId isShopView:(BOOL)isShopView {
	self = [super initWithNibName:@"GameDetailsView" bundle:nil];
	self.gameId = theId;
	_isShopView = isShopView;
	return self;
}

- (void)navigateTo:(NSString*)path {
	NSString *url = _isShopView ? [gameInfoBaseUrl stringByAppendingFormat:@"%@/inshop", path] : [gameInfoBaseUrl stringByAppendingFormat:@"%@", path];
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[self.webView loadRequest:request];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewWillAppear:(BOOL)animated {
	if ([UIApplication hasNetworkConnectionToHost:@"c64.manomio.com"]) {
		[self navigateTo:gameId];
	} else {
		NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"details_noconnection.html"]]];
		[self.webView loadRequest:request];
	}

    [super viewDidLoad];
}


- (IBAction)goBack:(UIButton*)sender {
	[self.navigationController popViewControllerAnimated:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
}

- (void)dealloc {
	self.gameId = nil;
	self.webView = nil;
    [super dealloc];
}


@end
