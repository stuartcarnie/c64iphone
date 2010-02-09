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

//! A brief description of the EMUFileInfo object
/*!
 Represents the base class for an emulator's disk, tape or other ROM image
 */
 
@interface EMUFileInfo : NSObject {
	NSString *path;
}

/*!
 The full path to the image file
 */
@property (nonatomic, retain) NSString *path;

- (id)initFromPath:(NSString*)thePath;
- (NSString*)fileName;

/*!
 Returns the file data
 */
- (NSData*)getFileData;

@end
