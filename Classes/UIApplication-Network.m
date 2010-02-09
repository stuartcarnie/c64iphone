/*
 Frodo, Commodore 64 emulator for the iPhone
 Copyright (C) 2007-2010 Stuart Carnie
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

#import "UIApplication-Network.h"


@implementation UIApplication (NetworkExtensions)

#define ReachableViaWiFiNetwork		2
#define ReachableDirectWWAN			(1 << 18)

// fast wi-fi connection
+(BOOL)hasActiveWiFiConnection {
	SCNetworkReachabilityFlags	flags;
	SCNetworkReachabilityRef    reachabilityRef;
	BOOL                        gotFlags;
	
	reachabilityRef = SCNetworkReachabilityCreateWithName(CFAllocatorGetDefault(), [@"www.apple.com" UTF8String]);
	if (reachabilityRef) {
		gotFlags = SCNetworkReachabilityGetFlags(reachabilityRef, &flags);
		CFRelease(reachabilityRef);
	} else
		gotFlags = 0;
	
	if (!gotFlags) {
		return NO;
	}
	
	if( flags & ReachableDirectWWAN ) {
		return NO;
	}
	
	if( flags & ReachableViaWiFiNetwork ) {
		return YES;
	}
	
	return NO;
}

// any type of internet connection (edge, 3g, wi-fi)
+(BOOL)hasNetworkConnection {
	return [UIApplication hasNetworkConnectionToHost:@"www.apple.com"];
}

+(BOOL)hasNetworkConnectionToHost:(NSString*)hostName {
    SCNetworkReachabilityFlags  flags;
    SCNetworkReachabilityRef	reachabilityRef;
    BOOL                        gotFlags;
    
    reachabilityRef = SCNetworkReachabilityCreateWithName(CFAllocatorGetDefault(), [hostName UTF8String]);
    if (reachabilityRef) {
		gotFlags = SCNetworkReachabilityGetFlags(reachabilityRef, &flags);
		CFRelease(reachabilityRef);
	} else
		gotFlags = 0;
    
    if (!gotFlags || (flags == 0) ) {
        return NO;
    }
    
    return YES;
}

@end