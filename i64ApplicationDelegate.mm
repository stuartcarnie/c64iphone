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

#import "i64ApplicationDelegate.h"
#import <AudioToolbox/AudioServices.h>
#import "debug.h"
#import "EmulationViewController.h"
#import "SplashScreen.h"
#import "GamePack.h"
#import "EncryptDecrypt.h"
#import "CocoaUtility.h"
#import "DebugSupport.h"
#import "ValidationCheck.h"
#import "ValidationCheck+Encryption.h"
#import "FlurryAPI.h"
#import "C64Defaults.h"
#import "MMStoreManager.h"

#import "manomio_keys.h"
#import "OpenFeint.h"
#import "OpenFeint+Dashboard.h"

#ifdef _INTERNAL
#import "FTPDService.h"
#endif

@interface i64ApplicationDelegate()
- (void)reportAppOpenToAdMob;
@end

i64ApplicationDelegate *g_application;

const int kEmulationViewControllerIndex = 1;

@implementation i64ApplicationDelegate

@synthesize gameBrowser, splashScreenActive;

void uncaughtExceptionHandler(NSException *exception) {
    [FlurryAPI logError:@"Uncaught" message:@"Crash!" exception:exception];
}

- (void)initializeOpenfeint {
	
	NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									 [NSNumber numberWithInt:UIInterfaceOrientationPortrait], OpenFeintSettingDashboardOrientation,
									 @"C64", OpenFeintSettingShortDisplayName,
									 [NSNumber numberWithBool:YES], OpenFeintSettingDisableUserGeneratedContent, 
									 [NSNumber numberWithBool:YES], OpenFeintSettingPromptToPostAchievementUnlock,
									 // [NSNumber numberWithBool:YES], OpenFeintSettingAlwaysAskForApprovalInDebug,
									 nil];
	
    [OpenFeint initializeWithProductKey:MM_OPENFEINT_PRODUCTKEY
                              andSecret:MM_OPENFEINT_PRODUCTSECRET
                         andDisplayName:@"Commodore 64"
                            andSettings:settings    // see OpenFeintSettings.h
                           andDelegates:[OFDelegatesContainer containerWithOpenFeintDelegate:self]];              // see OFDelegatesContainer.h
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {
	NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
	
	[MMStoreManager defaultStore];
	
	check2(60);
	[FlurryAPI startSession:MM_FLURRY_APPID];
	
	// ensures defaults are initialized
	[C64Defaults shared];
	
	g_application = self;
		
	// workaround for iPhone OS 2.1 and earlier not honouring the 'Navigation Bar Is Hidden' option in IB
	self.gameBrowser.navigationBarHidden = YES;
	mainController.delegate = self;
	
	[window addSubview:mainController.view];
	UIView *view = [[SplashScreen alloc] initWithFrame:[window frame]];
	[window addSubview:view];
	[view release];
	self.splashScreenActive = YES;
	[window makeKeyAndVisible];
	
	OSStatus res = AudioSessionInitialize(NULL, NULL, NULL, NULL);
	UInt32 sessionCategory = kAudioSessionCategory_AmbientSound;
	res = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
	res = AudioSessionSetActive(true);
	
	emulator = [mainController.viewControllers objectAtIndex:kEmulationViewControllerIndex];
	
	[self initializeOpenfeint];
	[self performSelectorInBackground:@selector(reportAppOpenToAdMob) withObject:nil];
	
#ifdef _INTERNAL
	ftpService = [FTPDService new];
	[ftpService start];
#endif
}


#define kDefaultManomioAlertURL		@"http://www.manomio.com/index.php/iphone/applicationalerts/"

- (void)launchEmulator {
	mainController.selectedIndex = kEmulationViewControllerIndex;
}

- (void)showGameShelf {
	mainController.selectedIndex = 0;
}

- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController {
	if (viewController.tabBarItem.tag == 1001) {
		[OpenFeint launchDashboardWithListLeaderboardsPage];
		return NO;
	}
	
	if (viewController != emulator || 
		[GamePack globalGamePack].currentGame != nil) {
		return YES;
	}
	
	NSString *msg = tabBarController.selectedIndex == 0 ? 
		@"Please choose a game by selecting the RUN/PLAY button" : 
		@"Please choose a game by selecting the RUN/PLAY button from the\nMy Games tab";
	
	[[[[UIAlertView alloc] initWithTitle:@"Want to play?"
							   message:msg
								delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease] show];
	return NO;
}

- (void)dashboardDidDisappear {
	if (mainController.selectedIndex == kEmulationViewControllerIndex)
		[emulator resumeEmulator];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
	if (mainController.selectedIndex == kEmulationViewControllerIndex)
		[emulator resumeEmulator];
	
	[OpenFeint applicationDidBecomeActive];
}

- (void)dashboardWillAppear {
	if (mainController.selectedIndex == kEmulationViewControllerIndex)
		[emulator pauseEmulator];
}

- (void)applicationWillResignActive:(UIApplication *)application {
	if (mainController.selectedIndex == kEmulationViewControllerIndex)
		[emulator pauseEmulator];
	
	[OpenFeint applicationWillResignActive];
}

- (void)applicationWillTerminate:(UIApplication *)application {
	[OpenFeint shutdown];
}

#pragma mark -
#pragma mark Admob Tracking

- (void)reportAppOpenToAdMob {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; // we're in a new thread here, so we need our own autorelease pool
	// Have we already reported an app open?
	NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString *appOpenPath = [documentsDirectory stringByAppendingPathComponent:@"admob_app_open"];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if(![fileManager fileExistsAtPath:appOpenPath]) {
		// Not yet reported -- report now
		NSString *appOpenEndpoint =[NSString stringWithFormat:@"http://a.admob.com/f0?isu=%@&app_id=%@",
									[[UIDevice currentDevice] uniqueIdentifier], @"305504539"];
		NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:appOpenEndpoint]];
		NSURLResponse *response;
		NSError *error;
		NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
		if((!error) && ([(NSHTTPURLResponse *)response statusCode] == 200) && ([responseData length] > 0)) {
			[fileManager createFileAtPath:appOpenPath contents:nil attributes:nil]; // successful report, mark it as such
		}
	}
	[pool release];
}

@end
