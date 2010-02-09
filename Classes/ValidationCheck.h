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

#import "CocoaUtility.h"
#import "FlurryAPI.h"
#import <objc/runtime.h>

#define FORCE_INLINE __attribute__((always_inline))

static FORCE_INLINE BOOL checkState(NSString *str) {
#if TARGET_IPHONE_SIMULATOR
	return NO;
#else
	// true if present
	return [[[NSBundle mainBundle] infoDictionary] objectForKey:str] != nil;
#endif
}

//static char rotChar47(char);
static FORCE_INLINE char rotChar47(char chr) {
	if (chr == ' ') return ' ';
	int ascii = chr;
	ascii += 47;
	if (ascii > 126) ascii -= 94;
	if (ascii < 33) ascii += 94;
	return (char)ascii;
}

static FORCE_INLINE NSString* rot47(NSString *inp) {
	int len = [inp length];
	char buf[len+1];
	const char* pinp = [inp UTF8String];
	
	for (NSUInteger i=0; i<len; i++) {
		buf[i] = rotChar47(*pinp++); 
	}
	buf[len] = '\0';
	NSMutableString *output = [NSString stringWithCString:buf length:len];
	return output;
}

static FORCE_INLINE BOOL check1(NSTimeInterval delay) {
		if (checkState(rot47(@"$:8?6Cx56?E:EJ"))) {
		[FlurryAPI logEvent:@"CHK:1" 
			 withParameters:[NSDictionary dictionaryWithObjectsAndKeys:[[UIDevice currentDevice] uniqueIdentifier], @"uuid", nil]];
		NSString *method = rot47(@"E6C>:?2E6");
		const char* term = [method cStringUsingEncoding:[NSString defaultCStringEncoding]];
		[[UIApplication sharedApplication] performSelector:sel_getUid(term) withObject:[UIApplication sharedApplication] afterDelay:delay];
		return NO;
	}
	
	return YES;
}

static FORCE_INLINE BOOL check2(NSTimeInterval delay) {
	if (checkState(rot47([@"JE:E?65xC6?8:$" reversed]))) {
		[FlurryAPI logEvent:@"CHK:2" 
			 withParameters:[NSDictionary dictionaryWithObjectsAndKeys:[[UIDevice currentDevice] uniqueIdentifier], @"uuid", nil]];
		NSString *method = rot47([@"6E2?:>C6E" reversed]);
		const char* term = [method cStringUsingEncoding:[NSString defaultCStringEncoding]];
		[[UIApplication sharedApplication] performSelector:sel_getUid(term) withObject:[UIApplication sharedApplication] afterDelay:delay];
		return NO;
	}
	
	return YES;
}

static FORCE_INLINE BOOL check3(NSTimeInterval delay) {
	if (checkState(rot47([[@"J E:E  ?65x C6   ?8:$" stringByReplacingOccurrencesOfString:@" " withString:@""] reversed]))) {
		[FlurryAPI logEvent:[@" C  H   K : 3" stringByReplacingOccurrencesOfString:@" " withString:@""]
			 withParameters:[NSDictionary dictionaryWithObjectsAndKeys:[[UIDevice currentDevice] uniqueIdentifier], @"uuid", nil]];
		NSString *method = rot47([[@"6  E 2  ? :  > C  6 E" stringByReplacingOccurrencesOfString:@" " withString:@""] reversed]);
		const char* term = [method cStringUsingEncoding:[NSString defaultCStringEncoding]];
		[[UIApplication sharedApplication] performSelector:sel_getUid(term) withObject:[UIApplication sharedApplication] afterDelay:delay];
		return NO;
	}
	
	return YES;
}

static FORCE_INLINE BOOL check4(NSTimeInterval delay) {
	if (checkState(rot47([@" $ : 8 ? 6 C x 5 6 ? E : E J" stringByReplacingOccurrencesOfString:@" " withString:@""]))) {
		[FlurryAPI logEvent:[@" C H K : 4" stringByReplacingOccurrencesOfString:@" " withString:@""]
			 withParameters:[NSDictionary dictionaryWithObjectsAndKeys:[[UIDevice currentDevice] uniqueIdentifier], @"uuid", nil]];
		NSString *method = rot47([@" E 6 C > : ? 2 E 6" stringByReplacingOccurrencesOfString:@" " withString:@""]);
		const char* term = [method cStringUsingEncoding:[NSString defaultCStringEncoding]];
		[[UIApplication sharedApplication] performSelector:sel_getUid(term) withObject:[UIApplication sharedApplication] afterDelay:delay];
		return NO;
	}
	
	return YES;
}

/*! Used for verifying state of application only - will not perform other functions 
	@result - YES if we're okay, NO if something is wrong...
 */
static FORCE_INLINE BOOL check5() {
	if (checkState(rot47([@" $ : 8 ? 6 C x 5 6 ? E : E J" stringByReplacingOccurrencesOfString:@" " withString:@""]))) {
		[FlurryAPI logEvent:[@" C H K : 5" stringByReplacingOccurrencesOfString:@" " withString:@""]
			 withParameters:[NSDictionary dictionaryWithObjectsAndKeys:[[UIDevice currentDevice] uniqueIdentifier], @"uuid", nil]];
		return NO;
	}
	
	return YES;
}
