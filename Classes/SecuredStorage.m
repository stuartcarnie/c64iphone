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

#import "SecuredStorage.h"

#if !TARGET_IPHONE_SIMULATOR

#import <Security/Security.h>

@interface SecuredDictionaryStorage(PrivateImplementation)
- (NSData *) dataFromDictionary: (NSMutableDictionary *) dict;
- (NSMutableDictionary *) dictionaryFromData: (NSData *) data;
@end

@implementation SecuredDictionaryStorage 

static SecuredDictionaryStorage *sharedInstance = nil;

+(SecuredDictionaryStorage *) sharedInstance { 
	if(!sharedInstance) { 
		sharedInstance = [[self alloc] init]; 
	} 
	return sharedInstance; 
} 

// Translate status messages into return strings 
- (NSString *) fetchStatus : (OSStatus) status { 
	if        (status == 0) return(@"Success!"); 
	else if (status == errSecNotAvailable) return(@"No trust results are available."); 
	else if (status == errSecItemNotFound) return(@"The item cannot be found."); 
	else if (status == errSecParam) return(@"Parameter error."); 
	else if (status == errSecAllocate) return(@"Memory allocation error. Failed to allocate memory."); 
	else if (status == errSecInteractionNotAllowed) return(@"User interaction is not allowed."); 
	else if (status == errSecUnimplemented) return(@"Function is not implemented"); 
	else if (status == errSecDuplicateItem) return(@"The item already exists."); 
	else if (status == errSecDecode) return(@"Unable to decode the provided data."); 
	else 
		return([NSString stringWithFormat:@"Function returned: %d", status]); 
}

#define    ACCOUNT    @"iC64-SecuredDictionaryStorage" 
#define    SERVICE    @"iC64-SecuredDictionaryStorage" 
#define    PWKEY      @"iC64-SecuredDictionaryStorage" 
#define    DEBUG      YES 

// Return a base dictionary 
- (NSMutableDictionary *) baseDictionary { 
	NSMutableDictionary *md = [[NSMutableDictionary alloc] init]; 
	// Password identification keys 
	NSData *identifier = [PWKEY dataUsingEncoding:NSUTF8StringEncoding]; 
	[md setObject:identifier forKey:(id)kSecAttrGeneric]; 
	[md setObject:ACCOUNT forKey:(id)kSecAttrAccount]; 
	[md setObject:SERVICE forKey:(id)kSecAttrService]; 
	[md setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass]; 
	return [md autorelease]; 
}

// Return a keychain-style dictionary populated with the password 
- (NSMutableDictionary *) buildDictForPassword:(NSMutableDictionary *) dict { 
	NSMutableDictionary *passwordDict = [self baseDictionary];
	// Add the password 
	NSData *dictData = [self dataFromDictionary:dict];
	[passwordDict setObject:dictData forKey:(id)kSecValueData]; // password 
	return passwordDict; 
}

// Build a search query based 
- (NSMutableDictionary *) buildSearchQuery { 
	NSMutableDictionary *genericDictQuery = [self baseDictionary]; 
	// Add the search constraints: One match returning both 
	// data and attributes 
	[genericDictQuery setObject:(id)kSecMatchLimitOne 
							 forKey:(id)kSecMatchLimit]; 
	[genericDictQuery setObject:(id)kCFBooleanTrue 
							 forKey:(id)kSecReturnAttributes]; 
	[genericDictQuery setObject:(id)kCFBooleanTrue 
							 forKey:(id)kSecReturnData]; 
	return genericDictQuery; 
}

// retrieve data dictionary from the keychain 
- (NSMutableDictionary *) fetchDictionary { 
	NSMutableDictionary *genericDictQuery = [self buildSearchQuery];
	NSMutableDictionary *outDictionary = nil;
	OSStatus status = SecItemCopyMatching((CFDictionaryRef)genericDictQuery, 
										  (CFTypeRef *)&outDictionary); 
	if (DEBUG) printf("FETCH: %s\n", [[self fetchStatus:status] UTF8String]); 
	if (status == errSecItemNotFound) return NULL; 
	return outDictionary; 
}

// create a new keychain entry 
- (BOOL) createKeychainValue:(NSMutableDictionary *) dict { 
	NSMutableDictionary *md = [self buildDictForPassword:dict]; 
	OSStatus status = SecItemAdd((CFDictionaryRef)md, NULL); 
	if (DEBUG) printf("CREATE: %s\n", [[self fetchStatus:status] UTF8String]); 
	if (status == noErr) return YES; else return NO; 
}

