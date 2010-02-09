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

#import <UIKit/UIKit.h>
#import "UIEnhancedKeyboardDelegate.h"

const CGFloat kDefaultPaddingBetweenKeys		= 0.0;
#define kKeyboardViewFrame						CGRectMake(0, 20, 320, 150)

@class KeyView;

@interface KeyboardView : UIView {
	KeyView							*current;
	UIImageView						*pushed;
	id<UIEnhancedKeyboardDelegate>	delegate;
	BOOL							keyLocked;
	NSTimer							*keyDownDelay;
}

+ (KeyboardView*)createFromLayout:(NSDictionary*)layout andBasePath:(NSString*)basePath;

@property (nonatomic, retain)		id<UIEnhancedKeyboardDelegate>	delegate;

@end

@interface KeyView : UIImageView {
	UIImage					*up;
	UIImage					*down;
	int						keyCode;
	BOOL					pushed;
	CGRect					oldRect;
}

@property (nonatomic, readonly) float	normalWidth;
@property (nonatomic, readonly) float	normalHeight;
@property (nonatomic)			int		keyCode;
@property (nonatomic, readonly)	UIImage *up;
@property (nonatomic, readonly)	UIImage *down;
@property (nonatomic)			BOOL	pushed;

- (id)initWithCode:(int)code withUpName:(NSString*)upName withDownName:(NSString*)downName andTopLeft:(CGPoint)topLeft andBasePath:(NSString*)basePath;

@end

