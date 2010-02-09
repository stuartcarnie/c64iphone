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

#include "EncryptDecrypt.h"
#include <CommonCrypto/CommonCryptor.h>
#include <CommonCrypto/CommonDigest.h>
#include "NSDataBase64.h"

static void Encrypt(NSString *src, NSString **dst, NSString	*key) {
    const char *    keyUTF8;
    unsigned char   keyDigest[CC_MD5_DIGEST_LENGTH];
	
    assert(src != NULL);
    assert(dst != NULL);
    assert(key != nil);
	
    // Calculate an MD5 digest of the key.
	
    keyUTF8 = [key UTF8String];
    assert(keyUTF8 != NULL);
	
    (void) CC_MD5(keyUTF8, (CC_LONG) strlen(keyUTF8), keyDigest);
	
	const char *srcData = [src UTF8String];
	char *dstData = (char *)malloc(128);
	char *p = dstData;
	
	const int len = [src length];
	for(int i = 0; i < len; i++) {
		*p++ = *srcData++ ^ keyDigest[i % CC_MD5_DIGEST_LENGTH];
	}

	realloc(dstData, len);
	NSData *data = [NSData dataWithBytesNoCopy:dstData length:len freeWhenDone:YES];
	*dst = [data base64Encoding];
}

static void Decrypt(NSData *src, NSString **dst, NSString *key) {
    const char *    keyUTF8;
    unsigned char   keyDigest[CC_MD5_DIGEST_LENGTH];
	
    assert(src != NULL);
    assert(dst != NULL);
    assert(key != nil);
	
    // Calculate an MD5 digest of the key.
	
    keyUTF8 = [key UTF8String];
    assert(keyUTF8 != NULL);
	
    (void) CC_MD5(keyUTF8, (CC_LONG) strlen(keyUTF8), keyDigest);
	
	const char *srcData = (const char*)[src bytes];
	char *dstData = (char *)malloc(128);
	char *p = dstData;
	
	const int len = [src length];
	for(int i = 0; i < len; i++) {
		*p++ = *srcData++ ^ keyDigest[i % CC_MD5_DIGEST_LENGTH];
	}
	
	realloc(dstData, len);
	*dst = [NSString stringWithCString:dstData length:len];
	free(dstData);
}

NSString* EncryptChallenge(NSString *challenge, NSString *key) {
	NSString *encryptedChallenge = nil;
    Encrypt(challenge, &encryptedChallenge, key);
	return encryptedChallenge;
}

NSString* DecryptChallenge(NSString *encryptedChallenge, NSString *key) {
	NSString *decryptedResponse = nil;
	NSData *data = [NSData dataWithBase64EncodedString:encryptedChallenge]; 
    Decrypt(data, &decryptedResponse, key);
	return decryptedResponse;
}