// remove a keychain entry 
- (void) clearKeychain { 
	NSMutableDictionary *genericDictionaryQuery = [self baseDictionary]; 
	OSStatus status = SecItemDelete((CFDictionaryRef) genericDictionaryQuery); 
	if (DEBUG) printf("DELETE: %s\n", [[self fetchStatus:status] UTF8String]); 
}

// Serialize to data 
- (NSData *) dataFromDictionary: (NSMutableDictionary *) dict { 
	NSString *errorString; 
	NSData *outData = [NSPropertyListSerialization dataFromPropertyList:dict 
																 format:NSPropertyListBinaryFormat_v1_0 
													   errorDescription:&errorString]; 
	return outData; 
} 

// Deserialize from data 
- (NSMutableDictionary *) dictionaryFromData: (NSData *) data { 
	NSString *errorString; 
	NSMutableDictionary *outDict = [NSPropertyListSerialization propertyListFromData:data 
																	mutabilityOption:kCFPropertyListMutableContainersAndLeaves 
																			  format:NULL 
																	errorDescription:&errorString]; 
	return outDict; 
}

- (void) clearSecuredDictionary {
	[self clearKeychain];
}

// update a keychaing entry 
- (BOOL) updateKeychainValue:(NSMutableDictionary *)dict { 
	NSMutableDictionary *genericDictQuery = [self baseDictionary]; 
	NSMutableDictionary *attributesToUpdate = [[NSMutableDictionary alloc] init]; 
	NSData *dictData = [self dataFromDictionary:dict]; 
	[attributesToUpdate setObject:dictData forKey:(id)kSecValueData]; 
	OSStatus status = SecItemUpdate((CFDictionaryRef)genericDictQuery, (CFDictionaryRef)attributesToUpdate); 
	[attributesToUpdate release];
	if (DEBUG) printf("UPDATE: %s\n", [[self fetchStatus:status] UTF8String]); 
	if (status == 0) return YES; else return NO; 
} 

// fetch a keychain value 
- (NSMutableDictionary *) fetchKeychainValue { 
	NSMutableDictionary *outDictionary = [self fetchDictionary]; 
	if (outDictionary) { 
		NSMutableDictionary* dict = [self dictionaryFromData:[outDictionary objectForKey:(id)kSecValueData]];
		return [dict autorelease]; 
	} else return NULL; 
} 


- (void) setObject: (id) anObject forKey: (NSString *) aKey { 
	NSMutableDictionary *dict = [self fetchKeychainValue]; 
	if (dict) { 
		// Keychain already has object 
		[dict setObject:anObject forKey:aKey]; 
		[self updateKeychainValue:dict]; 
		return; 
	} 
	// Dictionary not found so create it 
	dict = [[NSMutableDictionary alloc] init]; 
	[dict setObject:anObject forKey:aKey]; 
	if (![self createKeychainValue:dict]) [self updateKeychainValue:dict]; 
} 

- (void) removeObjectForKey: (NSString *) aKey { 
	NSMutableDictionary *dict = [self fetchKeychainValue]; 
	if (dict) { 
		// Keychain has object 
		[dict removeObjectForKey:aKey]; 
		[self updateKeychainValue:dict]; 
		return; 
	} 
} 

- (id) objectForKey: (NSString *) aKey { 
	NSMutableDictionary *dict = [self fetchKeychainValue]; 
	return [dict objectForKey:aKey]; 
}

- (NSMutableDictionary *) securedDictionary { 
	return [self fetchKeychainValue]; 
} 

@end

#else

@implementation SecuredDictionaryStorage 

static SecuredDictionaryStorage *sharedInstance		= nil;
static NSMutableDictionary		*sharedDictionary	= nil;

+(SecuredDictionaryStorage *) sharedInstance { 
	if(!sharedInstance) { 
		sharedInstance = [[self alloc] init]; 
		sharedDictionary = [[NSMutableDictionary alloc] init];
	} 
	return sharedInstance; 
} 

- (void) clearSecuredDictionary {
	[sharedDictionary removeAllObjects];
}

- (void) setObject: (id) anObject forKey: (NSString *) aKey {
	[sharedDictionary setObject:anObject forKey:aKey];
}

- (void) removeObjectForKey: (NSString *) aKey {
	[sharedDictionary removeObjectForKey:aKey];
}

- (id) objectForKey: (NSString *) aKey {
	return [sharedDictionary objectForKey:aKey];
}

- (NSMutableDictionary *) securedDictionary {
	return sharedDictionary;
}

@end

#endif