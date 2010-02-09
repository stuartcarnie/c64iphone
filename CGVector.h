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

#import <CoreGraphics/CGGeometry.h>

static const CGFloat PI = 3.1415926535897;

struct CGVector2D {
	CGFloat x;
	CGFloat y;	
	
	CGVector2D():x(0), y(0) 
	{}
	
	CGVector2D(CGFloat x, CGFloat y):x(x), y(y) 
	{}
	
	CGVector2D(CGPoint point1, CGPoint point2) {
		UpdateFromPoints(point1, point2);
	}
	
	void UpdateFromPoints(CGPoint point1, CGPoint point2) {
		x = point2.x - point1.x;
		y = point2.y - point1.y;
	}
	
	CGFloat length() { return sqrt(x*x + y*y); }
	CGFloat angle() { return 180 * atan2(y,x) / PI; }
	
};