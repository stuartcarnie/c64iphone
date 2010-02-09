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


#import "GamePack.h"
#import "Prefs.h"
#import "Frodo.h"
#import "C64.h"
#import "ValidationCheck+Encryption.h"
#import "i64ApplicationDelegate.h"

#import "GamePack+Private.h"

@interface GameInfo(PrivateImplementation)

- (void)checkKeyboardLayout:(NSDictionary*)layout;
- (void)processConfig:(NSDictionary*)config;
- (void)updatePrefs:(Prefs*)thePrefs;

@end

@implementation GameInfo

@synthesize coverArtPath, gameTitle, gameId, basePath, paths, initialState, trainerState, runtimeScript, applicationType;
@synthesize info1Title, info1;
@synthesize info2Title, info2;
@synthesize info3Title, info3;
@synthesize info4Title, info4;
@synthesize description;
@synthesize	previewImages;
@synthesize keyboard, keyboardLayoutName, autoSave, version, isInBundle, isInactive;

// prefs

- (id)initWithDictionary:(NSDictionary*)dict {
	self = [super init];
	
	self.gameTitle		= [dict valueForKey:@"gameTitle"];
	self.gameId			= [dict valueForKey:@"gameid"];
	self.paths			= [dict valueForKey:@"game-images"];
	self.initialState	= [dict valueForKey:@"initialState"];
	self.coverArtPath	= [dict valueForKey:@"coverArtPath"];
	self.info1Title		= [dict valueForKey:@"info1Title"];
	self.info1			= [dict valueForKey:@"info1"];
	self.info2Title		= [dict valueForKey:@"info2Title"];
	self.info2			= [dict valueForKey:@"info2"];
	self.info3Title		= [dict valueForKey:@"info3Title"];
	self.info3			= [dict valueForKey:@"info3"];
	self.description	= [dict valueForKey:@"description"];
	self.previewImages	= [dict valueForKey:@"previewImages"];
	NSNumber *num		= [dict valueForKey:@"autoBoot"];
	autoBoot			= num ? [num boolValue] : YES;
	
	num					= [dict valueForKey:@"autoSave"];
	autoSave			= num ? [num boolValue] : YES;
	
	num					= [dict valueForKey:@"version"];
	version				= num ? [num intValue] : 0;
	
	NSString* appType	= [dict valueForKey:@"application-type"];
	if ([appType isEqual:@"game"])
		applicationType = GameApplicationType;
	else if ([appType isEqual:@"demo"])
		applicationType = DemoApplicationType;
	else
		applicationType = OtherApplicationType;
	
	// prefs
	NSDictionary *config = [dict valueForKey:@"config"];
	_pref_flags.val = 0x00000000;
	
	if (config)
		[self processConfig:config];
	
	[self checkKeyboardLayout:[dict valueForKey:@"keyboard"]];
	
	return self;
}

- (BOOL)isEqual:(GameInfo *)other {
	return [gameId isEqual:other->gameId];
}

- (NSUInteger)hash {
	return [gameId hash];
}

- (NSComparisonResult)compare:(GameInfo*)anotherGameInfo {
	return [gameTitle caseInsensitiveCompare:anotherGameInfo->gameTitle];
}

- (id)initWithContentsOfGameInfoFile:(NSString*)gameInfoPath isBundlePath:(BOOL)isBundlePath {
	NSString *errorDesc = nil;
	NSPropertyListFormat format;
	NSData *plistXML = [[NSData alloc] initWithContentsOfFile:gameInfoPath];
	NSArray *temp = (NSArray *)[NSPropertyListSerialization
								propertyListFromData:plistXML
								mutabilityOption:NSPropertyListMutableContainersAndLeaves
								format:&format errorDescription:&errorDesc];
	[plistXML release];
	
	if (!temp) {
		NSLog(errorDesc);
		[errorDesc release];
		return nil;
	}
	
	
	self = [self initWithDictionary:[temp objectAtIndex:0]];
	
	// sets the base path
	self.basePath = [gameInfoPath stringByDeletingLastPathComponent];
	isInBundle = isBundlePath;
	
	NSString* ts = [NSString stringWithFormat:@"%@.trainer.state", self.gameId];
	if ([[NSFileManager defaultManager] fileExistsAtPath:[self.basePath stringByAppendingPathComponent:ts]]) {
		self.trainerState = ts;
	}
	
	NSString* rs = [NSString stringWithFormat:@"%@.runtime.lua", self.gameId];
	if ([[NSFileManager defaultManager] fileExistsAtPath:[self.basePath stringByAppendingPathComponent:rs]]) {
		self.runtimeScript = rs;
	}
	
	
	return self;
}

- (NSString*)sharedImagesPath {
	if (isInBundle)
		return basePath;
	
	return [[GamePack globalGamePack] sharedImagesPath];
}

