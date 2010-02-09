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


#import "MMC64SimpleShelfCell.h"
#import "MMProduct.h"
#import "EGOImageButton.h"

@interface MMC64SimpleShelfCell()

- (void)unregisterForChangeNotification;
- (void)updateProductInstalling:(MMProduct*)p index:(NSInteger)index;;

@end

@implementation MMC64SimpleShelfCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
    }
    return self;
}

- (void)dealloc {
    [super dealloc];
}

#define kImageTag		1000
#define kLabelTag		1010
#define kProgressTag	1020
#define kIndexUnknown	-1

- (void)setProductArray:(NSArray*)products {
	_products = products;
	int i = 0;
	for (MMProduct* p in products) {
		[p addObserver:self forKeyPath:@"installing" options:NSKeyValueObservingOptionNew context:nil];
		[p addObserver:self forKeyPath:@"downloadPercent" options:NSKeyValueObservingOptionNew context:nil];
		
		[self updateProductInstalling:p index:i];
		
		EGOImageButton *v = (EGOImageButton *)[self viewWithTag:kImageTag + i];
		v.imageURL = [NSURL URLWithString:p.imagePath];
		v.hidden = NO;
		
		UILabel* l = (UILabel *)[self viewWithTag:kLabelTag + i];
		l.text = [p description];
		l.hidden = NO;
		
		i++;
	}
	
	for (; i < 3; i++) {
		EGOImageButton *v = (EGOImageButton *)[self viewWithTag:kImageTag + i];
		v.hidden = YES;
		
		UILabel* l = (UILabel *)[self viewWithTag:kLabelTag + i];
		l.hidden = YES;
		
		UIProgressView* pv = (UIProgressView*)[self viewWithTag:kProgressTag + i];
		if (pv) [pv removeFromSuperview];
	}
}

- (IBAction)didSelectProduct:(UIControl*)sender {
	NSUInteger item = sender.tag - kImageTag;
	[self.delegate presentProductDetails:[_products objectAtIndex:item]];
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
	[super willMoveToSuperview:newSuperview];
	
	if(!newSuperview) {
		[self unregisterForChangeNotification];
		for (int i=1000; i < 1003; i++) {
			EGOImageButton *v = (EGOImageButton *)[self viewWithTag:i++];
			[v cancelImageLoad];
		}
	}
}

#pragma mark -
#pragma mark Change Notification

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	NSInteger i = [_products indexOfObject:object];
	
	if ([keyPath isEqualToString:@"installing"])
		[self updateProductInstalling:object index:i];
	else {
		MMProduct *p = (MMProduct*)object;
		UIProgressView* pv = (UIProgressView*)[self viewWithTag:kProgressTag + i];
		pv.progress = p.downloadPercent;
	}

}

- (void)unregisterForChangeNotification {
	for (MMProduct* p in _products) {
		[p removeObserver:self forKeyPath:@"installing"];
		[p removeObserver:self forKeyPath:@"downloadPercent"];
	}
}

- (void)updateProductInstalling:(MMProduct*)p index:(NSInteger)i; {
	
	EGOImageButton *v = (EGOImageButton *)[self viewWithTag:kImageTag + i];
	UIProgressView* pv = (UIProgressView*)[self viewWithTag:kProgressTag + i];
	if (p.installing && !pv) {
		UIProgressView* pv = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
		pv.tag = kProgressTag + i;
		pv.frame = CGRectMake(0, 0, 70, 10);
		pv.center = v.center;
		[self addSubview:pv];
		[pv release];
	}

	if (p.installing) {
		v.enabled = NO;
		pv.progress = p.downloadPercent;
	} else {
		v.enabled = YES;
		[pv removeFromSuperview];
	}

	
}

@synthesize delegate=_delegate;

@end