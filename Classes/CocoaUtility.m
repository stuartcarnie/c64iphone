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

#include "CocoaUtility.h"

@implementation UIImage(Loading)

+ (UIImage*)imageFromResource:(NSString*)resourceName {
	NSData *imageData = [[NSData alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:resourceName 
																							   ofType:nil]];
	UIImage *image = [UIImage imageWithData:imageData];
	[imageData release];
	return image;
}

@end

@implementation UIImageView(UIImageHelpers)

+ (UIImageView*)newViewFromImageResource:(NSString*)resourceName {
	NSData *imageData = [[NSData alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:resourceName 
																							   ofType:nil]];
	UIImageView *view = [[UIImageView alloc] initWithImage:[UIImage imageWithData:imageData]];
	[imageData release];
	return view;	
}

@end

@implementation NSString(URLEncoding)

- (NSString *)encodeForURL {
	NSString *reserved = @":/?#[]@!$&'()*+;=";
    return [NSMakeCollectable(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)self, NULL, (CFStringRef)reserved, kCFStringEncodingUTF8)) autorelease];
}

- (NSString *) decodeFromURL {
	return [NSMakeCollectable(CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault, (CFStringRef)self, CFSTR(""), kCFStringEncodingUTF8)) autorelease];
}

@end

@implementation NSString(StuartsExtra)

- (NSString *)reversed {
	int len = [self length];
	char buf[len + 1];
	buf[len] = '\0';
	const char* src = [self cStringUsingEncoding:[NSString defaultCStringEncoding]];
	char* dst = &buf[len-1];
	while (len--) {
		*dst-- = *src++;
	}
	return [NSString stringWithCString:buf length:[self length]];
}

@end

@implementation UIButton(ButtonHelpers)

+ (UIButton*)newButtonWithImage:(NSString*)imageName andSelectedImage:(NSString*)selectedImageName {
	UIButton *view = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *image = [UIImage imageFromResource:imageName];
	view.frame = CGRectMake(0, 0, image.size.width, image.size.height);
	[view setImage:image forState:UIControlStateNormal];
	if (selectedImageName)
		[view setImage:[UIImage imageFromResource:selectedImageName] forState:UIControlStateSelected];
	return [view retain];
}


@end