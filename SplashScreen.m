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

#import "SplashScreen.h"
#include <stdlib.h>
#import "CocoaUtility.h"
#import "i64ApplicationDelegate.h"
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>


@interface SplashScreen(Private)

- (void)animateWelcomeImage;
- (void)toggleButton;

@end

@implementation SplashScreen

const double	kWelcomeAnimationDuration	= 0.400;
const double	kButtonAnimationRate		= 1.0;
#define			kButtonCentre				CGPointMake(133,300)

@synthesize baseImage, welcomeImage, button1, button2, button_on;

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        // Initialization code
		UIImageView *view = [UIImageView newViewFromImageResource:@"Default.png"];
		self.baseImage = view;
		[view release];
		
		view = [UIImageView newViewFromImageResource:@"splash-window.png"];
		self.welcomeImage = view;
		[view release];
		self.welcomeImage.center = CGPointMake(160, 240);
		
		view = [UIImageView newViewFromImageResource:@"splash-button1.png"];
		self.button1 = view;
		[view release];
		[welcomeImage addSubview:self.button1];
		self.button1.center = kButtonCentre;

		view = [UIImageView newViewFromImageResource:@"splash-button2.png"];
		self.button2 = view;
		self.button2.hidden = YES;
		[view release];
		[welcomeImage addSubview:self.button2];
		self.button2.center = kButtonCentre;
		
		view = [UIImageView newViewFromImageResource:@"splash-button_on.png"];
		self.button_on = view;
		self.button_on.hidden = YES;
		[view release];
		[welcomeImage addSubview:self.button_on];
		self.button_on.center = kButtonCentre;
		
		[self addSubview:baseImage];
		[self addSubview:welcomeImage];
		
		[self performSelector:@selector(animateWelcomeImage) withObject:nil afterDelay:0.05];
		
		NSString *soundFile = [[NSBundle mainBundle] pathForResource:@"sound_click3.wav" ofType:nil];
		NSData *soundData = [[NSData alloc] initWithContentsOfFile:soundFile];
		clickSound = [[AVAudioPlayer alloc] initWithData:soundData error:nil];
		[soundData release];
	}
    return self;
}

#pragma mark -
#pragma mark Flicker Animation

CAMediaTimingFunction* GetTiming(NSString* name) {return [CAMediaTimingFunction functionWithName:name];}
float kTension = 0.66;
NSString *kWelcomeImageAnimationKeyPath = @"transform.scale";

/**
 * Delegate method to propagate resting positions to the Core Animation's layer tree.
 */
- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag
{
	NSString* keyPath = [((CAKeyframeAnimation *)theAnimation) keyPath];
	if ([keyPath isEqualToString:kWelcomeImageAnimationKeyPath]) {
		[welcomeImage.layer setValue:[NSNumber numberWithFloat:1.0] forKeyPath:kWelcomeImageAnimationKeyPath];
		
		_buttonTimer = [NSTimer scheduledTimerWithTimeInterval:kButtonAnimationRate target:self selector:@selector(toggleButton) userInfo:nil repeats:YES];
	}
}

- (void)animateWelcomeImage {
	[CATransaction begin];
	[CATransaction setValue:[NSNumber numberWithFloat:kWelcomeAnimationDuration] forKey:kCATransactionAnimationDuration];
	
	CAKeyframeAnimation * animation;
	animation = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
	animation.duration = kWelcomeAnimationDuration;
    animation.delegate = self;
    animation.removedOnCompletion = NO;
    animation.fillMode = kCAFillModeForwards;
    animation.beginTime = CACurrentMediaTime();
	
	// Create arrays for values and associated timings.
    NSMutableArray *values = [NSMutableArray array];
    NSMutableArray *timings = [NSMutableArray array];
	float bounceHeight = 0.3;
	float heightAtRest = 1.0;
    while (bounceHeight > 0.01) {
        // Bounce up
		[values addObject:[NSNumber numberWithFloat:heightAtRest + bounceHeight]];
		[timings addObject:GetTiming(kCAMediaTimingFunctionEaseOut)];
		
        // Reduce the height of the bounce by the spring's tension
		bounceHeight *= kTension;

        // Bounce down
		[values addObject:[NSNumber numberWithFloat:heightAtRest - bounceHeight]];
		[timings addObject:GetTiming(kCAMediaTimingFunctionEaseIn)];

		// Reduce the height of the bounce by the spring's tension
		bounceHeight *= kTension;
	}
	animation.values = values;
	animation.timingFunctions = timings;
	
	[welcomeImage.layer addAnimation:animation forKey:kWelcomeImageAnimationKeyPath];
	
	[CATransaction commit];
}

#pragma mark Button Animation

- (void)toggleButton {
	button1.hidden = !button1.hidden;
	button2.hidden = !button2.hidden;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	[clickSound play];
	button1.hidden		= YES;
	button2.hidden		= YES;
	button_on.hidden	= NO;
	[self performSelector:@selector(removeFromSuperview) withObject:nil afterDelay:0.1];
}

#pragma mark Cleanup

- (void)removeFromSuperview {
	[_timer invalidate];
	_timer = nil;
	if (_buttonTimer) {
		[_buttonTimer invalidate];
		_buttonTimer = nil;
	}
	[super removeFromSuperview];
	[g_application showGameShelf];
}

- (void)dealloc {
	g_application.splashScreenActive = NO;
	self.baseImage = nil;
	self.welcomeImage = nil;
	self.button1 = nil;
	self.button2 = nil;
	self.button_on = nil;
	[clickSound release];
    [super dealloc];
}


@end
