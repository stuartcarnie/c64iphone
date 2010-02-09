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

#import "KeyboardRowColumnLayout.h"
#import "KeyboardView.h"

@interface KeyboardRowColumnLayout(Private)

- (void)doLayout;

@end

@implementation KeyboardRowColumnLayout

@synthesize columns, widths;

- (id)initWithFrame:(CGRect)frame andColumns:(NSArray*)theColumns andWidths:(NSArray*)theWidths {
    self = [super initWithFrame:frame];
	
	self.columns	= theColumns;
	self.widths		= theWidths;
	
	[self doLayout];
	
    return self;
}

- (void)doLayout {
	CGFloat xpadding	= kDefaultPaddingBetweenKeys;			// padding between keys
	int x = 0;
	int xstart = 0;
	for (int i = 0; i < self.widths.count; i++) {
		int width = [(NSNumber*)[widths objectAtIndex:i] intValue];
		x = xstart;
		NSArray *keys = [columns objectAtIndex:i];
		if (keys.count > 0) {
			for(KeyView *key in keys) {
				[key setFrame:CGRectMake(x, 0, key.normalWidth, key.normalHeight)];
				[self addSubview:key];
				x += xpadding + key.normalWidth;
			}
		}
		xstart += width;
	}
}

- (void)dealloc {
	self.widths		= nil;
	self.columns	= nil;
    [super dealloc];
}


@end
