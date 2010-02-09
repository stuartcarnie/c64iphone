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


#import <StoreKit/StoreKit.h>

#import "debug.h"
#import "MMProductInstallController.h"
#import "MMProduct.h"
#import "GameInstaller.h"
#import "GameZipExtracter.h"
#import "BlocksAdditions.h"

@interface MMProductInstallController()
// downloading
- (void)sendRequest;
- (NSString *)encode:(const uint8_t *)input length:(NSInteger)length;

// extraction and installation
- (BOOL)extractDownload:(NSData*)data;

- (void)installTask;
- (void)completeTask;
- (void)setState:(enum tagProductInstallState)newState;

@end

@implementation MMProductInstallController

- (id)initWithProduct:(MMProduct*)product
		  transaction:(SKPaymentTransaction*)transaction {
	self = [super init];
	if (self == nil) return nil;
	
	_mmProduct = [product retain];
	_transaction = [transaction retain];
	_state = MMProductInstallStateIdle;
	_downloadData = [NSMutableData new];
	
	return self;
}

- (void)dealloc {
	_mmProduct.installing = NO;
	[_downloadData release];
	[_mmProduct release];
	[_transaction release];

	[super dealloc];
}

- (void)install {
	_mmProduct.downloadPercent = 0.0;
	_mmProduct.installing = YES;
	[self performSelectorInBackground:@selector(installTask) withObject:nil];
}

- (void)installTask {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	
	[self setState:MMProductInstallStateDownloading];
	[self sendRequest];
	
	[self setState:MMProductInstallStateExtracting];
	BOOL res = [self extractDownload:_downloadData];
	
	[pool release];
			
	[self setState:MMProductInstallStateIdle];
	
	if (res == YES) {
		if (_transaction) {
			// Remove the transaction from the payment queue.
			[[SKPaymentQueue defaultQueue] finishTransaction:_transaction];
		}
		[self performSelectorOnMainThread:@selector(completeTask) withObject:nil waitUntilDone:NO];
	}

	// TODO: probably won't release this 
	[self release];
}

- (void)completeTask {
	[[[[UIAlertView alloc] initWithTitle:@"Download complete" message:@"Your games are ready to play!" 
								delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease] show];
}

- (void)setState:(enum tagProductInstallState)newState {
	_state = newState;
	if (_delegate) {
		[_delegate stateChanged:newState];
	}
}

- (float)downloadPercent {
	float pct = (float)[_downloadData length] / (float)_expectedDownloadSize;
	return pct;
}

#pragma mark -
#pragma mark product server download

enum {
	kDownloadStateIdle,
	kDownloadStateStarting,
	kDownloadStateInProgress,
	
	// end states
	kDownloadStateSucceeded,
	kDownloadStateError,
	
	kDownloadStateFinished = kDownloadStateSucceeded
};

#if TARGET_IPHONE_SIMULATOR
#define BASE_URL @"http://c64.manomio.com/index.php/api_v1/requestProductSimulator/%@"
#else
#define BASE_URL @"http://c64.manomio.com/index.php/api_v1/requestProduct/%@"
#endif
- (void)sendRequest {
	_expectedDownloadSize = 0;
	
    NSURL *urlForValidation = [NSURL URLWithString:[NSString stringWithFormat:BASE_URL, _mmProduct.productIdentifier]];	
    NSMutableURLRequest *validationRequest = [[NSMutableURLRequest alloc] initWithURL:urlForValidation];
    [validationRequest setHTTPMethod:@"POST"];
	
	if (_transaction) {		
		NSString *jsonObjectString = [self encode:(uint8_t *)_transaction.transactionReceipt.bytes length:_transaction.transactionReceipt.length];
		[validationRequest setHTTPBody:[jsonObjectString dataUsingEncoding:NSASCIIStringEncoding]];
	}
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:validationRequest delegate:self];
	
	_downloadState = kDownloadStateStarting;
	[connection start];
	// wait whilst download proceeds
	while (CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.5, NO) == kCFRunLoopRunTimedOut && _downloadState < kDownloadStateFinished);
	
	[connection release];
}

#pragma mark -
#pragma mark NSURLConnection delegate messages

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	NSLog(@"%@", [error localizedDescription]);
	_downloadState = kDownloadStateError;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	_expectedDownloadSize = [response expectedContentLength];
	_downloadState = kDownloadStateInProgress;
	DLog(@"expected length: %d", _expectedDownloadSize);
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
	// no caching
	return nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[_downloadData appendData:data];
	_mmProduct.downloadPercent = self.downloadPercent;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	DLog(@"data length=%d", [_downloadData length]);
	_downloadState = kDownloadStateSucceeded;
	_mmProduct.downloadPercent = 1.0;
}

#pragma mark -
#pragma mark helpers

- (NSString *)encode:(const uint8_t *)input length:(NSInteger)length {
    static char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
	
    NSMutableData *data = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
    uint8_t *output = (uint8_t *)data.mutableBytes;
	
    for (NSInteger i = 0; i < length; i += 3) {
        NSInteger value = 0;
        for (NSInteger j = i; j < (i + 3); j++) {
			value <<= 8;
			
			if (j < length) {
				value |= (0xFF & input[j]);
			}
        }
		
        NSInteger index = (i / 3) * 4;
        output[index + 0] =                    table[(value >> 18) & 0x3F];
        output[index + 1] =                    table[(value >> 12) & 0x3F];
        output[index + 2] = (i + 1) < length ? table[(value >> 6)  & 0x3F] : '=';
        output[index + 3] = (i + 2) < length ? table[(value >> 0)  & 0x3F] : '=';
    }
	
    return [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
}

#pragma mark -
#pragma mark product extraction and installation

- (BOOL)extractDownload:(NSData*)data {
	if (!data || [data length] == 0)
		return NO;
	
	NSArray* files = [GameZipExtracter extractArchiveFromData:data];
	NSString* sigFile = [files firstUsingBlock:^(id obj) {
		return [obj hasSuffix:@"sign"];
	}];
	NSString* packFile = [files firstUsingBlock:^(id obj) {
		return [obj hasSuffix:@"zip"];
	}];
	
	if (!sigFile && !packFile)
		return NO;
	
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	
	NSData *packData = [NSData dataWithContentsOfFile:packFile];
	NSData *sigData = [NSData dataWithContentsOfFile:sigFile];
	
	[self setState:MMProductInstallStateInstalling];
	BOOL res = [GameInstaller installPackWithData:packData andSignature:sigData andProgressDelegate:nil];
	DLog(@"Successfully extracted game pack: %@", res ? @"YES" : @"NO");
	
	[pool release];
	
	return res;
}

#pragma mark -
#pragma mark synthesized properties

@synthesize state = _state;
@synthesize delegate = _delegate;

@end
