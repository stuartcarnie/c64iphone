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

#import "GameZipExtracter.h"
#import "NSDataBase64.h"
#import "LiteUnzip.h"
#include <fcntl.h>
#import "MMDigitalVerification.h"

@implementation GameZipExtracter

@synthesize basePath, packs, images;

#define cStringToNSStringNoCopy(x)	[[NSString alloc] initWithBytesNoCopy:x length:strlen(x) encoding:NSASCIIStringEncoding freeWhenDone:NO]
#define cStringToNSString(x)		[[NSString alloc] initWithBytes:x length:strlen(x) encoding:NSASCIIStringEncoding]

-(id)initWithData:(NSData*)data andSignature:(NSData*)signature {
	self = [super init];

	packs = [[NSMutableDictionary alloc] init];
	
	PKIFileVerification *pki = [MMDigitalVerification sharedManomioPublicKey];	
	BOOL pki_result = [pki verifyData:data withSignature:signature];
	if (!pki_result) {
		[[[[UIAlertView alloc] initWithTitle:@"Invalid Data" 
									 message:@"Unable to verify install data." 
									delegate:nil 
						   cancelButtonTitle:@"OK" 
						   otherButtonTitles:nil] autorelease] show];
		return self;
	}
	
	HUNZIP huz;
	DWORD result = UnzipOpenBuffer(&huz, (void*)[data bytes], [data length], NULL);
	NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"installXXXXXX"];
	char pathChars[PATH_MAX + 1];
	pathChars[PATH_MAX] = 0;
	[tempPath getFileSystemRepresentation:pathChars maxLength:(PATH_MAX + 1)];
	mkdtemp(pathChars);
	basePath = cStringToNSString(pathChars);
	
	ZIPENTRY	ze;
	DWORD		numitems;
	
	// Find out how many items are in the archive.
	ze.Index = (DWORD)-1;
	if ((UnzipGetItem(huz, &ze))) goto bad2;
	numitems = ze.Index;

	NSMutableArray *files;
	// Unzip each item, using the name stored (in the zip) for that item.
	for (ze.Index = 0; ze.Index < numitems; ze.Index++) {		
		if (UnzipGetItem(huz, &ze))
			break;

		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

		NSString *name = cStringToNSStringNoCopy(ze.Name);
		NSString *fileName = [basePath stringByAppendingPathComponent:name];

		if (ze.Attributes & S_IFDIR) {
			NSString *filePath = [name substringToIndex:[name length] - 1];
			files = [[NSMutableArray alloc] init];
			[packs setObject:files forKey:filePath];
			[files release];
		} else {
			NSString *filePath = [name stringByDeletingLastPathComponent];
			files = [packs objectForKey:filePath];
			if (files)
				[files addObject:fileName];
			else
				NSLog(@"Invalid archive path - not found in dictionary, %@", filePath);
		}
		UnzipItemToFile(huz, [fileName cStringUsingEncoding:[NSString defaultCStringEncoding]], &ze);
		[name release];
		[pool release];
	}
	
	self.images = [packs objectForKey:@"images"];
	if (images) {
		[packs removeObjectForKey:@"images"];
	}
	
bad2:
	UnzipClose(huz);
		
	return self;
}

-(NSString*)findFileNamed:(NSString*)fileName inArray:(NSArray*)theArray {
	for (NSString *n in theArray) {
		if ([n hasSuffix:fileName])
			return n;
	}
	
	return nil;
}

- (void)dealloc {
	if (self.basePath) {
		[[NSFileManager defaultManager] removeItemAtPath:self.basePath error:nil];
		[basePath release];
	}
	[packs release];
	[images release];

	[super dealloc];
}

#pragma mark -
#pragma mark static helpers

+ (NSArray*)extractArchiveFromData:(NSData*)data {
	NSMutableArray* files = nil;
	HUNZIP huz;
	DWORD result = UnzipOpenBuffer(&huz, (void*)[data bytes], [data length], NULL);
	@try {
		NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"installXXXXXX"];
		char pathChars[PATH_MAX + 1];
		pathChars[PATH_MAX] = 0;
		[tempPath getFileSystemRepresentation:pathChars maxLength:(PATH_MAX + 1)];
		mkdtemp(pathChars);
		NSString* basePath = cStringToNSString(pathChars);
		
		ZIPENTRY	ze;
		DWORD		numitems;
		
		// Find out how many items are in the archive.
		ze.Index = (DWORD)-1;
		if ((UnzipGetItem(huz, &ze))) 
			return nil;
		
		numitems = ze.Index;
		files = [NSMutableArray arrayWithCapacity:numitems];
		
		// Unzip each item, using the name stored (in the zip) for that item.
		for (ze.Index = 0; ze.Index < numitems; ze.Index++) {		
			if (UnzipGetItem(huz, &ze))
				break;
			
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			NSString *name = cStringToNSStringNoCopy(ze.Name);
			NSString *fileName = [basePath stringByAppendingPathComponent:name];
			[files addObject:fileName];
			UnzipItemToFile(huz, [fileName cStringUsingEncoding:[NSString defaultCStringEncoding]], &ze);
			[name release];
			[pool release];
		}
	}
	@finally {
		UnzipClose(huz);
	}
	return files;
}

@end
