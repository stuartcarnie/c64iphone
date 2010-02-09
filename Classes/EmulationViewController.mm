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

#import "EmulationViewController.h"
#import "C64.h"
#import "debug.h"
#import "Keyboard.h"
#import "Prefs.h"
#import "C64State.h"
#import "DisplayView.h"
#import "InputControllerView.h"
#import "Frodo.h"
#import "ControlsToolbarView.h"
#import "JoystickView.h"
#import "JoystickViewLandscape.h"
#import "Display.h"
#import "CommodoreKeyboard.h"
#import "CustomKeyboard.h"
#import "KeyboardView.h"
#import "CocoaUtility.h"
#import "GamePack.h"
#import "C64Defaults.h"
#import "ValidationCheck.h"
#import "C64State+Version.h"
#import "C64Defaults.h"
#import "LandscapeOverlay.h"

#import "FlurryAPI.h"
static NSString *rungameEvent_start			= @"RunGame.start";
static NSString *rungameEvent_stop			= @"RunGame.stop";

#define USE_ACCELEROMETER				1
#define USE_PORTRAIT_SKIN

#define kAccelerometerFrequency			25	// Hz
#define kFilteringFactor				0.1
#define kMinEraseInterval				0.5
#define kEraseAccelerationThreshold		2.0

EmulationViewController *g_emulatorViewController;

@interface EmulationViewController(PrivateImplementation)

- (void)rotateToPortrait;
- (void)rotateToLandscape;
- (void)didRotate;
- (void)disableAccelerometer;
- (void)enableAccelerometer;
- (void)animationDidStop:(NSString *)animationID finished:(BOOL)finished context:(void *)context;
- (void)shouldMonitorDeviceRotation:(BOOL)value;

- (void)showControlsOverlay;
- (void)hideControlsOverlay;
- (void)displayControlsOverlay:(BOOL)display;

// Keyboard Function
- (void)initializeKeyboard;

// additional state methods
- (void)gameChanged;
- (void)promptForLoadGame;
- (void)loadGameStateWithName:(NSString*)fileName;
- (void)loadGameState;
- (void)saveGameState;

// fullscreen management
- (void)toggleFullScreen:(id)sender;
- (void)setFullScreen:(BOOL)fullScreen;

- (UITabBar*)getTabBarView;

// update state from defaults
- (void)initFromDefaults;
- (void)defaultsChanged:(NSNotification*)notification;

@end

// region heights and positions in pixels
const int kHeaderBarHeight					= 24;
const int kPortraitSkinHeight				= 267;

const int kInputAreaTop						= kPortraitSkinHeight + 1;

// portrait frames
#define kKeyboardFramePortrait				CGRectMake(0, kInputAreaTop, 320, 210)
#define kKeyboardFramePortraitInView		CGRectMake(0, 0, 320, 210)
#define kDisplaySkinFramePortrait			CGRectMake(0, 0, 320, 272)
#define kToolbarFramePortrait				CGRectMake(0, 238, 320, 22)

#if DISPLAY_MODE == DM_CROP_DISPLAY
# define kDisplayFramePortrait				CGRectMake(0, kHeaderBarHeight, 320, DM_CROP_HEIGHT)
#else
# define kDisplayFramePortrait				CGRectMake(-32, kHeaderBarHeight - 35, DISPLAY_X, DISPLAY_Y)
#endif

#define kInputFrameWithKeyboardPortrait		CGRectMake(0, 0, 320, kPortraitSkinHeight)
#define kInputFrameWithoutKeyboardPortrait	CGRectMake(0, kInputAreaTop, 320, 480 - kInputAreaTop)
#define kJoystickViewFramePortrait			CGRectMake(0, kInputAreaTop, 320, 200)

// tabbar
#define kTabBarVisible						CGRectMake(0, 0, 320, 480)
#define kTabBarNotVisible					CGRectMake(0, 0, 320, 480 + 50)

