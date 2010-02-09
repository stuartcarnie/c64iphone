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

@protocol ControlsToolbarChangedDelegate
@required
- (void)changed;
@end

enum ControlsToolbarState {
	ControlsStateAlpha		= 1000,
	ControlsStateNumeric	= 1001,
	ControlsStateFunction	= 1002,
	ControlsStateJoystick	= 1003
};


@interface ControlsToolbarView : UIView {
	IBOutlet UIButton					*buttonAlpha;
	IBOutlet UIButton					*buttonNumeric;
	IBOutlet UIButton					*buttonFunction;
	IBOutlet UIButton					*buttonJoystick;

	IBOutlet UIButton					*buttonControls;

	ControlsToolbarState				state;
	id<ControlsToolbarChangedDelegate>	delegate;
	BOOL								showGameMode;
	NSArray								*currentButtons;
}

@property (nonatomic) ControlsToolbarState							state;
@property (nonatomic, retain) id<ControlsToolbarChangedDelegate>	delegate;
@property (nonatomic) BOOL											showGameMode;

- (IBAction)selected:(UIButton*)sender;


@end
