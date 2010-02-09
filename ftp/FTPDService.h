//
//  FTPDService.h
//  Test
//
//  Created by Stuart Carnie on 1/28/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifdef _DISTRIBUTION
#error FTP not supported in distribution builds
#endif

@interface FTPDService : NSObject {
	BOOL ftpOn;
	NSNetService *ftpService;
}

- (void)start;

@property (assign) BOOL ftpOn;
@property (retain) NSNetService *ftpService;

@end
