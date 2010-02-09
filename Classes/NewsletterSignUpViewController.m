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


#import "NewsletterSignUpViewController.h"
#import "debug.h"
#import "CocoaUtility.h"

@interface NewsletterSignUpViewController()

- (void)registerForKeyboardNotifications;
- (void)keyboardWasShown:(NSNotification*)aNotification;
- (void)keyboardWasHidden:(NSNotification*)aNotification;
- (void)getXID;
- (void)sendForm:(NSString*)xid;
- (void)sendDone;
- (void)unableToComplete;

@end

@implementation NewsletterSignUpViewController

@synthesize email=_email, scrollView=_scrollView, contentView=_contentView, activity=_activity;;

- (void)viewDidLoad {
    [super viewDidLoad];
	
	_scrollView.contentSize = _contentView.bounds.size;
	
	[self registerForKeyboardNotifications];
}

// Call this method somewhere in your view controller setup code.
- (void)registerForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardWasShown:)
												 name:UIKeyboardDidShowNotification object:nil];
	
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardWasHidden:)
												 name:UIKeyboardDidHideNotification object:nil];
}

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification {
    if (_keyboardShown)
        return;
	
    NSDictionary* info = [aNotification userInfo];
	
    // Get the size of the keyboard.
    NSValue* aValue = [info objectForKey:UIKeyboardBoundsUserInfoKey];
    CGSize keyboardSize = [aValue CGRectValue].size;
	
    // Resize the scroll view (which is the root view of the window)
    CGRect viewFrame = [_scrollView frame];
    viewFrame.size.height -= keyboardSize.height;
    _scrollView.frame = viewFrame;
	
    // Scroll the active text field into view.
    CGRect textFieldRect = [_activeField frame];
    [_scrollView scrollRectToVisible:textFieldRect animated:YES];
	
    _keyboardShown = YES;
}


// Called when the UIKeyboardDidHideNotification is sent
- (void)keyboardWasHidden:(NSNotification*)aNotification {
    NSDictionary* info = [aNotification userInfo];
	
    // Get the size of the keyboard.
    NSValue* aValue = [info objectForKey:UIKeyboardBoundsUserInfoKey];
    CGSize keyboardSize = [aValue CGRectValue].size;
	
    // Reset the height of the scroll view to its original value
    CGRect viewFrame = [_scrollView frame];
    viewFrame.size.height += keyboardSize.height;
    _scrollView.frame = viewFrame;
	
    _keyboardShown = NO;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    _activeField = textField;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    _activeField = nil;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[_email resignFirstResponder];
	[self getXID];
	return YES;
}

- (void)getXID {
	[_activity startAnimating];
	NSStringEncoding enc;
	NSError *err = nil;
	NSString *str = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"http://c64.manomio.com/index.php/iphone/register/"] 
										 usedEncoding:&enc 
												error:&err];

	NSInteger errorCode = [err code];
	if (errorCode != 0) {
		[self unableToComplete];
		return;
	}
	
	NSRange range = [str rangeOfString:@"name=\"XID\" value=\"" options:NSCaseInsensitiveSearch];
	range = NSMakeRange(range.location + range.length, 40);
	str = [str substringWithRange:range];
	[self sendForm:str];
}

- (void)sendForm:(NSString*)xid {
	NSMutableURLRequest *post = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://c64.manomio.com/index.php"]];
	[post setHTTPMethod:@"POST"];
	[post setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	NSString *formData = [NSString stringWithFormat:@"XID=%@&ACT=3&RET=%@&list=c64news&site_id=4&email=%@", 
						  xid, [@"http://c64.manomio.com/index.php/iphone/register/" encodeForURL], 
						  [[_email text] encodeForURL]];
	[post setHTTPBody:[formData dataUsingEncoding:[NSString defaultCStringEncoding]]];
	_connection = [[NSURLConnection alloc] initWithRequest:post delegate:self startImmediately:YES];
}

- (void)sendDone {
	[_connection release];
	_connection = nil;
	[_activity stopAnimating];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
	// no caching
	return nil;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	NSLog(@"Failed to subscribe to newsletter");
	[self sendDone];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response {
	NSInteger statusCode = [response statusCode];
	if (statusCode != 200) {
		[self unableToComplete];
		return;
	}
	
	[[[[UIAlertView alloc] initWithTitle:@"Success!" 
								message:@"You'll receive a confirmation email to complete your subscription." 
							   delegate:nil 
					  cancelButtonTitle:@"OK" 
					  otherButtonTitles:nil] autorelease] show];
}
		
- (void)unableToComplete {
	[[[[UIAlertView alloc] initWithTitle:@"We're Sorry" 
								 message:@"Sorry, but we're unable to submit your request at this time.  Please try again later." 
								delegate:nil 
					   cancelButtonTitle:@"OK" 
					   otherButtonTitles:nil] autorelease] show];	
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[self sendDone];
}

- (void)viewWillDisappear:(BOOL)animated {
	[_email resignFirstResponder];
}

- (void)dealloc {
	self.email = nil;
    [super dealloc];
}


@end