// landscape frames
#define kFullControlsOverlayFrameLandscape	CGRectMake(10, 10, 449, 283)
#define kInputFrameLandscape				CGRectMake(0, 0, 480, 320)

#define kDisplayFrameLandscapeFullScreen	CGRectMake(0, 0, 480, 325.5)
#define kDisplayFrameLandscape				CGRectMake(39, 18, 400, 271.25)

NSString *kDefaultKeyboardBackgroundImage	= @"keys_bg_320x210.png";

// miscellaneous constants
const double kDefaultAnimationDuration					= 250.0 / 1000.0;
const double kDefaultControlsOverlayAnimationDuration	= 100.0 / 1000.0;	// 100 ms

@implementation EmulationViewController

@synthesize emulator, emulatorState;
@synthesize displayView, inputController, keyboardView, currentKeyboard, keyboardBackground;
@synthesize portraitSkinView, skinImage, toolbar, joystickView, landscapeJoystickView;
@synthesize commodoreKeyboard, customKeyboard;
@synthesize portraitNoBasic, skinImageNoBasic;

// Implement loadView to create a view hierarchy programmatically.
- (void)loadView {
	check4(180);
	g_emulatorViewController		= self;
	
	activeKeyboardType				= ActiveKeyboardNone;
	
	self.hidesBottomBarWhenPushed	= YES;
	self.emulatorState				= EmulatorNotStarted;
	checkForSaveGame				= YES;
	toolbarState					= ControlsStateAlpha;
	emulator						= new Frodo();
	
	isFullScreen = [[NSUserDefaults standardUserDefaults] boolForKey:kSettingFullScreenModeDisplaySkin];
	//isBasicEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:kSettingBasicIsEnabled];
	
	layoutOrientation				= (UIInterfaceOrientation)[[UIDevice currentDevice] orientation];
	
	// create all the views, order is important to ensure active areas of the UI are layered on top
	CGRect frame = [UIScreen mainScreen].applicationFrame;
	UIView *view = [[UIView alloc] initWithFrame:frame];
	view.backgroundColor = [UIColor blackColor];
	
	self.displayView = [[DisplayView alloc] initWithFrame:kDisplayFramePortrait];
	[view addSubview:self.displayView];
	
	self.keyboardBackground = [[UIImageView alloc] initWithFrame:kKeyboardFramePortrait];
	[view addSubview:self.keyboardBackground];
	
#if defined(USE_PORTRAIT_SKIN)
	self.portraitSkinView = [UIImageView newViewFromImageResource:@"newoverlay_interlaced.png"];
	self.portraitSkinView.frame = kDisplaySkinFramePortrait;
	[view addSubview:self.portraitSkinView];
#endif
		
	self.skinImage = [UIImageView newViewFromImageResource:@"ls-overlay-skin.png"];
	self.skinImage.alpha = 0.0;
	[view addSubview:skinImage];
	
	fullScreenBottomBar = [UIImageView newViewFromImageResource:@"ls-fullscreen_bottomBtn.png"];
	fullScreenBottomBar.alpha = 0.0;
	fullScreenBottomBar.center = CGPointMake(240, 305);
	[view addSubview:fullScreenBottomBar];
		
	self.joystickView = [[JoystickView alloc] initWithFrame:kJoystickViewFramePortrait];
	self.joystickView.alpha = 0;
	[view addSubview:self.joystickView];
	
	self.inputController = [[InputControllerView alloc] initWithFrame:kInputFrameWithKeyboardPortrait];
	self.inputController.delegate = self.joystickView;
	[view addSubview:self.inputController];
	
	self.landscapeJoystickView = [[JoystickViewLandscape alloc] initWithFrame:kInputFrameLandscape];
	self.landscapeJoystickView.hidden = YES;
	[self.inputController addSubview:self.landscapeJoystickView];
	
	self.toolbar = [[ControlsToolbarView alloc] initWithFrame:kToolbarFramePortrait];
	self.toolbar.delegate = self;
	[view addSubview:self.toolbar];	

	self.keyboardView = [[UIView alloc] initWithFrame:kKeyboardFramePortrait];
	[view addSubview:self.keyboardView];
	isKeyboardVisible = YES;
	
	//
	ls_overlay = [[LandscapeOverlay alloc] initWithFrame:kInputFrameLandscape];
	ls_overlay.alpha = 0.0;	
	ls_overlay.center = CGPointMake(240, 160);
	[view addSubview:ls_overlay];
	
	landscapeToFullScreenButton = [UIButton newButtonWithImage:@"ls-commodorelogoBtn.png" andSelectedImage:nil];
	landscapeToFullScreenButton.alpha = 0.0;
	landscapeToFullScreenButton.center = CGPointMake(240, 300);
	[landscapeToFullScreenButton addTarget:self action:@selector(toggleFullScreen:) forControlEvents:UIControlEventTouchUpInside];
	[view addSubview:landscapeToFullScreenButton];
		
	toggleFromFullScreen = [UIButton buttonWithType:UIButtonTypeCustom];
	toggleFromFullScreen.frame = CGRectMake(0, 0, 30, 20);
	toggleFromFullScreen.center = CGPointMake(240, 310);
	toggleFromFullScreen.alpha = 0.0;
	[toggleFromFullScreen addTarget:self action:@selector(toggleFullScreen:) forControlEvents:UIControlEventTouchUpInside];
	[view addSubview:toggleFromFullScreen];
	
    self.view = view;
	view.userInteractionEnabled = NO;
    [view release];
	
	// monitor device rotation
	[self shouldMonitorDeviceRotation:YES];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(gameChanged)
												 name:kGameChangedNotification 
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(defaultsChanged:) 
												 name:NSUserDefaultsDidChangeNotification object:nil];
	
	[self initFromDefaults];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	self.portraitSkinView	= nil;
	self.skinImage			= nil;
	self.keyboardView		= nil;
	self.currentKeyboard	= nil;
	self.commodoreKeyboard	= nil;
	self.customKeyboard		= nil;
	self.keyboardBackground = nil;
	self.displayView		= nil;
	self.inputController	= nil;
	[ls_overlay release];
	[super dealloc];	
}

