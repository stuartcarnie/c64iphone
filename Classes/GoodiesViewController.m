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

#import "GoodiesViewController.h"
#import "debug.h"
#import "UIApplication-Network.h"

@interface GoodiesViewController(PrivateImplementation)

- (void)navigateTo:(NSString*)path;
- (void)goBack:(id)sender;

@end

@implementation GoodiesViewController

@synthesize webView, toolBar, activityIndicator;

NSString* hostName	= @"c64.manomio.com";
NSString* baseUrl	= @"http://c64.manomio.com/index.php/iphone/othergames/";

- (void)viewWillAppear:(BOOL)animated {
	CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
	UIWebView *newWebView = [[UIWebView alloc] initWithFrame:frame];
	[self.view addSubview:newWebView];
	self.webView = newWebView;
	self.webView.delegate = self;
	[newWebView release];
	
	if (![UIApplication hasNetworkConnectionToHost:hostName]) {
		NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"goodiesViewNoConnection.html"]]];
		[webView loadRequest:req];
	} else {
		[self navigateTo:@"inappshop"];
	}
}

- (void)viewDidDisappear:(BOOL)animated {
	// release the object to conserve memory
	[webView removeFromSuperview];
	self.webView.delegate = nil;
	self.webView = nil;	
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; 
}

- (void)navigateTo:(NSString*)path {
	NSString *url = [baseUrl stringByAppendingString:path];
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[self.webView loadRequest:request];
}
	 
- (void)goToLink:(UIBarButtonItem*)sender{
	DLog(@"go to link");
	switch(sender.tag) {
		case 1:
			[self navigateTo:@"C10"];
			break;
		case 2:
			[self navigateTo:@"C11"];
			break;
		case 3:
			[self navigateTo:@"C12"];
			break;
	}
}

- (void)webViewDidStartLoad:(UIWebView *)sender {
	UIActivityIndicatorView *view = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	view.center = webView.center;
	[view startAnimating];
	self.activityIndicator = view;
	[view release];
	[webView addSubview:self.activityIndicator];
}

- (void)webViewDidFinishLoad:(UIWebView *)sender {
	[self.activityIndicator stopAnimating];
	[self.activityIndicator removeFromSuperview];
	self.activityIndicator = nil;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSString *host = [[request URL] host];
	if (host) {
		NSRange range = [host rangeOfString:@"phobos"];
		if (range.location != NSNotFound) {
			[[UIApplication sharedApplication] openURL:[request URL]];
			return NO;
		}
	}
	
	NSString *scheme = [request.URL scheme];
	if ([scheme isEqualToString:@"manomio"]) {		
		[self.navigationController popViewControllerAnimated:YES];
		return NO;
	}
	
	return YES;
}

- (void)dealloc {
	self.toolBar			= nil;
	self.activityIndicator	= nil;
	self.webView			= nil;
    [super dealloc];
}


@end
