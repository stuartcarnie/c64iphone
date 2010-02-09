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

#import "InfoViewController.h"

@implementation InfoViewController

@synthesize webView;

- (void)viewWillAppear:(BOOL)animated {
	CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
	UIWebView *newWebView = [[UIWebView alloc] initWithFrame:frame];
	[self.view addSubview:newWebView];
	self.webView = newWebView;
	[newWebView release];
	NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"info.html"]]];
	[webView loadRequest:req];
}

- (void)viewDidDisappear:(BOOL)animated {
	[webView removeFromSuperview];
	self.webView = nil;	
}

- (void)dealloc {
	self.webView = nil;
    [super dealloc];
}


@end