- (void)shouldMonitorDeviceRotation:(BOOL)value {
	if (value) {
		[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(didRotate)
													 name:UIDeviceOrientationDidChangeNotification
												   object:nil];
	} else {
		[[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
	}

}

- (void)defaultsChanged:(NSNotification*)notification {
	[self initFromDefaults];
}

- (void)initFromDefaults {
	C64Defaults *d = [C64Defaults shared];
	
	controlsMode = d.controlsMode;
}

- (void)disableAccelerometer {
    [[UIAccelerometer sharedAccelerometer] setDelegate:nil];
}

- (void)enableAccelerometer {
	//Configure and enable the accelerometer
    [[UIAccelerometer sharedAccelerometer] setUpdateInterval:(1.0 / kAccelerometerFrequency)];
    [[UIAccelerometer sharedAccelerometer] setDelegate:self];
}

- (UITabBar*)getTabBarView {
	UIView *tabBarHostView = self.tabBarController.view;
	for (UIView *v in tabBarHostView.subviews) {
		if ([v isMemberOfClass:[UITabBar class]]) {
			return (UITabBar*)v;
		}
	}
	return nil;
}

//	***********************
//! Toolbar button changed
- (void)changed {
	DLog(@"Toolbar clicked");
	ControlsToolbarState state = self.toolbar.state;
	
	if (state == ControlsStateJoystick) {
		if (isKeyboardVisible)
			[self toggleKeyboard];
	} else {
		if (!isKeyboardVisible) {
			[self toggleKeyboard];
		}
		switch (self.toolbar.state) {
			case ControlsStateAlpha:
				[self.currentKeyboard setKeyboardLayout:kKeyboardLayoutAlpha];
				break;
			case ControlsStateNumeric:
				[self.currentKeyboard setKeyboardLayout:kKeyboardLayoutNumeric];
				break;
			case ControlsStateFunction:
				[self.currentKeyboard setKeyboardLayout:kKeyboardLayoutExtended];
				break;
		}
	}
}

#pragma mark Keyboard Methods

- (void)loadCommodoreKeyboard {
	CommodoreKeyboard *view = [[CommodoreKeyboard alloc] initWithFrame:kKeyboardFramePortraitInView];
	view.delegate = self;
	self.commodoreKeyboard = view;
	[view release];
}

- (void)removeCurrentKeyboardFromView {
	if ([keyboardView.subviews count] == 0)
		return;
	
	UIView *view = [keyboardView.subviews objectAtIndex:0];
	[view removeFromSuperview];
}

- (void)initializeKeyboard {
	GameInfo *info = [GamePack globalGamePack].currentGame;
	
	NSDictionary *layout = info.keyboard;
	NSString *backgroundImage = nil;

	tagActiveKeyboardType neededKeyboard = (!layout || ThePrefs.UseCommodoreKeyboard) ? ActiveKeyboardCommodore : ActiveKeyboardCustom;
	if (neededKeyboard == ActiveKeyboardCommodore) {
		if (activeKeyboardType == ActiveKeyboardCommodore)
			return;
		
		[self removeCurrentKeyboardFromView];
		
		if (!commodoreKeyboard)
			[self loadCommodoreKeyboard];
						
		self.currentKeyboard = commodoreKeyboard;
		
		[keyboardView addSubview:commodoreKeyboard];
		activeKeyboardType = ActiveKeyboardCommodore;
		self.toolbar.showGameMode = NO;
	} else {
		NSString *layoutName = [layout valueForKey:@"layout-name"];
		if (activeKeyboardType == ActiveKeyboardCustom && [layoutName isEqual:customKeyboardName])
			return;
		
		[self removeCurrentKeyboardFromView];

		if (![layoutName isEqual:customKeyboardName]) {				
			CustomKeyboard *view = [[CustomKeyboard alloc] initWithFrame:kKeyboardFramePortraitInView andLayout:layout andBasePath:info.sharedImagesPath];
			view.delegate = self;
			self.customKeyboard = view;
			[view release];
		}
		
		customKeyboardName = layoutName;
		// get background image name
		backgroundImage = [info.sharedImagesPath stringByAppendingPathComponent:[layout valueForKey:@"background"]];
		[keyboardView addSubview:customKeyboard];
		activeKeyboardType = ActiveKeyboardCustom;
		self.toolbar.showGameMode = YES;
	}

	if (backgroundImage) {
		self.keyboardBackground.image = [UIImage imageWithContentsOfFile:backgroundImage];
		CGRect frame = self.keyboardBackground.frame;
		CGFloat height = self.keyboardBackground.image.size.height;
		self.keyboardBackground.frame = CGRectMake(frame.origin.x, frame.origin.y, 320, height);
	} else {
		self.keyboardBackground.image = [UIImage imageNamed:kDefaultKeyboardBackgroundImage];
		self.keyboardBackground.frame = kKeyboardFramePortrait;
	}
	
}

#pragma mark Hide / Show keyboard

#define kScaleFactor	100

// Called when the accelerometer detects motion; plays the erase sound and redraws the view if the motion is over a threshold.
- (void)accelerometer:(UIAccelerometer*)accelerometer didAccelerate:(UIAcceleration*)acceleration {
	static double time_start = CFAbsoluteTimeGetCurrent();
		
	if (UIInterfaceOrientationIsLandscape(layoutOrientation) && controlsMode != 2)
		return;
	
    UIAccelerationValue length, x, y, z;
    
    //Use a basic high-pass filter to remove the influence of the gravity
    myAccelerometer[0] = acceleration.x * kFilteringFactor + myAccelerometer[0] * (1.0 - kFilteringFactor);
    myAccelerometer[1] = acceleration.y * kFilteringFactor + myAccelerometer[1] * (1.0 - kFilteringFactor);
    myAccelerometer[2] = acceleration.z * kFilteringFactor + myAccelerometer[2] * (1.0 - kFilteringFactor);
	
	if (controlsMode == 2 && UIInterfaceOrientationIsLandscape(layoutOrientation)) {
		[inputController setAccel:myAccelerometer];
		return;
	}

    // Compute values for the three axes of the acceleromater
    x = acceleration.x - myAccelerometer[0];
    y = acceleration.y - myAccelerometer[0];
    z = acceleration.z - myAccelerometer[0];
    
    //Compute the intensity of the current acceleration 
    length = sqrt(x * x + y * y + z * z);
	CFAbsoluteTime current = CFAbsoluteTimeGetCurrent() - time_start;
    // If above a given threshold, play the erase sounds and erase the drawing view
    if((length >= kEraseAccelerationThreshold) && (current > lastTime + kMinEraseInterval)) {
		if (isKeyboardVisible)
			toolbarState = self.toolbar.state;
		
		[self toggleKeyboard];
		
		if (isKeyboardVisible)
			self.toolbar.state = toolbarState;
		else
			self.toolbar.state = ControlsStateJoystick;
		
        lastTime = current;
    }
}

- (void)toggleKeyboard {
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	[UIView beginAnimations:nil context:ctx];
	
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDuration:kDefaultAnimationDuration];
	
	isKeyboardVisible = !isKeyboardVisible;
	if (isKeyboardVisible) {
		keyboardBackground.alpha	= 1.0;
		keyboardView.alpha			= 1.0;
		joystickView.alpha			= 0.0;
		inputController.frame		= kInputFrameWithKeyboardPortrait;
	} else {
		keyboardBackground.alpha	= 0.0;
		keyboardView.alpha			= 0.0;
		joystickView.alpha			= 1.0;
		inputController.frame		= kInputFrameWithoutKeyboardPortrait;
	}
	
	[UIView commitAnimations];
}

#pragma mark Rotation handlers

#define degreesToRadian(x) (M_PI  * x / 180.0)

- (void)didRotate {
	if (self.tabBarController.selectedViewController != self)
		return;
	
	UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
	if (!UIDeviceOrientationIsValidInterfaceOrientation(orientation) || layoutOrientation == (UIInterfaceOrientation)orientation)
		return;

	DLog(@"didRotate:");

	layoutOrientation = (UIInterfaceOrientation)orientation;
	
	[UIView beginAnimations:@"rotate" context:nil];

	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];

	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDuration:kDefaultAnimationDuration];
		
	self.view.center = CGPointMake(160, 240);

	if (UIInterfaceOrientationIsLandscape(layoutOrientation)) {
		inputController.isLandscape = YES;
		
		self.tabBarController.view.frame = kTabBarNotVisible;
		UIView *parent = self.view.superview;
		parent.frame = kTabBarVisible;
		
		if (layoutOrientation == UIInterfaceOrientationLandscapeLeft) {
			self.view.transform = CGAffineTransformMakeRotation(degreesToRadian(-90));
		} else {
			self.view.transform = CGAffineTransformMakeRotation(degreesToRadian(90));
		}
		self.view.bounds = CGRectMake(0, 0, 480, 320);
		
		[self rotateToLandscape];
	} else {
		inputController.isLandscape = NO;
		
		self.tabBarController.view.frame = kTabBarVisible;
		self.view.transform = CGAffineTransformIdentity;
		self.view.bounds = CGRectMake(0, 0, 320, 480);
		
		[self rotateToPortrait];
	}
	
	[UIView commitAnimations];
}

