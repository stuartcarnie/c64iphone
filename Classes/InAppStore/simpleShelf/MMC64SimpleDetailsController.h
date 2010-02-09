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


#import <UIKit/UIKit.h>

@class MMProduct, EGOImageView, GameDetailsController;

@interface MMC64SimpleDetailsController : UIViewController {
	MMProduct*					_product;
	EGOImageView*				_coverArtImage;
	UIButton*					_buyButton;
	UILabel*					_productTitle;
	UILabel*					_productDescription;
	UILabel*					_publisherNotes;
	UILabel*					_price;
	
	GameDetailsController*		_moreDetailsController;
}

@property (nonatomic, retain) IBOutlet EGOImageView* coverArtImage;
@property (nonatomic, retain) IBOutlet UIButton* buyButton;
@property (nonatomic, retain) IBOutlet UILabel* productTitle;
@property (nonatomic, retain) IBOutlet UILabel* productDescription;
@property (nonatomic, retain) IBOutlet UILabel* publisherNotes;
@property (nonatomic, retain) IBOutlet UILabel* price;

- (void)setProduct:(MMProduct*)product;

- (IBAction)buyProduct:(id)sender;
- (IBAction)moreDetails:(id)sender;
- (IBAction)closeView:(id)sender;

@end
