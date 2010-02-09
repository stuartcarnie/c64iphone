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

class OFControllerLoader
{
public:
	static UIViewController* load(NSString* name, NSObject* filesOwner = nil);
	static UITableViewCell* loadCell(NSString* cellName, NSObject* filesOwner = nil);
	static UIView* loadView(NSString* viewName, NSObject* filesOwner = nil);
	static bool doesControllerExist(NSString* name);
	
	static void replaceMeWith(UIViewController* controllerToReplace, NSString* name);
	static void push(UIViewController* requestingController, NSString* name, BOOL shouldAnimate = YES, BOOL shouldHaveBackButton = YES);
	
	static void setAssetFileSuffix(NSString* suffixString);
	static void setClassNamePrefix(NSString* prefixString);
	
private:
	static UINavigationController* getNavigationController(UIViewController* requestingController);
	static NSString* getControllerNibName(NSString* controllerName);
	static NSString* getControllerClassName(NSString* controllerName);
};