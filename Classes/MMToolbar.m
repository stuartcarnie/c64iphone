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


#import "MMToolbar.h"
#import "CocoaUtility.h"

const double kButtonYPosition = 0.0;

@interface MMToolbar()
- (UIButton*)addToolButtonWithImage:(NSString*)imageName andSelectedImage:(NSString*)selectedImageName;
- (CGSize)getSizeFromImage:(UIButton*)button;
- (void)frameButton:(UIButton*)button atX:(float*)x;
- (void)unsetAllButtons;
- (void)selected:(UIButton*)sender;
@end

@implementation MMToolbar

@synthesize delegate, selectedIndex;

- (id)initWithFrame:(CGRect)frame upImages:(NSArray*)upImages downImages:(NSArray*)downImages {
	assert([upImages count] == [downImages count]);

	self = [super initWithFrame:frame];
	
	NSUInteger count = [upImages count];
	for (int i = 0; i < count; i++) {
		UIButton *btn = [self addToolButtonWithImage:[upImages objectAtIndex:i] andSelectedImage:[downImages objectAtIndex:i]];
		btn.tag = i;
	}
	
	return self;
}

- (void)setSelectedIndex:(NSUInteger)index {
	assert(index >= 0 && index < [self.subviews count]);
	
	[self unsetAllButtons];
	[[self.subviews objectAtIndex:index] setSelected:YES];
}

- (void)layoutSubviews {
	float totalWidth = 0;
	for(UIButton* button in self.subviews)
		totalWidth += [self getSizeFromImage:button].width;
	
	float startX = (self.frame.size.width / 2.0) - (totalWidth / 2.0);
	for(UIButton* button in self.subviews)
		[self frameButton:button atX:&startX];
}

- (void)selected:(UIButton*)sender {
	[self unsetAllButtons];
	
	sender.selected = YES;
	
	[delegate changed:sender.tag];
}

- (void)frameButton:(UIButton*)button atX:(float*)x {
	CGSize buttonSize = [self getSizeFromImage:button];
	button.frame = CGRectMake(*x, kButtonYPosition, buttonSize.width, buttonSize.height);
	*x += buttonSize.width;
}

- (void)unsetAllButtons {
	for (UIButton *button in self.subviews)
		if (button.selected)
			button.selected = NO;
}

const int UIControlStateAllNormal = (UIControlStateNormal | UIControlStateHighlighted | UIControlStateDisabled);

- (UIButton*)addToolButtonWithImage:(NSString*)imageName andSelectedImage:(NSString*)selectedImageName {
	UIButton *view = [UIButton buttonWithType:UIButtonTypeCustom];
	[view setImage:[UIImage imageFromResource:imageName] forState:UIControlStateNormal];
	[view setImage:[UIImage imageFromResource:selectedImageName] forState:UIControlStateSelected];
	[view addTarget:self action:@selector(selected:) forControlEvents:UIControlEventTouchUpInside];
	[self addSubview:view];
	return view;
}

- (CGSize)getSizeFromImage:(UIButton*)button {
	return button.currentImage.size;
}

- (void)dealloc {
	self.delegate = nil;
	[super dealloc];
}

@end