- (void)launchGame {
	check3(35);
	[GamePack globalGamePack].currentGame = self;
	
	Prefs prefs;
	prefs.Load(Frodo::prefs_path());
	[self updatePrefs:&prefs];
	prefs.ConfigureOptimizations();
	
	if ([self.paths count] != 0) {		
		NSString *romPath = [basePath stringByAppendingPathComponent:[self.paths objectAtIndex:0]];
		prefs.ChangeRom(romPath);
	}
	
	if (self.runtimeScript) {
		NSString *scriptPath = [basePath stringByAppendingPathComponent:self.runtimeScript];
		prefs.LuaScript(scriptPath);	
	} else {
		prefs.LuaScript(nil);
	}
	
	prefs.Save(Frodo::prefs_path());
	
	if (Frodo::Instance && Frodo::Instance->TheC64) {
		Frodo::Instance->TheC64->NewPrefs(&prefs);
	}
	
	ThePrefs = prefs;
	
	if ([self.paths count] != 0) {
		if (autoBoot) {
			if (Frodo::Instance && Frodo::Instance->TheC64)
				Frodo::Instance->TheC64->ResetAndAutoboot();
			else {
				Frodo::AutoBoot = true;
				
			}
		} else {
			if (Frodo::Instance && Frodo::Instance->TheC64)
				Frodo::Instance->TheC64->Reset();
		}
	}
	
#if !defined(EMU_LITE)
	[g_application launchEmulator];
#endif
}

- (BOOL)uninstall {
	if (isInBundle) {
		NSLog(@"Cannot uninstall game in main bundle");
		return NO;
	}
	
	[[NSFileManager defaultManager] removeItemAtPath:basePath error:nil];
	[[GamePack globalGamePack] removeGameInfo:self];
	return YES;
}

- (void)checkKeyboardLayout:(NSDictionary*)layout {
	if (!layout)
		return;
	
	keyboardLayoutName = [layout valueForKey:@"layout-name"];
	
	NSAssert(keyboardLayoutName, @"layout-name not set for custom keyboard layout");
	
	self.keyboard = layout;
}

#define SetPref( pref, val ) if (_pref_flags.val##Set) thePrefs->pref = _pref_flags.val;

- (void)updatePrefs:(Prefs*)thePrefs {
	SetPref(SkipFrames, skipFrames);
	SetPref(BordersOn, bordersOn);
	SetPref(JoystickSwap, joystickSwap);
	SetPref(Emul1541Proc, emul1541Proc);
}

- (id)valueForUndefinedKey:(NSString *)key {
	return [@"invalid key: " stringByAppendingString:key];
}

- (BOOL)bordersOn {
	return _pref_flags.bordersOn;
}

- (NSString*)coverArtPath {
	if (!cachedCoverArtFullPath) {
		cachedCoverArtFullPath = [[basePath stringByAppendingPathComponent:coverArtPath] retain];
	}
	
	return cachedCoverArtFullPath;
}

- (UIImage*)image {
	return [UIImage imageWithContentsOfFile:self.coverArtPath];
}

- (BOOL)useTrainer {
	NSNumber *n = [[GamePack globalGamePack] getValue:@"useTrainer" forGameId:gameId];
	if (n == nil) return NO;
	return [n boolValue];
}

- (void)setUseTrainer:(BOOL)v {
	NSNumber *n = [NSNumber numberWithBool:v];
	[[GamePack globalGamePack] setValue:n forKey:@"useTrainer" forGameId:gameId];
}

- (NSString*)launchState {
	if (self.useTrainer)
		return self.trainerState;
	
	return self.initialState;
}

#pragma mark private implementation

#define ReadBoolean( val, key ) num = [config valueForKey:key]; if (num) { _pref_flags.val = [num boolValue]; _pref_flags.val##Set = YES; }

- (void)processConfig:(NSDictionary*)config {
	NSNumber *num = [config valueForKey:@"SkipFrames"];
	if (num) {
		_pref_flags.skipFrames		= [num intValue];
		_pref_flags.skipFramesSet	= YES;
	}
	
	ReadBoolean(bordersOn, @"BordersOn");
	ReadBoolean(joystickSwap, @"JoystickSwap");
	ReadBoolean(emul1541Proc, @"Emul1541Proc");
}

- (void)dealloc {
	[cachedCoverArtFullPath release];
	self.coverArtPath = nil;
	self.gameTitle = nil;
	self.gameId = nil;
	self.basePath = nil;
	self.paths = nil;
	self.initialState = nil;
	self.info1Title = nil;
	self.info1 = nil;
	self.info2Title = nil;
	self.info2 = nil;
	self.info3Title = nil;
	self.info3 = nil;
	self.info4Title = nil;
	self.info4 = nil;
	self.description = nil;
	self.previewImages = nil;
	self.keyboard = nil;
	
	[super dealloc];
}

@end

