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


#import "MMProductStatusRequest.h"
#import "MMDownloadManager.h"
#import "JSON.h"
#import "BlocksAdditions.h"


@interface MMProductStatusRequest()

@property (nonatomic, copy)		ProductsCallback productsCallback;
@property (nonatomic, copy)		void (^failBlock)(NSError* error);

@end

@implementation MMProductStatusRequest

- (id)initWithSuccessBlock:(ProductsCallback)block andFailBlock:(void(^)(NSError* error))failBlock {
	self = [super init];
	if (!self) return nil;
	
	self.productsCallback = block;
	self.failBlock = failBlock;
	
	MMDownloadManager *mgr = [MMDownloadManager defaultManager];
	[mgr downloadURL:[NSURL URLWithString:@"http://c64.manomio.com/index.php/api_v1/gameStatus/"] 
			 succeed:^(id<MMDownloadResponse> data) {
				 [self autorelease];
				 NSArray *results = [data.asString JSONValue];
				 self.productsCallback(results, YES);
			 } 
				fail:^(NSError* error) {
					[self autorelease];
					if (_failBlock)
						_failBlock(error);
				}];
	
	return self;
	
}

- (void)dealloc {
	self.productsCallback = nil;
	
	[super dealloc];
}

@synthesize productsCallback=_productsCallback;
@synthesize failBlock=_failBlock;

@end