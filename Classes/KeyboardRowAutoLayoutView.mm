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

#import "KeyboardRowAutoLayoutView.h"
#import "KeyboardView.h"

@interface KeyboardRowAutoLayoutView(Private)

- (void)doLayout;

@end

@implementation KeyboardRowAutoLayoutView

@synthesize row;

- (id)initWithFrame:(CGRect)frame andRow:(KeyboardRow*)theRow {
    if (self = [super initWithFrame:frame]) {
		self.opaque = YES;
		
		self.row = theRow;
		for(UIView *key in self.row.left)
			[self addSubview:key];
		for(UIView *key in self.row.centre)
			[self addSubview:key];
		for(UIView *key in self.row.right)
			[self addSubview:key];
		
		[self doLayout];
    }
    return self;
}

- (void)doLayout {
	CGFloat viewWidth	= self.bounds.size.width;
	CGFloat xpadding	= kDefaultPaddingBetweenKeys;			// padding between keys
	
	// layout left portion of row
	if (row.left && row.left.count) {
		CGFloat totalWidth = [row calculateWidthFor:KALeft];
		
		// include spacers between keys in total width calculation
		totalWidth += xpadding * ([row.left count] - 1);
		
		// start with margin on left
		CGFloat x = 0;
		
		// update individual button frames with new layout
		for (KeyView* btn in row.left) {
			[btn setFrame:CGRectMake(x, 0, btn.normalWidth, btn.normalHeight)];
			x += xpadding + btn.normalWidth;
		}
	}
	
	// layout centre portion of row
	if (row.centre && row.centre.count) {
		CGFloat totalWidth = [row calculateWidthFor:KACentre];
		
		// include spacers between keys in total width calculation
		totalWidth += xpadding * ([row.centre count] - 1);
		
		// calculate offset from centre
		CGFloat x = round((viewWidth / 2.0) - (totalWidth / 2.0));
		
		// update individual button frames with new layout
		for (KeyView* btn in row.centre) {
			[btn setFrame:CGRectMake(x, 0, btn.normalWidth, btn.normalHeight)];
			x += xpadding + btn.normalWidth;
		}
	}
	
	// layout right portion of row
	if (row.right && row.right.count) {
		CGFloat totalWidth = [row calculateWidthFor:KARight];
		
		// include spacers between keys in total width calculation
		totalWidth += xpadding * ([row.right count] - 1);
		
		// start with margin on left
		CGFloat x = viewWidth - totalWidth;
		
		// update individual button frames with new layout
		for (KeyView* btn in row.right) {
			[btn setFrame:CGRectMake(x, 0, btn.normalWidth, btn.normalHeight)];
			x += xpadding + btn.normalWidth;
		}
	}
}

- (void)dealloc {
    [super dealloc];
}


@end

#pragma mark KeyboardRow

@implementation KeyboardRow

@synthesize left, centre, right;

- (id)init {
	[super init];
	return self;
}

- (void)dealloc {
	[left release];
	[centre release];
	[right release];
	[super dealloc];
}

- (NSMutableArray*)left {
	if (!left)
		left = [[NSMutableArray alloc] init];	
	return left;
}

- (NSMutableArray*)centre {
	if (!centre)
		centre = [[NSMutableArray alloc] init];	
	return centre;
}

- (NSMutableArray*)right {
	if (!right)
		right = [[NSMutableArray alloc] init];	
	return right;
}

- (CGFloat) calculateWidthFor:(KeyAlignment)theAlignment {
	NSMutableArray *row = nil;
	if (theAlignment == KALeft) {
		row = left;
	} else if (theAlignment == KACentre) {
		row = centre;
	} else if (right) {
		row = right;
	}
	if (!row)
		return 0.0;
	
	CGFloat totalWidth = 0.0;
	for (KeyView* btn in row) {
		totalWidth += btn.normalWidth;
	}		
	return totalWidth;
}

@end