- (void)rotateToPortrait {
	DLog(@"Rotating to portrait");
	
	[self getTabBarView].hidden = NO;

	// hide landscape views
	self.skinImage.alpha				= 0.0;
	landscapeToFullScreenButton.alpha	= 0.0;
	fullScreenBottomBar.alpha			= 0.0;
	toggleFromFullScreen.alpha			= 0.0;

#if defined(USE_PORTRAIT_SKIN)
	// show header
	self.portraitSkinView.alpha			= 1.0;
#endif
	self.toolbar.alpha					= 1.0;
		
	self.displayView.frame = kDisplayFramePortrait;
	[self.displayView setNeedsLayout];
	
	self.landscapeJoystickView.hidden	= YES;
	self.inputController.delegate		= joystickView;
	
	if (isKeyboardVisible) {
		self.keyboardBackground.alpha	= 1.0;
		self.keyboardView.alpha			= 1.0;
		self.inputController.frame		= kInputFrameWithKeyboardPortrait;
	} else {
		self.joystickView.alpha			= 1.0;
		self.inputController.frame		= kInputFrameWithoutKeyboardPortrait;
	}
}

- (void)rotateToLandscape {
	DLog(@"Rotating to landscape");

	// hide portrait views
#if defined(USE_PORTRAIT_SKIN)
	// hide header
	self.portraitSkinView.alpha			= 0.0;
#endif
	
	self.toolbar.alpha					= 0.0;
	
	// hide keyboard
	self.keyboardBackground.alpha		= 0.0;
	self.keyboardView.alpha				= 0.0;
	
	// hide joystick
	self.joystickView.alpha				= 0.0;
	self.landscapeJoystickView.hidden	= NO;
	self.inputController.delegate		= landscapeJoystickView;	
	self.inputController.frame			= kInputFrameLandscape;
	self.landscapeJoystickView.frame	= kInputFrameLandscape;
	
	// show landscape views
	[self setFullScreen:isFullScreen];
}

