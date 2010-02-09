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
#import "MMLocalProductInstallController.h"
#import "MMProductInstallController.h"
#import "MMProduct.h"
#import "GameInstaller.h"
#import "GameZipExtracter.h"
#import "BlocksAdditions.h"

@interface MMLocalProductInstallController()
- (BOOL)sendRequest;

// extraction and installation
- (BOOL)extractDownload:(NSData*)data;

- (void)installTask;
- (void)completeTask;
- (void)updateVersion;
- (void)setState:(enum tagProductInstallState)newState;

@end

@implementation MMLocalProductInstallController

- (id)initWithProduct:(MMProduct*)product
		  transaction:(SKPaymentTransaction*)transaction {
	self = [super init];
	if (self == nil) return nil;
	
	_mmProduct = [product retain];
	_transaction = [transaction retain];
	_state = MMProductInstallStateIdle;
	
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
	BOOL fileLoded = [self sendRequest];
	if (fileLoded) {	
		[self setState:MMProductInstallStateExtracting];
		BOOL res = [self extractDownload:_downloadData];
		
		
		[self setState:MMProductInstallStateIdle];
		
		if (res == YES) {
			if (_transaction) {
				// Remove the transaction from the payment queue.
				[[SKPaymentQueue defaultQueue] finishTransaction:_transaction];
			}
			[self performSelectorOnMainThread:@selector(completeTask) withObject:nil waitUntilDone:NO];
		}
	} else {
		[self performSelectorOnMainThread:@selector(updateVersion) withObject:nil waitUntilDone:NO];
	}

	[pool release];
	
	// TODO: probably won't release this 
	[self release];
}

- (void)completeTask {
	[[[[UIAlertView alloc] initWithTitle:@"Install complete" message:@"Your games are ready to play!" 
								delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease] show];
}

- (void)updateVersion {
	[[[[UIAlertView alloc] initWithTitle:@"Install error" message:@"Please download the latest version of C64 to install this game" 
								delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease] show];
}

- (void)setState:(enum tagProductInstallState)newState {
	_state = newState;
	if (_delegate) {
		[_delegate stateChanged:newState];
	}
}

- (float)downloadPercent {
	return 100.0;
}

#pragma mark -
#pragma mark Load file

- (BOOL)sendRequest {
	NSString* packFile = [[NSBundle mainBundle] pathForResource:_mmProduct.productIdentifier ofType:@"zip"];
	id mgr = [NSFileManager defaultManager];
	if ([mgr fileExistsAtPath:packFile]) {
		_downloadData = [[NSData dataWithContentsOfFile:packFile] retain];
		return YES;
	}
	
	return NO;
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
