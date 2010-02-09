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


#import "MMProduct.h"
#import <StoreKit/StoreKit.h>

NSString* kProductIdentifierKey = @"product_id";
NSString* kCoverImageKey = @"cover_image";
NSString* kTitleKey = @"title";
NSString* kDescriptionKey = @"description";
NSString* kIsFree = @"is_free";
NSString* kStatus = @"status";
NSString* kPublisherNotes = @"publisher_notes";

@interface MMProduct()

@property (nonatomic, retain) NSDictionary*	mmData;

@end

@implementation MMProduct

- (id)initWithDictionary:(NSDictionary*)dict andProduct:(SKProduct*)product {
	self = [super init];
	if (!self) return nil;
	
	self.mmData = dict;
	_product = [product retain];
	
	return self;
}

- (void)dealloc {
	[_product release];
	self.mmData = nil;
	
	[super dealloc];
}

- (NSString*)imagePath {
	return [_mmData objectForKey:kCoverImageKey];
}

- (NSString*)productIdentifier {
	if (_product)
		return _product.productIdentifier;
	
	return [_mmData objectForKey:kProductIdentifierKey];
}

- (NSString*)title {
	if (_product)
		return _product.localizedTitle;
	
	return [_mmData objectForKey:kTitleKey];
}

- (NSString*)productDescription {
	if (_product)
		return _product.localizedDescription;
	
	return [_mmData objectForKey:kDescriptionKey];
}

- (NSString*)status {
	return [_mmData objectForKey:kStatus];
}

- (NSString*)publisherNotes {
	NSString* str = [_mmData objectForKey:kPublisherNotes];
	return [str stringByReplacingOccurrencesOfString:@"<br/>" withString:@"\n"];
}

- (BOOL)isFree {
	if (_product)
		return NO;
	
	return [[_mmData objectForKey:kIsFree] isEqual:@"Yes"];
}

- (NSString*)description {
	return [_mmData objectForKey:kTitleKey];
}

#pragma mark -
#pragma mark identity and equality methods

- (NSUInteger)hash {
	return [self.productIdentifier hash];
}

- (BOOL)isEqual:(id)object {
	if (self == object) return YES;
	
	if ([object isKindOfClass:[MMProduct class]]) {
		MMProduct *otherProduct = (MMProduct*)object;
		return [self.productIdentifier isEqualToString:otherProduct.productIdentifier];
	}
	
	return NO;
}

#pragma mark -
#pragma mark synthesized properties

@synthesize mmData = _mmData;
@synthesize product = _product;
@synthesize installing = _installing;
@synthesize downloadPercent = _downloadPercent;

@end
