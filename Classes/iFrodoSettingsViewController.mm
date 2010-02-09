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

#import "iFrodoSettingsViewController.h"
#import "iFSwitchCell.h"
#import "SegmentSettingsCell.h"
#import "LatencySettingsCell.h"
#import "Frodo.h"
#import "C64.h"

@implementation iFrodoSettingsViewController

enum {
	general_section,
	drive_section,
	controllers_section,
	emulation_section,
	sid_section,
	sound_section,
	debug_section
};

enum {
	emulate_1541_option,
	swap_joysticks_option,
	frame_skip_option,
	borders_option,
	sid_on_option,
	sid_filters_option,
	show_speed_option,
	autoboot_option,
	latency_min_option,
	latency_max_option,
	always_use_commodore_keyboard,
};

- (void)viewDidLoad {
	self.title = @"Settings";
	sections = [[NSArray arrayWithObjects:@"General", @"Drive", @"Controllers", @"Emulation", @"SID", @"Audio Latency", @"Debug", nil] retain];
	prefs = new Prefs();
	prefs->Load(Frodo::prefs_path());
	
	[super viewDidLoad];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return [sections count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return [sections objectAtIndex:section];
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
	switch (section) {
		case general_section:
			return 2;
			
		case drive_section:
			return 1;
			
		case controllers_section:
			return 1;
			
		case emulation_section:
			return 2;
			
		case sid_section:
			return 2;
			
		case sound_section:
			return 2;
			
		case debug_section:
			return 1;
	}
    return 0;
}

- (iFSwitchCell *)newSwitchCell
{
	[[NSBundle mainBundle] loadNibNamed:@"iFrodoSettingsCells" owner:self options:NULL];
	iFSwitchCell *cell = theCell;
	theCell = nil;
	return cell;
}

- (SegmentSettingsCell *)newSegmentCell
{
	[[NSBundle mainBundle] loadNibNamed:@"SegmentSettingsCell" owner:self options:NULL];
	SegmentSettingsCell *cell = theSegmentCell;
	theSegmentCell = nil;
	return cell;
}

- (void)loadLatencyCells {
	[[NSBundle mainBundle] loadNibNamed:@"LatencySettingsCells" owner:self options:NULL];
}

static int latency_min_values[] = {  80, 100, 120, 140, 160, 180 };
static int latency_max_values[] = { 200, 225, 250, 275, 300, 325 };
int findIndex(int* vals, int val) {
	for (int i = 0; i < 6; i++) {
		if (*vals == val)
			return i;
		vals++;
	}
	return 0;
}

- (void)settingChangedFor:(UIControl *)sender {
	if ([sender isKindOfClass:[UISwitch class]]) {
		UISwitch* ctl = (UISwitch *)sender;
		switch (ctl.tag) {
			case emulate_1541_option:
				prefs->Emul1541Proc = ctl.on;
				break;
				
			case autoboot_option:
				prefs->AutoBoot = ctl.on;
				break;
				
			case always_use_commodore_keyboard:
				prefs->UseCommodoreKeyboard = ctl.on;
				break;
				
			case swap_joysticks_option:
				prefs->JoystickSwap = ctl.on;
				break;
				
			case sid_on_option:
				prefs->SIDOn = ctl.on;
				break;
				
			case sid_filters_option:
				prefs->SIDFilters = ctl.on;
				break;
				
			case show_speed_option:
				prefs->ShowSpeed = ctl.on;
				break;
				
			case borders_option:
				prefs->BordersOn = ctl.on;
				break;
		}
	} else {
		UISegmentedControl* ctl = (UISegmentedControl *)sender;
		switch (ctl.tag) {
			case frame_skip_option:
				prefs->SkipFrames = ctl.selectedSegmentIndex + 3;
				break;
				
			case latency_min_option:
				prefs->LatencyMin = latency_min_values[ctl.selectedSegmentIndex];
				break;
				
			case latency_max_option:
				prefs->LatencyMax = latency_max_values[ctl.selectedSegmentIndex];
				break;
		}
	}
	
	prefs->Save(Frodo::prefs_path());
	
	if (Frodo::Instance && Frodo::Instance->TheC64) {
		Prefs *newPrefs = Frodo::reload_prefs();
		Frodo::Instance->TheC64->NewPrefs(newPrefs);
		ThePrefs = *newPrefs;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = nil;
	
	int section = [indexPath indexAtPosition:0];
	
	switch (section) {
		case general_section: {
			iFSwitchCell* cell2 = [self newSwitchCell];
			switch (indexPath.row) {
				case 0: {
					cell2.label.text = @"Auto Boot";
					cell2.theSwitch.tag = autoboot_option;
					cell2.theSwitch.on = prefs->AutoBoot;
					break;
				}
					
				case 1: {
					cell2.label.text = @"Keyboard";
					cell2.theSwitch.tag = always_use_commodore_keyboard;
					cell2.theSwitch.on = prefs->UseCommodoreKeyboard;
					break;
				}
			}
			
			[cell2.theSwitch addTarget:self action:@selector(settingChangedFor:) forControlEvents:UIControlEventValueChanged];
			cell = cell2;
			break;
		}
			
		case drive_section: {
			iFSwitchCell* cell2 = [self newSwitchCell];
			cell2.label.text = @"Emulate Drive";
			cell2.theSwitch.tag = emulate_1541_option;
			cell2.theSwitch.on = prefs->Emul1541Proc;
			[cell2.theSwitch addTarget:self action:@selector(settingChangedFor:) forControlEvents:UIControlEventValueChanged];
			cell = cell2;
			break;
		}
			
		case controllers_section: {
			iFSwitchCell* cell2 = [self newSwitchCell];
			cell2.label.text = @"Swap Joysticks";
			cell2.theSwitch.tag = swap_joysticks_option;
			cell2.theSwitch.on = prefs->JoystickSwap;
			[cell2.theSwitch addTarget:self action:@selector(settingChangedFor:) forControlEvents:UIControlEventValueChanged];
			cell = cell2;
			break;
		}
			
		case emulation_section: {
			switch (indexPath.row) {
				case 0: {
					SegmentSettingsCell* cell2 = [self newSegmentCell];
					cell2.label.text = @"Frame Skip";
					cell2.theSegment.tag = frame_skip_option;
					cell2.theSegment.selectedSegmentIndex = prefs->SkipFrames - 3;
					[cell2.theSegment addTarget:self action:@selector(settingChangedFor:) forControlEvents:UIControlEventValueChanged];
					cell = cell2;
					break;
				}
				case 1: {
					iFSwitchCell* cell2 = [self newSwitchCell];
					cell2.label.text = @"Borders";
					cell2.theSwitch.tag = borders_option;
					cell2.theSwitch.on = prefs->BordersOn;
					[cell2.theSwitch addTarget:self action:@selector(settingChangedFor:) forControlEvents:UIControlEventValueChanged];
					cell = cell2;
					break;
				}
			}
			break;
		}
			
		case sid_section: {
			switch (indexPath.row) {
				case 0: {
					iFSwitchCell* cell2 = [self newSwitchCell];
					cell2.label.text = @"SID On";
					cell2.theSwitch.tag = sid_on_option;
					cell2.theSwitch.on = prefs->SIDOn;
					[cell2.theSwitch addTarget:self action:@selector(settingChangedFor:) forControlEvents:UIControlEventValueChanged];
					cell = cell2;
					break;
				}
				case 1: {
					iFSwitchCell* cell2 = [self newSwitchCell];
					cell2.label.text = @"SID Filters";
					cell2.theSwitch.tag = sid_filters_option;
					cell2.theSwitch.on = prefs->SIDFilters;
					[cell2.theSwitch addTarget:self action:@selector(settingChangedFor:) forControlEvents:UIControlEventValueChanged];
					cell = cell2;
					break;
				}
			}
			break;
		}
			
		case sound_section: {
			if (minLatency == nil) {
				[self loadLatencyCells];
				LatencySettingsCell* cell2 = minLatency;
				cell2.segment.tag = latency_min_option;
				cell2.segment.selectedSegmentIndex = findIndex(latency_min_values, prefs->LatencyMin);
				[cell2.segment addTarget:self action:@selector(settingChangedFor:) forControlEvents:UIControlEventValueChanged];

				cell2 = maxLatency;
				cell2.segment.tag = latency_max_option;
				cell2.segment.selectedSegmentIndex = findIndex(latency_max_values, prefs->LatencyMax);
				[cell2.segment addTarget:self action:@selector(settingChangedFor:) forControlEvents:UIControlEventValueChanged];
			}
			
			switch (indexPath.row) {
				case 0: {
					cell = minLatency;
					break;
				}
				case 1: {
					cell = maxLatency;
					break;
				}
			}
			break;
		}
			
		case debug_section: {
			iFSwitchCell* cell2 = [self newSwitchCell];
			cell2.label.text = @"Show Speed";
			cell2.theSwitch.tag = show_speed_option;
			cell2.theSwitch.on = prefs->ShowSpeed;
			[cell2.theSwitch addTarget:self action:@selector(settingChangedFor:) forControlEvents:UIControlEventValueChanged];
			cell = cell2;
			break;
		}
	}
	
	return cell;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
	// Release anything that's not essential, such as cached data
}

- (void)dealloc {
	delete prefs;
	[sections release];
	[super dealloc];
}


@end
