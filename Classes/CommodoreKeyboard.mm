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

#import "CommodoreKeyboard.h"
#import "KeyboardView.h"
#import "debug.h"

@interface CommodoreKeyboard(Private)

- (void)loadKeyboardViews;

@end


@implementation CommodoreKeyboard

@synthesize delegate, currentView;

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
	
	keyboardViews	= [[NSMutableDictionary alloc] init];
	
	[self loadKeyboardViews];
	self.currentView.frame = kKeyboardViewFrame;
	[self addSubview:self.currentView];
	
    return self;
}

- (void)loadKeyboardViews {
	NSString *errorDesc = nil;
	NSPropertyListFormat format;
	NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"commodore-keyboard" ofType:@"plist"];
	NSData *plistXML	= [[NSFileManager defaultManager] contentsAtPath:plistPath];
	NSArray *layouts	= (NSArray *)[NSPropertyListSerialization propertyListFromData:plistXML
																 mutabilityOption:NSPropertyListMutableContainersAndLeaves
																		   format:&format
																 errorDescription:&errorDesc];
	
	if (!layouts) {
		DLog(errorDesc);
		[errorDesc release];
		return;
	}

	BOOL first = YES;
	for(NSDictionary *layout in layouts) {
		KeyboardView *kview = [KeyboardView createFromLayout:layout andBasePath:[[NSBundle mainBundle] bundlePath]];
		kview.delegate = self;
		[keyboardViews setObject:kview forKey:[layout valueForKey:@"layout-name"]];
		if (first) {
			first		= NO;
			self.currentView = kview;
		}
		[kview release];
	}
}

- (void)setKeyboardLayout:(NSString*)layout {
	[self.currentView removeFromSuperview];
	
	self.currentView = [keyboardViews objectForKey:layout];
	self.currentView.frame = kKeyboardViewFrame;
	[self addSubview:self.currentView];
}

- (void)dealloc {
	self.currentView = nil;
	[keyboardViews release];
	self.delegate = nil;
    [super dealloc];
}

#pragma mark UIEnhancedKeyboardDelegate

- (void)keyDown:(int)keyCode {
	[delegate keyDown:keyCode];
}

- (void)keyUp:(int)keyCode {
	[delegate keyUp:keyCode];
}


@end
