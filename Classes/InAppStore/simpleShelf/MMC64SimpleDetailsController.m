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


#import "MMC64SimpleDetailsController.h"
#import "MMProduct.h"
#import "EGOImageView.h"
#import "MMStoreManager.h"
#import "GameDetailsController.h"

@interface MMC64SimpleDetailsController()

@property (nonatomic, retain) GameDetailsController* moreDetailsController;

@end

@implementation MMC64SimpleDetailsController

/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
}
*/

- (void)dealloc {
	self.coverArtImage = nil;
	self.buyButton = nil;
	self.productTitle = nil;
	self.productDescription = nil;
	self.publisherNotes = nil;
	self.price = nil;

	self.moreDetailsController = nil;
    [super dealloc];
}

- (void)updatePrice {
	if (_product.product) {
		// TODO: add shared number formatter
		NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
		[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
		[numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
		[numberFormatter setLocale:_product.product.priceLocale];
		NSString *formattedString = [numberFormatter stringFromNumber:_product.product.price];
		[numberFormatter release];
		
		[_price setText:formattedString];		
	} else {
		[_price setText:[NSString string]];
	}
}

void resizeLabel(UILabel *l, int maxHeight, int maxLines) {
	CGRect bounds = CGRectMake(0, 0, l.bounds.size.width, maxHeight);
    CGRect newRect = [l textRectForBounds:bounds limitedToNumberOfLines:maxLines];
    // reset the height
    CGRect f = l.frame;
    f.size.height = newRect.size.height;
    l.frame = f;
}

- (void)viewWillAppear:(BOOL)animated {
	_coverArtImage.imageURL = [NSURL URLWithString:_product.imagePath];
	_productTitle.text = _product.title;
	_productDescription.text = _product.productDescription;
	resizeLabel(_productDescription, 80, 4);
	
	_publisherNotes.text = _product.publisherNotes;
	resizeLabel(_publisherNotes, 80, 4);
		
	[self updatePrice];
}

- (void)setProduct:(MMProduct*)product {
	_product = product;
}

- (IBAction)buyProduct:(id)sender {
	[[MMStoreManager defaultStore] shouldBuyProduct:_product];
	[self closeView:sender];
}

- (IBAction)closeView:(id)sender {
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.5];
	[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:self.navigationController.view cache:YES];
	[self.navigationController popViewControllerAnimated:NO];
	[UIView commitAnimations];
}

- (IBAction)moreDetails:(id)sender {
	self.moreDetailsController.gameId = _product.productIdentifier;
	[self.navigationController pushViewController:self.moreDetailsController animated:YES];
}

- (GameDetailsController*)moreDetailsController {
	if (!_moreDetailsController)
		_moreDetailsController = [[GameDetailsController alloc] initWithGameId:_product.productIdentifier isShopView:YES];
	return _moreDetailsController;
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
	self.moreDetailsController = nil;
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	self.moreDetailsController = nil;
}

@synthesize coverArtImage=_coverArtImage;
@synthesize buyButton=_buyButton;
@synthesize productTitle=_productTitle;
@synthesize productDescription=_productDescription;
@synthesize price=_price;
@synthesize publisherNotes=_publisherNotes;
@synthesize moreDetailsController=_moreDetailsController;

@end
