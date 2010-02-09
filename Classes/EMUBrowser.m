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

#import "EMUBrowser.h"
#import "EMUFileInfo.h"

@interface EMUBrowser()

- (NSMutableArray*)getFilesForPath:(NSString *)thePath;

@end



@implementation EMUBrowser

@synthesize basePath, extensions;

- (id)initWithBasePath:(NSString *)theBasePath {
	NSAssert(theBasePath != nil, @"theBasePath cannot be nil");

	self.extensions = [NSArray arrayWithObjects:@"d64", @"D64", @"t64", @"T64", nil];
	self.basePath = theBasePath;
	
	return [super init];
}

- (NSMutableArray*)getFiles {
	NSMutableArray* list = [[NSMutableArray alloc] init];
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	NSString *romsPath = [documentsDirectory stringByAppendingPathComponent:@"roms"];
	[list addObjectsFromArray:[self getFilesForPath:romsPath]];
	
	[list addObjectsFromArray:[self getFilesForPath:[[NSBundle mainBundle] bundlePath]]];
	
	return [list autorelease];
}

- (NSMutableArray*)getFilesForPath:(NSString *)thePath {
	NSMutableArray* list = [[NSMutableArray alloc] init];
	
	NSDirectoryEnumerator *direnum = [[NSFileManager defaultManager] enumeratorAtPath:thePath];
	NSArray *files = [[direnum allObjects] pathsMatchingExtensions:extensions];
	for (NSString *pname in files) {
		id obj = [[EMUFileInfo alloc] initFromPath:[thePath stringByAppendingPathComponent:pname]];
		[list addObject:obj];
		[obj release];
	}
	return [list autorelease];
}

-(void)dealloc {
	self.extensions = nil;
	self.basePath = nil;
	[super dealloc];
}

@end
