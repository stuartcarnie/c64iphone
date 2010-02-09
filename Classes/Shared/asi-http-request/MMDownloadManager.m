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

#import "MMDownloadManager.h"
#import "ASINetworkQueue.h"
#import "ASIHTTPRequest.h"
#import <PLBlocks/Block.h>

@interface MMRequest : ASIHTTPRequest<MMDownloadResponse> {
	SuccessCallback			_succeedBlock;
	ErrorCallback			_failBlock;
}

- (id)initWithURL:(NSURL *)newURL successBlock:(SuccessCallback)successBlock failBlock:(ErrorCallback)failBlock;
- (void)doSucceedBlock;
- (void)doFailBlock;

@property (nonatomic, copy)		SuccessCallback succeedBlock;
@property (nonatomic, copy)		ErrorCallback failBlock;

@end


@implementation MMDownloadManager

+ (MMDownloadManager*)defaultManager {
	static MMDownloadManager* g_manager = nil;
	if (!g_manager) {
		g_manager = [MMDownloadManager new];
	}
	
	return g_manager;
}

#pragma mark -
#pragma mark implementation

- (id)init {
	self = [super init];
	if (!self) return nil;
	
	_networkQueue = [[ASINetworkQueue queue] retain];
	
	return self;
}

- (void)downloadURL:(NSURL*)url succeed:(SuccessCallback)succeedBlock fail:(ErrorCallback)failBlock {
	MMRequest *req = [[MMRequest alloc] initWithURL:url successBlock:succeedBlock failBlock:failBlock];
	
	[_networkQueue addOperation:req];
	[req release];
	
	[_networkQueue go];
}



@end

@implementation MMRequest

- (id)initWithURL:(NSURL *)newURL successBlock:(SuccessCallback)successBlock failBlock:(ErrorCallback)failBlock {
	self = [super initWithURL:newURL];
	if (!self) return nil;
	
	self.succeedBlock = successBlock;
	self.failBlock = failBlock;
	
	return self;
}

- (void)requestFinished {
	if (_succeedBlock) {
		[self performSelectorOnMainThread:@selector(doSucceedBlock) withObject:nil waitUntilDone:NO];
	}
	
	[super requestFinished];
}

- (void)failWithError:(NSError *)theError {
	if (_failBlock) {
		[self performSelectorOnMainThread:@selector(doFailBlock) withObject:nil waitUntilDone:NO];
	}
	
	[super failWithError:theError];
}

- (void)doSucceedBlock {
	_succeedBlock(self);
}

- (void)doFailBlock {
	_failBlock(self.error);
}

- (void)dealloc {
	self.succeedBlock = nil;
	self.failBlock = nil;
	
	[super dealloc];
}

#pragma mark -
#pragma mark MMDownloadResponse protocol

- (NSString*)asString {
	return [self responseString];
}

- (NSData*)asData {
	return [self responseData];
}

@synthesize succeedBlock = _succeedBlock;
@synthesize failBlock = _failBlock;

@end