- (void)animationDidStop:(NSString *)animationID finished:(BOOL)finished context:(void *)context {
	if (!UIInterfaceOrientationIsLandscape(layoutOrientation))
		return;
	
	[self getTabBarView].hidden = YES;
	
	if ([animationID isEqual:@"rotate"]) {		
		[self displayControlsOverlay:YES];
		
		// hide overlay after 2 seconds
		[self performSelector:@selector(hideControlsOverlay) withObject:nil afterDelay:2.0];
	}
}

- (void)showControlsOverlay {
	[self displayControlsOverlay:YES];
}

- (void)hideControlsOverlay {
	[self displayControlsOverlay:NO];
}

- (void)displayControlsOverlay:(BOOL)display {
	DLog(@"Displaying landscape controller layout");
	
	//self.fullControlsImage.frame = kFullControlsOverlayFrameLandscape;
	ls_overlay.center = CGPointMake(240, 160);
	[UIView beginAnimations:@"overlay-open" context:nil];
	[UIView setAnimationCurve:UIViewAnimationCurveLinear];
	[UIView setAnimationDuration:kDefaultControlsOverlayAnimationDuration];

	ls_overlay.alpha = display ? 1.0 : 0.0;
	[UIView commitAnimations];	
}

- (void)viewWillAppear:(BOOL)animated {
	check1(18);
	GameInfo *info = [GamePack globalGamePack].currentGame;
	if (info)
		[FlurryAPI logEvent:rungameEvent_start withParameters:[NSDictionary dictionaryWithObject:info.gameTitle forKey:@"game"]];
	else
		[FlurryAPI logEvent:rungameEvent_start];

	[self initializeKeyboard];
}

