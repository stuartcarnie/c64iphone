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

#import "GameBrowserListViewCell.h"
#import "BlocksAdditions.h"
#import "GamePack.h"

@implementation GameBrowserListViewCell

@synthesize coverArt, gameTitle, run, details, enableTrainer, enableTrainerSwitch;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier]) {
        // Initialization code
    }
    return self;
}

- (void)toggleHasTrainer:(UIButton*)sender {
	sender.selected = !sender.selected;
	gameInfo.useTrainer = sender.selected;
}

- (void)setGameInfo:(GameInfo*)info row:(NSUInteger)row {
	gameInfo = info;
	gameTitle.text = info.gameTitle;
	gameTitle.tag = row;
	
	run.tag = row;
	details.tag = row;
	
	_cancelLoad = NO;
	coverArt.alpha = 0.0;
	
	BOOL hasTrainer = info.trainerState != nil;
	enableTrainer.hidden = enableTrainerSwitch.hidden = !hasTrainer;
	if (hasTrainer)
		enableTrainerSwitch.selected = info.useTrainer;
	
	[UIImage imageWithContentsOfFile:info.coverArtPath whenReadyBlock:^(UIImage *image) {
		if (_cancelLoad) return;
		coverArt.image = image;
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.5];
		coverArt.alpha = 1.0;
		[UIView commitAnimations];
	}];
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
	[super willMoveToSuperview:newSuperview];
	
	if(!newSuperview) {
		_cancelLoad = YES;
	}
}

- (void)dealloc {
	self.coverArt		= nil;
	self.gameTitle		= nil;
	self.enableTrainer	= nil;
	self.enableTrainerSwitch = nil;
	self.run			= nil;
	
    [super dealloc];
}


@end
