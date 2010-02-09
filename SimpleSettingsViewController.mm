/*
 Frodo, Commodore 64 emulator for the iPhone
 Copyright (C)	
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


#import "SimpleSettingsViewController.h"
#import "Prefs.h"
#import "Frodo.h"
#import "C64.h"
#import "C64Defaults.h"
#import "MMStoreManager.h"

typedef struct tagPrefs {
	Prefs	*prefs;
};

@interface SimpleSettingsViewController()

- (void)updateControls;

@end

@implementation SimpleSettingsViewController

@synthesize showFullKeyboard, fixedJoystick, joystickOnRight, version;

- (void)viewDidLoad {
    [super viewDidLoad];
	
	changed				= NO;
	opaque_prefs		= new tagPrefs();
	opaque_prefs->prefs = new Prefs();
	self.version.text	= [NSString stringWithFormat:@"v%@", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
	
#if defined(_ARM_ARCH_7)
	UILabel* speedLabel = (UILabel*)[self.view viewWithTag:1000];
	speedLabel.hidden = false;
	speedLabel.text = @"ARMv7 Optimized";
#endif
	
	[self updateControls];
}

- (IBAction)downloadAllPurchases:(id)sender {
	[[MMStoreManager defaultStore] downloadAllPurchases];
}

- (IBAction)toggleShowFullKeyboard:(UIButton*)sender {
	changed = YES;
	sender.selected = !sender.selected;
	opaque_prefs->prefs->UseCommodoreKeyboard = (bool)sender.selected;
}

- (IBAction)toggleJoystickOnRight:(UIButton*)sender {
	sender.selected = !sender.selected;
	[C64Defaults shared].joystickOnRight = sender.selected;
}

- (IBAction)toggleFixedJoystick:(UIButton*)sender {
	BOOL fixedOn = (sender.selected = !sender.selected);
	[C64Defaults shared].controlsMode = fixedOn ? 1 : 0;
}

- (void)updateControls {
	Prefs *prefs = opaque_prefs->prefs;
	prefs->Load(Frodo::prefs_path());
	showFullKeyboard.selected = prefs->UseCommodoreKeyboard;
	joystickOnRight.selected = [C64Defaults shared].joystickOnRight;
	fixedJoystick.selected = [C64Defaults shared].controlsMode == 1;
}

- (void)viewWillDisappear:(BOOL)animated {
	if (!changed)
		return;
	
	Prefs *prefs = opaque_prefs->prefs;
	prefs->Save(Frodo::prefs_path());
	
	if (Frodo::Instance && Frodo::Instance->TheC64) {
		Prefs *newPrefs = Frodo::reload_prefs();
		Frodo::Instance->TheC64->NewPrefs(newPrefs);
		ThePrefs = *newPrefs;
	}
}

- (void)dealloc {
	if (opaque_prefs) {
		delete opaque_prefs->prefs;
		delete opaque_prefs;
	}
	
	self.showFullKeyboard = nil;
	self.fixedJoystick = nil;
    [super dealloc];
}


@end
