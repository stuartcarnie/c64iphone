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


#import <Foundation/Foundation.h>

//! Used to group applications
enum tagApplicationType {
	GameApplicationType,
	DemoApplicationType,
	OtherApplicationType
};

#pragma mark -

@interface GameInfo : NSObject {
@private
	NSString				*cachedCoverArtFullPath;
	NSString				*coverArtPath;
	NSString				*gameTitle;
	NSString				*gameId;
	enum tagApplicationType		applicationType;
	
	NSString				*basePath;
	NSArray					*paths;
	NSString				*initialState;
	NSString				*trainerState;
	NSString				*runtimeScript;
	NSString				*info1Title, *info1;
	NSString				*info2Title, *info2;
	NSString				*info3Title, *info3;
	NSString				*info4Title, *info4;
	NSString				*description;
	NSString				*previewImages;
	NSUInteger				version;
	BOOL					autoBoot;
	BOOL					autoSave;
	BOOL					isInBundle;
	BOOL					isInactive;
	
	// preferences overrides
	union {
		struct {
			unsigned int		skipFrames:4;
			BOOL				bordersOn:1;
			BOOL				joystickSwap:1;
			BOOL				emul1541Proc:1;
			
			// indicates if the item is set
			BOOL				skipFramesSet:1;
			BOOL				bordersOnSet:1;
			BOOL				joystickSwapSet:1;
			BOOL				emul1541ProcSet:1;
		};
		unsigned int val;
	} _pref_flags;
	
	NSDictionary			*keyboard;
	NSString				*keyboardLayoutName;
}

@property (nonatomic, retain)	NSString			*coverArtPath;
@property (nonatomic, retain)	NSString			*gameTitle;
@property (nonatomic, retain)	NSString			*gameId;
@property (nonatomic)			enum tagApplicationType	applicationType;
@property (nonatomic, retain)	NSString			*basePath;
// represents the shared images path for this gameInfo
@property (readonly)			NSString			*sharedImagesPath;
@property (nonatomic, retain)	NSArray				*paths;
@property (nonatomic, retain)	NSString			*initialState;
@property (nonatomic, retain)	NSString			*trainerState;
@property (nonatomic, retain)	NSString			*runtimeScript;
@property (nonatomic, retain)	NSString			*info1Title;
@property (nonatomic, retain)	NSString			*info1;
@property (nonatomic, retain)	NSString			*info2Title;
@property (nonatomic, retain)	NSString			*info2;
@property (nonatomic, retain)	NSString			*info3Title;
@property (nonatomic, retain)	NSString			*info3;
@property (nonatomic, retain)	NSString			*info4Title;
@property (nonatomic, retain)	NSString			*info4;
@property (nonatomic, retain)	NSString			*description;
@property (nonatomic, retain)	NSString			*previewImages;
@property (nonatomic)			NSUInteger			version;
@property (nonatomic, readonly)	BOOL				bordersOn;
@property (nonatomic, readonly) BOOL				autoSave;
@property (nonatomic, readonly) BOOL				isInBundle;
@property (nonatomic)			BOOL				isInactive;

@property (nonatomic)			BOOL				useTrainer;
@property (nonatomic, readonly) NSString			*launchState;

@property (nonatomic, retain)	NSDictionary		*keyboard;
@property (nonatomic, readonly)	NSString			*keyboardLayoutName;

- (id)initWithDictionary:(NSDictionary*)dict;
- (id)initWithContentsOfGameInfoFile:(NSString*)gameInfoPath isBundlePath:(BOOL)isBundlePath;
- (void)launchGame;
- (BOOL)uninstall;
- (NSComparisonResult)compare:(GameInfo*)anotherGameInfo;

- (UIImage*)image;

@end
