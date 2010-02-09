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


#import <UIKit/UIKit.h>

@interface NewsletterSignUpViewController : UIViewController {
	UITextField				*_email;
	UIScrollView			*_scrollView;
	UIView					*_contentView;
	
	BOOL					_keyboardShown;
	
	UITextField				*_activeField;
	NSURLConnection			*_connection;
	UIActivityIndicatorView	*_activity;
}

@property(nonatomic, retain) IBOutlet UITextField				*email;
@property(nonatomic, retain) IBOutlet UIScrollView				*scrollView;
@property(nonatomic, retain) IBOutlet UIView					*contentView;
@property(nonatomic, retain) IBOutlet UIActivityIndicatorView	*activity;


@end