- (void)viewDidAppear:(BOOL)animated {
	check2(48);
	DLog(@"viewDidAppear: starting emulator");
	
	// These two lines are THE check required by Apple, so that the emulator will
	// only run with active games.
	// Remove to get back the beloved BASIC!
	//GameInfo *info = [GamePack globalGamePack].currentGame;
	//if (!info) return;
	
	[self startEmulator];
	if (checkForSaveGame) {
		checkForSaveGame = NO;
		[self promptForLoadGame];
	}
	// [self enableAccelerometer];
}

- (void)viewWillDisappear:(BOOL)animated {
	check3(31);
	[FlurryAPI logEvent:rungameEvent_stop];

	//GameInfo *info = [GamePack globalGamePack].currentGame;
	//if (!info) return;
	DLog(@"viewWillDisappear: pausing emulator");
	
	// [self disableAccelerometer];
	[self pauseEmulator];
	[self saveGameState];
}

#pragma mark State functions

NSString* getCurrentStateName() {
	GameInfo *info = [GamePack globalGamePack].currentGame;
	if (!info)
		return nil;
	
	NSString *disk = [info.gameId stringByAppendingPathExtension:@"state"];
	return disk;
}

- (void)gameChanged {
	GameInfo *info = [GamePack globalGamePack].currentGame;
	if (info && (info.autoSave || info.launchState))
		checkForSaveGame = YES;
	else
		checkForSaveGame = NO;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex != 0)
		return;
	
	[self loadGameStateWithName:[DOCUMENTS_FOLDER stringByAppendingPathComponent:getCurrentStateName()]];
}

