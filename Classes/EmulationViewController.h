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
#import "MultiLayoutKeyboardViewProtocol.h"
#import "ControlsToolbarView.h"

@class DisplayView;
@class InputControllerView;
@class EmulationView;
@class JoystickView;
@class JoystickViewLandscape;
class Frodo;
@class CommodoreKeyboard;
@class CustomKeyboard;
@class C64State, LandscapeOverlay;

enum tagEmulatorState {
	EmulatorNotStarted,
	EmulatorPaused,
	EmulatorRunning
};

enum tagActiveKeyboardType {
	ActiveKeyboardNone,
	ActiveKeyboardCommodore,
	ActiveKeyboardCustom
};

@interface EmulationViewController : UIViewController<UIEnhancedKeyboardDelegate, UIAccelerometerDelegate, ControlsToolbarChangedDelegate, UIAlertViewDelegate> {
	// Views: both orientations
	DisplayView					*displayView;
	InputControllerView			*inputController;
	
	// Views: portrait
	UIView						*keyboardView;
	id<MultiLayoutKeyboardView>	currentKeyboard;
	
	UIImageView					*keyboardBackground;
	
	UIImageView					*portraitSkinView;
	UIImageView					*portraitNoBasic;
	ControlsToolbarView			*toolbar;
	ControlsToolbarState		toolbarState;
	JoystickView				*joystickView;
	JoystickViewLandscape		*landscapeJoystickView;
	
	// Views: landscape
	UIImageView					*skinImage;
	UIImageView					*skinImageNoBasic;
	LandscapeOverlay			*ls_overlay;
	UIImageView					*fullScreenBottomBar;
	UIButton					*landscapeToFullScreenButton;
	UIButton					*toggleFromFullScreen;

	// Emulator
	Frodo						*emulator;
	NSThread					*emulationThread;
	tagEmulatorState			emulatorState;
	
	// keyboard show / hide using shake
	UIAccelerationValue			myAccelerometer[3];
	CFTimeInterval				lastTime;

	// Layout state information
	UIInterfaceOrientation		layoutOrientation;		// The orientation of the current layout
	BOOL						isKeyboardVisible;
	
	tagActiveKeyboardType		activeKeyboardType;
	NSString					*customKeyboardName;
	CommodoreKeyboard			*commodoreKeyboard;
	CustomKeyboard				*customKeyboard;

	// if YES, will check if a save game exists for the currently loaded disk and prompt 
	// the user if they wish to load it.
	BOOL						checkForSaveGame;
	
	BOOL						isFullScreen;
	
	BOOL						controlsMode;
}

@property (nonatomic)			Frodo						*emulator;
@property (nonatomic)			tagEmulatorState			emulatorState;

@property (nonatomic, retain)	DisplayView					*displayView;
@property (nonatomic, retain)	InputControllerView			*inputController;
@property (nonatomic, retain)	UIView						*keyboardView;
@property (nonatomic, retain)	CommodoreKeyboard			*commodoreKeyboard;
@property (nonatomic, retain)	CustomKeyboard				*customKeyboard;
@property (nonatomic, retain)	id<MultiLayoutKeyboardView>	currentKeyboard;
@property (nonatomic, retain)	UIImageView					*keyboardBackground;

@property (nonatomic, retain)	JoystickView				*joystickView;
@property (nonatomic, retain)	JoystickViewLandscape		*landscapeJoystickView;
@property (nonatomic, retain)	UIImageView					*portraitSkinView;
@property (nonatomic, retain)	UIImageView					*skinImage;
@property (nonatomic, retain)	UIImageView					*portraitNoBasic;
@property (nonatomic, retain)	UIImageView					*skinImageNoBasic;
@property (nonatomic, retain)	ControlsToolbarView			*toolbar;


- (void)startEmulator;
- (void)runEmulator;
- (void)pauseEmulator;
- (void)resumeEmulator;
- (void)saveState:(NSString*)fileName;
- (void)loadState:(NSString*)fileName;
- (void)toggleKeyboard;

@end

extern EmulationViewController *g_emulatorViewController;
