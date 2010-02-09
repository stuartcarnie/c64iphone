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

#import "KeyboardView.h"
#import "debug.h"

#import "KeyboardRowAutoLayoutView.h"
#import "KeyboardRowColumnLayout.h"
#import "KeyboardRowAbsoluteLayout.h"

#import "Commodore64KeyCodes.h"
#import <map>
#import <string>

using std::map;
using std::string;

@interface KeyboardView(Private)

- (void)showPushedKey:(KeyView*)key;
- (void)lockPushedKey;
- (void)stopKeyDownTimer;
- (void)restartKeyDownTimer;
- (void)endKeyPress;

// static load methods
+ (void)loadKeysFromArray:(NSArray*)array intoSection:(NSMutableArray*)section ofKeyboard:(KeyboardView*)keyboard andBasePath:(NSString*)basePath;
+ (NSArray*)loadKeysForColums:(NSArray*)columns ofKeyboard:(KeyboardView*)keyboard andBasePath:(NSString*)basePath;

@end

@implementation KeyboardView

#include "keys_declaration.h"

const int		kKeyboardRowHeight	= 32;
const int		kKeyHoverHeight		= 45;		// the # of pixels above the finger, where the 'pressed' key will show

//! delay before keydown message is sent to emulator
const double	kKeyDelayInterval = (200.0 / 1000.0);


+ (KeyboardView*)createFromLayout:(NSDictionary*)layout andBasePath:(NSString*)basePath {
	NSArray* rows = [layout objectForKey:@"rows"];
	if (!rows) {
		DLog([NSString stringWithFormat:@"Unable to find rows key in layout %@", [layout objectForKey:@"layout-name"]]);
		return nil;
	}
	
	KeyboardView *view = [[KeyboardView alloc] initWithFrame:CGRectZero];
	int frameY = 0;

	for(NSDictionary *row in rows) {
		if ([[row valueForKey:@"layout-mode"] isEqualToString:@"auto"]) {
			KeyboardRow *kr = [[KeyboardRow alloc] init];
			[KeyboardView loadKeysFromArray:[row valueForKey:@"left"] intoSection:kr.left ofKeyboard:view andBasePath:basePath];
			[KeyboardView loadKeysFromArray:[row valueForKey:@"centre"] intoSection:kr.centre ofKeyboard:view andBasePath:basePath];
			[KeyboardView loadKeysFromArray:[row valueForKey:@"right"] intoSection:kr.right ofKeyboard:view andBasePath:basePath];
			
			KeyboardRowAutoLayoutView *rowView = [[KeyboardRowAutoLayoutView alloc] initWithFrame:CGRectMake(0, frameY, 320, kKeyboardRowHeight) 
																						   andRow:kr];
			[view addSubview:rowView];
			[rowView release];
			[kr release];
		} else if ([[row valueForKey:@"layout-mode"] isEqualToString:@"column"]) {
			NSArray *widths = [row valueForKey:@"column-widths"];
			NSArray *columns = [row valueForKey:@"columns"];
			
			NSArray *keyColumns = [KeyboardView loadKeysForColums:columns ofKeyboard:view andBasePath:basePath];
			KeyboardRowColumnLayout *rowView = [[KeyboardRowColumnLayout alloc] initWithFrame:CGRectMake(0, frameY, 320, kKeyboardRowHeight)
																				   andColumns:keyColumns andWidths:widths];
			[view addSubview:rowView];
			[rowView release];
		} else if ([[row valueForKey:@"layout-mode"] isEqualToString:@"absolute"]) {
			NSArray *keyboardKeys = [row valueForKey:@"keys"];
			
			NSMutableArray *array = [[NSMutableArray alloc] init];
			[KeyboardView loadKeysFromArray:keyboardKeys intoSection:array ofKeyboard:view andBasePath:basePath];
			KeyboardRowAbsoluteLayout *rowView = [[KeyboardRowAbsoluteLayout alloc] initWithFrame:CGRectMake(0, 0, 320, 150) andKeys:array];
			[view addSubview:rowView];
			[rowView release];
		}
	
		NSNumber *rowHeight = [row valueForKey:@"height"];
		if (rowHeight)
			frameY += [rowHeight intValue];
		else
			frameY += kKeyboardRowHeight;
	}
	
	return view;
}


