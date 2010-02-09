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
#import "MMProductInstall.h"

@class SKPaymentTransaction, MMProduct;

/*! Installs products from the local app bundle only
 */
@interface MMLocalProductInstallController : NSObject {
	MMProduct						*_mmProduct;
	SKPaymentTransaction			*_transaction;
	enum tagProductInstallState		_state;
	id<MMProductInstallDelegate>	_delegate;
	
	NSMutableData					*_downloadData;
}

@property (nonatomic, readonly) float downloadPercent;
@property (nonatomic, readonly) enum tagProductInstallState state;
@property (nonatomic, assign) id<MMProductInstallDelegate> delegate;

- (id)initWithProduct:(MMProduct*)product
		  transaction:(SKPaymentTransaction*)transaction;

- (void)install;

@end
