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


#pragma mark -
#pragma mark NSArray

/** Additions for using blocks
 */
@interface NSArray(BlocksAdditions)

- (NSArray*)map:(id (^)(id obj))block;
- (id)firstUsingBlock:(BOOL(^)(id obj))block;

@end

@interface UIImage(BlocksAdditions)

+ (void)imageWithContentsOfFile:(NSString*)path whenReadyBlock:(void(^)(UIImage* image))whenReadyBlock;

@end

typedef void (^BasicBlock)(void);

void RunInBackground(BasicBlock block);
void RunOnMainThread(BOOL wait, BasicBlock block);
void RunOnThread(NSThread *thread, BOOL wait, BasicBlock block);
void RunAfterDelay(NSTimeInterval delay, BasicBlock block);
void WithAutoreleasePool(BasicBlock block);
