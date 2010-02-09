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


#import "BlocksAdditions.h"

#pragma mark -
@implementation NSArray(BlocksAdditions)

- (NSArray*)map:(id (^)(id obj))block {
	NSMutableArray *new = [NSMutableArray array];
	for(id obj in self)
	{
		id newObj = block(obj);
		[new addObject: newObj ? newObj : [NSNull null]];
	}
	return new;
}

- (id)firstUsingBlock:(BOOL(^)(id obj))block {
	for(id obj in self) {
		if (block(obj))
			return obj;
	}
	return nil;
}

@end

#pragma mark -

@implementation UIImage(BlocksAdditions)

+ (void)imageWithContentsOfFile:(NSString*)path whenReadyBlock:(void(^)(UIImage* image))whenReadyBlock {
	RunInBackground(^{
		[NSThread setThreadPriority:0.1];
		
		WithAutoreleasePool(^{
			NSData *data = [NSData dataWithContentsOfFile:path];
			UIImage* image = [UIImage imageWithData:data];
			RunOnMainThread(NO, ^{ 
				whenReadyBlock(image);
			});
		});
	});
}

@end

@implementation NSObject (BlocksAdditions)
 
- (void)my_callBlock {
	void (^block)(void) = (id)self;
	block();
}
 
- (void)my_callBlockWithObject: (id)obj {
	void (^block)(id obj) = (id)self;
	block(obj);
}
 
@end
 
void RunInBackground(BasicBlock block) {
	[NSThread detachNewThreadSelector: @selector(my_callBlock) toTarget: [[block copy] autorelease] withObject: nil];
}
 
void RunOnMainThread(BOOL wait, BasicBlock block) {
	[[[block copy] autorelease] performSelectorOnMainThread: @selector(my_callBlock) withObject: nil waitUntilDone: wait];
}
 
void RunOnThread(NSThread *thread, BOOL wait, BasicBlock block) {
	[[[block copy] autorelease] performSelector: @selector(my_callBlock) onThread: thread withObject: nil waitUntilDone: wait];
}
 
void RunAfterDelay(NSTimeInterval delay, BasicBlock block) {
	[[[block copy] autorelease] performSelector: @selector(my_callBlock) withObject: nil afterDelay: delay];
}
 
void WithAutoreleasePool(BasicBlock block) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	block();
	[pool release];
}
