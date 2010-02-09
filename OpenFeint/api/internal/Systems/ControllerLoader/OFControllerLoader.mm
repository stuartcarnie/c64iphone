////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// 
///  Copyright 2009 Aurora Feint, Inc.
/// 
///  Licensed under the Apache License, Version 2.0 (the "License");
///  you may not use this file except in compliance with the License.
///  You may obtain a copy of the License at
///  
///  	http://www.apache.org/licenses/LICENSE-2.0
///  	
///  Unless required by applicable law or agreed to in writing, software
///  distributed under the License is distributed on an "AS IS" BASIS,
///  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
///  See the License for the specific language governing permissions and
///  limitations under the License.
/// 
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#import "OFControllerLoader.h"
#import "OpenFeint+Private.h"
#import <objc/runtime.h>
#import "OFTableCellHelper.h"

namespace
{
	NSString* gSuffixString = @"";
	NSString* gClassNamePrefixString = @"";
}

template <typename _T>
static _T* loadControllerFromNib(NSString* nibName, id owner)
{
	if(owner == nil)
	{
		// citron note: This suppresses tons of console spam
		owner = @"";
	}
	
	NSArray* objects = [[NSBundle mainBundle] loadNibNamed:nibName owner:owner options:nil];	
	
	for(unsigned int i = 0; i < [objects count]; ++i)
	{
		NSObject* obj = [objects objectAtIndex:i];
		if([obj isKindOfClass:[_T class]]) 
		{
			return static_cast<_T*>(obj);
		}
	}
	
	return nil;
}

UITableViewCell* OFControllerLoader::loadCell(NSString* cellName, NSObject* filesOwner)
{
	NSString* nibName = [NSString stringWithFormat:@"%@Cell%@", cellName, gSuffixString];
	UITableViewCell* tableCell = loadControllerFromNib<UITableViewCell>(nibName, filesOwner);
	
	if(!tableCell)
	{
		NSString* cellClassName = [NSString stringWithFormat:@"%@%@Cell", gClassNamePrefixString, cellName];
		Class cellClass = (Class)objc_lookUpClass([cellClassName UTF8String]);
		if(cellClass)
		{
			tableCell = (UITableViewCell*)class_createInstance(cellClass, 0);
			OFAssert([tableCell isKindOfClass:[OFTableCellHelper class]], "We don't support loading non-OFTableCellHelpers via OFControllerLoader::loadCell!");
			
			[(OFTableCellHelper*)tableCell initOFTableCellHelper:cellName];

			[tableCell autorelease];
			
			SEL setOwner = @selector(setOwner:);
			if([tableCell respondsToSelector:setOwner])
			{
				[tableCell performSelector:setOwner withObject:filesOwner];
			}			
		}

		if(!tableCell)
		{
			OFAssert(0, "Failed trying to load table cell %@ from nib %@", cellName, nibName);
			return nil;
		}
	}
	
	if(![tableCell.reuseIdentifier isEqualToString:cellName])
	{
		OFAssert(0, "Table cell '%@' from nib '%@' has an incorrect reuse identifier. Expected '%@' but was '%@'", cellName, nibName, cellName, tableCell.reuseIdentifier);
	}
		
	return tableCell;
}

UIViewController* OFControllerLoader::load(NSString* name, NSObject* filesOwner)
{
	UIViewController* controller = nil;
	if ([OpenFeint isInLandscapeMode])
	{
		NSString* landscapeNibName = [NSString stringWithFormat:@"%@ControllerLandscape%@", name, gSuffixString];
		controller = loadControllerFromNib<UIViewController>(landscapeNibName, filesOwner);
	}
	
	if (!controller)
	{
		controller = loadControllerFromNib<UIViewController>(OFControllerLoader::getControllerNibName(name), filesOwner);
	}
	
	
	if(!controller)
	{
		Class controllerClass = (Class)objc_lookUpClass([OFControllerLoader::getControllerClassName(name) UTF8String]);
		if(controllerClass)
		{
			controller = (UIViewController*)class_createInstance(controllerClass, 0);
			[controller init];
			[controller autorelease];
		}
	}
	
	OFAssert(controller, "Failed trying to load controller %@", name);
		
	return controller;
}

UIView* OFControllerLoader::loadView(NSString* viewName, NSObject* filesOwner)
{
	UIView* view = nil;
	if ([OpenFeint isInLandscapeMode])
	{
		NSString* landscapeNibName = [NSString stringWithFormat:@"%@Landscape%@", viewName, gSuffixString];
		view = loadControllerFromNib<UIView>(landscapeNibName, filesOwner);
	}
	
	if (!view)
	{
		view = loadControllerFromNib<UIView>([NSString stringWithFormat:@"%@%@", viewName, gSuffixString], filesOwner);
	}	
	
	OFAssert(view, "Failed trying to load view %@", viewName);
		
	return view;
}

bool OFControllerLoader::doesControllerExist(NSString* name)
{
	if ([OpenFeint isInLandscapeMode])
	{
		NSString* landscapeNibName = [NSString stringWithFormat:@"%@ControllerLandscape%@", name, gSuffixString];
		if ([[NSBundle mainBundle] pathForResource:landscapeNibName ofType:@"nib"])
		{
			return true;
		}
	}

	if ([[NSBundle mainBundle] pathForResource:OFControllerLoader::getControllerNibName(name) ofType:@"nib"])
	{
		return true;
	}

	if (objc_lookUpClass([OFControllerLoader::getControllerClassName(name) UTF8String]))
	{
		return true;
	}
	return false;
}

UINavigationController* OFControllerLoader::getNavigationController(UIViewController* requestingController)
{
	UINavigationController* container = nil;
	if([requestingController isKindOfClass:[UINavigationController class]])
	{
		container = (UINavigationController*)requestingController;
	}
	else
	{
		container = [requestingController navigationController];
	}
	
	OFAssert(container, "Attempting to get a navigation controller from a view controller that doesn't have one.");
	
	return container;
}

void OFControllerLoader::push(UIViewController* requestingController, NSString* name, BOOL shouldAnimate, BOOL shouldHaveBackButton)
{
	UIViewController* incomingContoller = load(name);
	incomingContoller.navigationItem.hidesBackButton = !shouldHaveBackButton;	
	[getNavigationController(requestingController) pushViewController:incomingContoller animated:shouldAnimate];
}
	
void OFControllerLoader::replaceMeWith(UIViewController* controllerToReplace, NSString* name)
{
	UIViewController* incomingController = load(name);

	UINavigationController* navController = getNavigationController(controllerToReplace);
	[navController popToRootViewControllerAnimated:NO];
	[navController pushViewController:incomingController animated:NO];
	[navController setNavigationBarHidden:YES animated:NO];
}

NSString* OFControllerLoader::getControllerNibName(NSString* controllerName)
{
	return [NSString stringWithFormat:@"%@Controller%@", controllerName, gSuffixString];
}

NSString* OFControllerLoader::getControllerClassName(NSString* controllerName)
{
	return [NSString stringWithFormat:@"%@%@Controller", gClassNamePrefixString, controllerName];
}

void OFControllerLoader::setAssetFileSuffix(NSString* suffixString)
{
	[gSuffixString release];
	gSuffixString = [suffixString retain];
}

void OFControllerLoader::setClassNamePrefix(NSString* prefixString)
{
	[gClassNamePrefixString release];
	gClassNamePrefixString = [prefixString retain];
}