+ (void)loadKeysFromArray:(NSArray*)keys intoSection:(NSMutableArray*)section ofKeyboard:(KeyboardView*)keyboard andBasePath:(NSString*)basePath {
	static NSCharacterSet *commaSet = [[NSCharacterSet characterSetWithCharactersInString:@","] retain];

	for(NSDictionary *keyDict in keys) {
		NSString* code = [keyDict valueForKey:@"code"];
		tagKey *key = findKey([code UTF8String]);
		if (key) {
			NSString *smallName = [keyDict valueForKey:@"upImage"];
			NSString *largeName = nil;
			if (!smallName) {
				smallName = [[NSString stringWithFormat:@"key_%s_small", key->imageName] lowercaseString];
				largeName = [[NSString stringWithFormat:@"key_%s_large", key->imageName] lowercaseString];
			}

			CGPoint topLeftPoint = CGPointZero;
			
			NSString *topLeft = [keyDict valueForKey:@"topLeft"];
			if (topLeft) {
				NSArray *elements = [topLeft componentsSeparatedByCharactersInSet:commaSet];
				if ([elements count] == 2) {
					topLeftPoint = CGPointMake([[elements objectAtIndex:0] floatValue], [[elements objectAtIndex:1] floatValue]);
				}
			}
			
			KeyView *view = [[KeyView alloc] initWithCode:key->code withUpName:smallName withDownName:largeName andTopLeft:topLeftPoint andBasePath:basePath];
			[section addObject:view];
			[view release];
		} else {
			DLog([NSString stringWithFormat:@"Warning: could not find key for %@", code]);
		}

	}
}

+ (NSArray*)loadKeysForColums:(NSArray*)columns ofKeyboard:(KeyboardView*)keyboard andBasePath:(NSString*)basePath {
	NSMutableArray *cols = [[NSMutableArray alloc] initWithCapacity:columns.count];
	
	for(NSArray* key_ar in columns) {
		NSMutableArray *keys = [[NSMutableArray alloc] initWithCapacity:key_ar.count];
		if (key_ar.count > 0) {
			[KeyboardView loadKeysFromArray:key_ar intoSection:keys ofKeyboard:keyboard andBasePath:basePath];
		}
		[cols addObject:keys];
		[keys release];			
	}
	
	return [cols autorelease];
}

#pragma mark KeyboardView Instance methods

@synthesize delegate;

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
		pushed = [[UIImageView alloc] init];
		pushed.hidden = YES;
	}
    return self;
}

- (void)dealloc {
	self.delegate = nil;
    [super dealloc];
}

- (void)stopKeyDownTimer {
	if (keyDownDelay) {
		[keyDownDelay invalidate];
		keyDownDelay = nil;
	}
}

- (void)restartKeyDownTimer {
	if (keyDownDelay)
		[self stopKeyDownTimer];
	
	keyDownDelay = [NSTimer scheduledTimerWithTimeInterval:kKeyDelayInterval target:self selector:@selector(lockPushedKey) userInfo:nil repeats:NO];
}

- (void)endKeyPress {
	[self stopKeyDownTimer];

	pushed.hidden	= YES;
	current.pushed	= NO;
	current			= nil;
	keyLocked		= NO;	
}

