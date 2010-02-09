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

#import "ImageBarControl.h"
#import "CocoaUtility.h"

@interface ImageBarControl()

- (void)buttonSelected:(UIButton*)button;
- (void)loadButtonsFromItems:(NSArray*)items;

@end

@implementation ImageBarControl

#define kButtonYPosition		0.0
#define kToolbarFixedHeight		36.0

@synthesize selectedSegmentIndex = _selectedSegment;

#pragma mark -
#pragma mark Helper Functions

CGSize getSizeFromImage(UIButton *button) {
	return button.currentImage.size;
}

#pragma mark -
#pragma mark ImageBarControl

- (id)initWithItems:(NSArray*)items {
	self = [super init];
	if (self) {
		_segments = [NSMutableArray new];
		[self loadButtonsFromItems:items];
		[self setSelectedSegmentIndex:0];
	}
	return self;
}

- (void)frameButton:(UIButton*)button atX:(float*)x {
	CGSize buttonSize = getSizeFromImage(button);
	button.frame = CGRectMake(*x, kButtonYPosition, buttonSize.width, kToolbarFixedHeight);
	*x += buttonSize.width;
}

- (void)layoutSubviews {
	float totalWidth = 0;
	for(UIButton* button in _segments)
		totalWidth += getSizeFromImage(button).width;
		
	float startX = ceilf((self.frame.size.width / 2.0) - (totalWidth / 2.0));
	for(UIButton* button in _segments)
		[self frameButton:button atX:&startX];
}

- (UIButton*)createToolButtonWithImage:(NSString*)imageName andSelectedImage:(NSString*)selectedImageName {
	UIButton *view = [UIButton buttonWithType:UIButtonTypeCustom];

	view.showsTouchWhenHighlighted = YES;
	view.adjustsImageWhenHighlighted = NO;
	
	[view setImage:[UIImage imageFromResource:imageName] forState:UIControlStateNormal];
	[view setImage:[UIImage imageFromResource:selectedImageName] forState:UIControlStateSelected];
	[view addTarget:self action:@selector(buttonSelected:) forControlEvents:UIControlEventTouchUpInside];
	[self addSubview:view];
	return [view retain];
}

- (NSUInteger)numberOfSegments {
	return [_segments count];
}

- (void)setSelectedSegmentIndex:(NSInteger)value {
	if (value < 0 || value >= [_segments count])
		return;
	
	if (_selectedButton) {
		_selectedButton.selected = NO;
	}
	_selectedSegment = value;
	_selectedButton = [_segments objectAtIndex:_selectedSegment];
	_selectedButton.selected = YES;
}

- (void)loadButtonsFromItems:(NSArray*)items {
	int count = [items count];
	float totalWidth = 0;
	for (int i=0; i<count; i+=2) {
		NSString *image = [items objectAtIndex:i];
		NSString *selectedImage = [items objectAtIndex:i+1];
		UIButton *button = [self createToolButtonWithImage:image andSelectedImage:selectedImage];
		button.tag = i/2;
		totalWidth += getSizeFromImage(button).width;
		[_segments addObject:button];
		[button release];
	}
	
	// FIXME: This height should be calculated
	float intPart;
	if (modff(totalWidth / 2.0, &intPart) > 0.1) totalWidth += 1.0;
	self.frame = CGRectMake(0, 0, ceilf(totalWidth), kToolbarFixedHeight);
}

- (void)buttonSelected:(UIButton*)button {
	int index = button.tag;
	if (index != _selectedSegment) {
		self.selectedSegmentIndex = index;
		[self sendActionsForControlEvents:UIControlEventValueChanged];
	}
}

- (void)dealloc {
	[_segments release];
    [super dealloc];
}

@end
