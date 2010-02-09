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


#import "MMProductsRequest.h"
#import "MMDownloadManager.h"
#import "JSON.h"
#import "BlocksAdditions.h"
#import "MMProduct.h"

@interface MMProductsRequest()

- (void)processProductsResult;

@property (nonatomic, copy)		ProductsCallback productsCallback;
@property (nonatomic, retain)	NSDictionary* mmProducts;

@end

#ifdef _DISTRIBUTION
 #define URL	@"http://c64.manomio.com/index.php/api_v1/inAppPurchases/"
#else
 #define URL	@"http://c64.manomio.com/index.php/api_v1/inAppPurchasesSandbox_2/"
#endif

@implementation MMProductsRequest

- (id)initWithBlock:(ProductsCallback)block {
	self = [super init];
	if (!self) return nil;
	
	self.productsCallback = block;
	
	// firstly, initiate the download of the list of products available from manomio.com
	MMDownloadManager *mgr = [MMDownloadManager defaultManager];
	[mgr downloadURL:[NSURL URLWithString:URL]
			 succeed:^(id<MMDownloadResponse> data) {
				 NSArray *results = [data.asString JSONValue];
				 
				 NSMutableDictionary *products = [NSMutableDictionary dictionaryWithCapacity:[results count]];
				 for (NSArray* result in results) {
					 [products setValue:[result objectAtIndex:1] forKey:[result objectAtIndex:0]];
				 }
				 self.mmProducts = products;
				 
				 [self processProductsResult];
			 } 
				fail:^(NSError* error) {
					_productsCallback(nil, NO);
					
					[self autorelease];
				}];
	
	return self;
}

- (void)dealloc {
	self.productsCallback = nil;
	self.mmProducts = nil;
	
	[super dealloc];
}

#if TARGET_IPHONE_SIMULATOR

- (void)processProductsResult {
	NSArray *validProducts = [_mmProducts allKeys];
	NSMutableArray *pl = [NSMutableArray arrayWithCapacity:[validProducts count]];
	
    for (NSString *prodId in validProducts) {
		NSMutableDictionary *prodDict = [_mmProducts objectForKey:prodId];
		[prodDict setObject:prodId forKey:kProductIdentifierKey];
		MMProduct *mmprod = [[MMProduct alloc] initWithDictionary:prodDict andProduct:nil];
		[pl addObject:mmprod];
		[mmprod release];
	}
	
	_productsCallback(pl, YES);

	[self autorelease];
}

#else

- (void)processProductsResult {
	SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:[_mmProducts allKeys]]];
	request.delegate = self;
	[request start];
}

#endif

#pragma mark -
#pragma mark SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
	NSArray *validProducts = response.products;
	NSArray *invalidProductsIds = response.invalidProductIdentifiers;
	
	NSMutableArray *pl = [NSMutableArray arrayWithCapacity:[validProducts count] + [invalidProductsIds count]];
	
    for (SKProduct *prod in validProducts) {
		NSDictionary *prodDict = [_mmProducts objectForKey:prod.productIdentifier];
		MMProduct *mmprod = [[MMProduct alloc] initWithDictionary:prodDict andProduct:prod];
		[pl addObject:mmprod];
		[mmprod release];
	}
	
	// add invalid product IDs
	for (NSString *prodId in invalidProductsIds) {
		NSMutableDictionary *prodDict = [_mmProducts objectForKey:prodId];
		[prodDict setObject:prodId forKey:kProductIdentifierKey];
		MMProduct *mmprod = [[MMProduct alloc] initWithDictionary:prodDict andProduct:nil];
		[pl addObject:mmprod];
		[mmprod release];
	}
		
	_productsCallback(pl, YES);
	
	// cleanup
	[request autorelease];
	[self autorelease];
}

#pragma mark -
#pragma mark Properties

@synthesize productsCallback = _productsCallback;
@synthesize mmProducts = _mmProducts;

@end
