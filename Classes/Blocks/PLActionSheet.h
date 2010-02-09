//
//  PLActionSheet.h
//
//  Created by Landon Fuller on 7/3/09.
//  Copyright 2009 Plausible Labs Cooperative, Inc.. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 * A simple block-enabled API wrapper on top of UIActionSheet.
 */
@interface PLActionSheet : NSObject <UIActionSheetDelegate> {
@private
    UIActionSheet *_sheet;
    NSMutableArray *_blocks;
}

- (id) initWithTitle: (NSString *) title;

- (void) setCancelButtonWithTitle: (NSString *) title block: (void (^)()) block;
- (void) addButtonWithTitle: (NSString *) title block: (void (^)()) block;

- (void) showInView: (UIView *) view;

@end