- (void)loadGameStateWithName:(NSString*)fileName {
	[self pauseEmulator];
	while (!emulator->TheC64->InPauseLoop()) {
		CFRunLoopRunInMode(kCFRunLoopDefaultMode, 50.0 / 1000.0, false);
	}
	[self loadState:fileName];
	[self resumeEmulator];
}

- (void)promptForLoadGame {
	GameInfo *info = [GamePack globalGamePack].currentGame;
	if (!info || !info.autoSave)
		return;
	
	if (info.launchState) {
		[self loadGameStateWithName:[info.basePath stringByAppendingPathComponent:info.launchState]];
	}
	
	NSString *stateName = getCurrentStateName();
	NSString *path = [DOCUMENTS_FOLDER stringByAppendingPathComponent:stateName];
	if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
		C64State *state = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
		if (state.validVersion) {
			UIAlertView *view = [[UIAlertView alloc] initWithTitle:@"Save Game" message:@"Resume previous game?" delegate:self cancelButtonTitle:nil otherButtonTitles:@"Yes", @"No", nil];
			[view show];
			[view release];
		}
	}
}

- (void)loadGameState {
	NSAssert(emulatorState == EmulatorPaused, @"Emulator must be paused before calling loadGameState");

	NSString *fullPath = [DOCUMENTS_FOLDER stringByAppendingPathComponent:getCurrentStateName()];
	[self loadState:fullPath];
}

- (void)saveGameState {
	NSAssert(emulatorState == EmulatorPaused, @"Emulator should be paused before calling saveGameState");

	if (!check4(22)) {
		// do not save if unlicensed
		return;
	}
	
	GameInfo *info = [GamePack globalGamePack].currentGame;
	if (!info || !info.autoSave)
		return;	
	NSString *fullPath = [DOCUMENTS_FOLDER stringByAppendingPathComponent:getCurrentStateName()];
	[self saveState:fullPath];
}

- (void)saveState:(NSString*)fileName {
	NSAssert(emulator, @"Emulator must be launched and paused");
	
	C64State *state = [[[C64State alloc] init] autorelease];
	emulator->TheC64->SaveSnapshot(state.part1, state.part2);
	[NSKeyedArchiver archiveRootObject:state toFile:fileName];
}

- (void)loadState:(NSString*)fileName {
	NSAssert(emulator, @"Emulator must be launched and paused");
	
	C64State *state;
	state = [NSKeyedUnarchiver unarchiveObjectWithFile:fileName];
	if (state && state.part1 && state.part2)
		emulator->TheC64->LoadSnapshot(state.part1, state.part2);
}

