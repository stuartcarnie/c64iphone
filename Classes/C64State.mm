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

#import "C64State.h"
#import "Prefs.h"

@implementation C64State

@synthesize part1, part2;

- (id)init {
	[super init];
	
	part1 = (uint8*)malloc(SNAPSHOT_SIZE_1);
	part2 = (uint8*)malloc(SNAPSHOT_SIZE_2);
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeBytes:part1 length:SNAPSHOT_SIZE_1 forKey:@"par1"];
	[encoder encodeBytes:part2 length:SNAPSHOT_SIZE_2 forKey:@"par2"];
}

- (id)initWithCoder:(NSCoder *)decoder {
	self = [self init];
	
	NSUInteger len;
	uint8* buf = (uint8*)[decoder decodeBytesForKey:@"par1" returnedLength:&len];
	assert(len == SNAPSHOT_SIZE_1);
	memcpy(part1, buf, len);
	
	buf = (uint8*)[decoder decodeBytesForKey:@"par2" returnedLength:&len];
	assert(len == SNAPSHOT_SIZE_2);
	memcpy(part2, buf, len);
	
	return self;
}

- (void)dealloc {
	free(part1);
	free(part2);
	[super dealloc];
}

@end