- (void)lockPushedKey {
	if (current) {
		DLog([NSString stringWithFormat:@"lockPushedKey: key down '%d'", current.keyCode]);
		[delegate keyDown:current.keyCode];
		keyLocked = YES;
	}
	
	keyDownDelay = nil;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	UITouch *touch = [touches anyObject];
	CGPoint loc = [touch locationInView:self];
	UIView *view = [self hitTest:loc withEvent:event];
	if ([view isKindOfClass:[KeyView class]]) {
		current = (KeyView*)view;
		[self showPushedKey:current];
		[self restartKeyDownTimer];
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	if (keyLocked)
		return;
	
	UITouch *touch = [touches anyObject];
	CGPoint loc = [touch locationInView:self];
	UIView *view = [self hitTest:loc withEvent:event];

	if ([view isKindOfClass:[KeyView class]]) {
		current = (KeyView*)view;
		[self showPushedKey:current];
		[self restartKeyDownTimer];
	} else {
		current.pushed = NO;
		current = nil;
		pushed.hidden = YES;
	}

}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	if (current != nil) {
		DLog([NSString stringWithFormat:@"touchesEnded: key up '%d'", current.keyCode]);
		// send key to emulator
		[delegate keyUp:current.keyCode];
		[self endKeyPress];
	}
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
	if (current != nil) {
		if (keyLocked)
			[delegate keyUp:current.keyCode];
		[self endKeyPress];
	}
}

- (void)showPushedKey:(KeyView*)key {
	if (!key.down) {
		// emulate button getting smaller
		key.pushed = YES;
	} else {
		float xofs = (key.down.size.width - key.up.size.width) / 2;
		CGRect newRect = CGRectOffset(key.frame, -xofs, -kKeyHoverHeight);
		if (newRect.origin.x < 0)
			newRect.origin.x = 0;
		
		newRect.size = key.down.size;
		float overflow = (newRect.origin.x + newRect.size.width) - 320;
		if (overflow > 0)
			newRect.origin.x -= overflow;
		pushed.frame	= newRect; 
		pushed.image	= key.down;
		pushed.hidden	= NO;
		[key.superview addSubview:pushed];
		[pushed.superview bringSubviewToFront:pushed];	
	}	
}

@end

#pragma mark KeyView instance methods

@implementation KeyView

@synthesize keyCode, up, down, pushed;

- (id)initWithCode:(int)code withUpName:(NSString*)upName withDownName:(NSString*)downName andTopLeft:(CGPoint)topLeft andBasePath:(NSString*)basePath {
	self		= [super init];

	keyCode		= code;
	// this was about 50% on the iPhone, than directly loading via [UIImage imageWithContentsOfFile:...]
	NSData *data = [[NSData alloc] initWithContentsOfFile:[[basePath stringByAppendingPathComponent:upName] stringByAppendingString:@".png"]];
	up			= [UIImage imageWithData:data];
	[data release];
	if (!up) {
		up		= [[UIImage imageNamed:@"key_blank_small.png"] retain];
		DLog([NSString stringWithFormat:@"Missing small key image '%@'", upName]);
	}
	
	if (downName) {
		data		= [[NSData alloc] initWithContentsOfFile:[[basePath stringByAppendingPathComponent:downName] stringByAppendingString:@".png"]];
		down		= [[UIImage imageWithData:data] retain];
		[data release];
		if (!down) {
			down	= [[UIImage imageNamed:@"key_blank_large.png"] retain];
			DLog([NSString stringWithFormat:@"Missing large key image '%@'", downName]);
		}
	}
	
	self.userInteractionEnabled = YES;
	self.image = up;
	
	self.frame	= CGRectMake(topLeft.x, topLeft.y, up.size.width, up.size.height);
	return self;
}

- (void)setPushed:(BOOL)value {
	if (value == pushed)
		return;
	
	pushed = value;
	
	if (value) {
		oldRect = self.frame;
		self.frame = CGRectInset(oldRect, oldRect.size.width - oldRect.size.width * 0.9, oldRect.size.height - oldRect.size.height * 0.9);
	} else {
		self.frame = oldRect;
	}
}

- (float)normalWidth {
	return up.size.width;
}

- (float)normalHeight {
	return up.size.height;
}

- (void)dealloc {
	[up release];
	[down release];
	[super dealloc];
}

@end