#pragma mark Emulator Functions

- (void)enableUserInteraction {
	self.view.userInteractionEnabled = YES;
}

- (void)startEmulator {
	if (!emulator) return;

	if (emulatorState == EmulatorPaused) {
		[self resumeEmulator];
	} else if (emulatorState == EmulatorNotStarted) {
		emulationThread = [[NSThread alloc] initWithTarget:self selector:@selector(runEmulator) object:nil];
		[emulationThread start];
		
		// wait until emulator is running before continuing
		while (!(emulator->TheC64 && emulator->TheC64->IsEmulatorRunning())) {
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, 50.0 / 1000.0, false);
		}
		
		[self enableUserInteraction];
	}
}

- (void)stopEmulator {
	NSAssert(emulator != NULL, @"emulator should not be NULL");
	
	emulator->TheC64->Quit();
	while (![emulationThread isFinished]) {
		usleep(100);
	}
	[emulationThread release];
}

- (void)runEmulator {
	self.emulatorState = EmulatorRunning;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[NSThread setThreadPriority:0.7];
	emulator->ReadyToRun();
	[pool release];
}

- (void)pauseEmulator {
	NSAssert(emulator != NULL, @"emulator cannot be NULL");
	DLog(@"pausing emulator");
	
	[self shouldMonitorDeviceRotation:NO];
	emulator->TheC64->Pause();
	emulatorState = EmulatorPaused;
}

- (void)resumeEmulator {
	NSAssert(emulator != NULL, @"emulator cannot be NULL");
	if (emulatorState != EmulatorPaused)
		return;
	
	DLog(@"resuming emulator");
	
	[self shouldMonitorDeviceRotation:YES];
	emulatorState = EmulatorRunning;
	emulator->TheC64->Resume();
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; 
}

#pragma mark Full Screen Handling

- (void)toggleFullScreen:(id)sender {
	[UIView beginAnimations:@"toggle-fullscreen" context:nil];
		
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDuration:kDefaultControlsOverlayAnimationDuration];
	
	[self setFullScreen:(sender == landscapeToFullScreenButton)];

	[UIView commitAnimations];
	[[NSUserDefaults standardUserDefaults] setBool:isFullScreen forKey:kSettingFullScreenModeDisplaySkin];
}

- (void)setFullScreen:(BOOL)fullScreen {
	if (fullScreen) {
		landscapeToFullScreenButton.alpha = 0.0;
		skinImage.alpha = 0.0;
		displayView.frame = kDisplayFrameLandscapeFullScreen;
		
		fullScreenBottomBar.alpha = 1.0;
		toggleFromFullScreen.alpha = 1.0;
		
		isFullScreen = YES;
	} else {		
		landscapeToFullScreenButton.alpha = 1.0;
		skinImage.alpha	= 1.0;
		displayView.frame = kDisplayFrameLandscape;
		
		fullScreenBottomBar.alpha = 0.0;
		toggleFromFullScreen.alpha = 0.0;
		
		isFullScreen = NO;
	}
}

#pragma mark UIEnhancedKeyboardDelegate

- (void)keyDown:(int)keyCode {
	if (keyCode > KeyCode_UIBASE)
		return;
	
	emulator->TheC64->TheKeyboard->QueueKeyEvent((KeyCode)keyCode, KeyStateDown);
}

- (void)keyUp:(int)keyCode {
	emulator->TheC64->TheKeyboard->QueueKeyEvent((KeyCode)keyCode, KeyStateDown);
	emulator->TheC64->TheKeyboard->QueueKeyEvent(KeyCode_HOLD_KEY, KeyStateUp);
	emulator->TheC64->TheKeyboard->QueueKeyEvent((KeyCode)keyCode, KeyStateUp);
}

@end
