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


#import "MMStoreManager.h"
#import "MMProductsRequest.h"
#import "MMProduct.h"
#import "BlocksAdditions.h"
#ifdef _INTERNAL
#import "MMProductInstallController.h"
#else
#import "MMLocalProductInstallController.h"
#endif
#import "GamePack.h"
#import "Reachability.h"

@interface MMStoreManager()
- (MMProduct*)getProductForId:(NSString*)productId;
- (void)completeTransaction:(SKPaymentTransaction*)transaction;
- (void)failedTransaction:(SKPaymentTransaction*)transaction;
- (void)restoreTransaction:(SKPaymentTransaction*)transaction;

- (void)provideContentForProductId:(NSString*)productIdentifier usingTransaction:(SKPaymentTransaction*)transaction;

@end

@implementation MMStoreManager

#pragma mark -
#pragma mark Static members

+ (MMStoreManager*)defaultStore {
	static MMStoreManager* store = nil;
	if (store == nil) {
		store = [MMStoreManager new];
	}
		
	return store;
}

#pragma mark -
#pragma mark Implementation

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_getProductsLoading = NO;
	_getProductsCallbacks = [[NSMutableArray array] retain];
	
	// Attempt to load the product from the App Store, which will trigger any pending downloads.
	[self getAvailableProducts:nil];
	
	return self;
}

- (void)dealloc {
	[_cachedProducts release];
	[_getProductsCallbacks release];
	
	[super dealloc];
}

- (void)getAvailableProducts:(ProductsCallback)block {
	@synchronized(self) {
		if (_cachedProducts) {
			block(_cachedProducts, YES);
			return;
		}
		
		__block ProductsCallback blockCopy = [block copy];
		
		if (_getProductsLoading) {
			[_getProductsCallbacks addObject:blockCopy];
		} else {
			_getProductsLoading = YES;
			[[MMProductsRequest alloc] 
			 initWithBlock:^(NSArray *prods, BOOL succeeded) {
				 if (succeeded) {
					 _cachedProducts = [prods retain];
					 [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
				 }
				 
				 if (blockCopy) {
					 blockCopy(prods, succeeded);
					 [blockCopy release];
				 }

				 // process all callbacks
				 _getProductsLoading = NO;
				 if ([_getProductsCallbacks count] == 0) return;

				 for (ProductsCallback cb in _getProductsCallbacks) {
					 cb(_cachedProducts, succeeded);
				 }
				 [_getProductsCallbacks removeAllObjects];
			 }];			
		}
	}
}

- (void)downloadAllPurchases {
	[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (MMProduct*)getProductForId:(NSString*)productId {
	NSAssert(_cachedProducts != nil, @"cached products list not initialized");
	
	return [_cachedProducts firstUsingBlock:^(id obj) {
		MMProduct* prod = (MMProduct*)obj;
		return [prod.productIdentifier isEqual:productId];
	}];
}

#if TARGET_IPHONE_SIMULATOR

- (void)shouldBuyProduct:(MMProduct*)product {
	[self provideContentForProductId:product.productIdentifier usingTransaction:nil];
}

#else

- (void)shouldBuyProduct:(MMProduct*)product {
	product.installing = YES;
	
	if (product.product) {
		SKPayment *pmt = [SKPayment paymentWithProduct:product.product];
		[[SKPaymentQueue defaultQueue] addPayment:pmt];
		return;
	}
	
	if (product.isFree) {
		[self provideContentForProductId:product.productIdentifier usingTransaction:nil];
	}
}

#endif

#pragma mark -
#pragma mark SKPaymentTransactionObserver implementation

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
	for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
            default:
                break;
        }
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
	
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
	
}

#pragma mark -
#pragma mark transaction processing

- (void)completeTransaction:(SKPaymentTransaction*)transaction {
    [self provideContentForProductId:transaction.payment.productIdentifier usingTransaction:transaction];
}

- (void)failedTransaction:(SKPaymentTransaction*)transaction {
	MMProduct *product = [self getProductForId:transaction.payment.productIdentifier];
	product.installing = NO;
	
	if (transaction.error.code != SKErrorPaymentCancelled) {
        // Optionally, display an error here.
    }
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)restoreTransaction:(SKPaymentTransaction*)transaction {
    [self provideContentForProductId:transaction.originalTransaction.payment.productIdentifier usingTransaction:transaction];
}

- (void)provideContentForProductId:(NSString*)productIdentifier usingTransaction:(SKPaymentTransaction*)transaction {
	MMProduct *product = [self getProductForId:productIdentifier];
#ifdef _INTERNAL
	MMProductInstallController *ctl = [[MMProductInstallController alloc] initWithProduct:product transaction:transaction];
#else
	MMLocalProductInstallController *ctl = [[MMLocalProductInstallController alloc] initWithProduct:product transaction:transaction];
#endif
	[ctl install];
}


@end
