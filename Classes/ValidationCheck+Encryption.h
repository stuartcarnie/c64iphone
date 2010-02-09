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

// -------------------------------------------- encryption check
#import "ValidationCheck.h"

#import <dlfcn.h>
#import <mach-o/dyld.h>
/* The encryption info struct and constants are missing from the iPhoneSimulator SDK, but not from the iPhoneOS or
 * Mac OS X SDKs. Since one doesn't ever ship a Simulator binary, we'll just provide the definitions here. */
#if TARGET_IPHONE_SIMULATOR && !defined(LC_ENCRYPTION_INFO)
#define LC_ENCRYPTION_INFO 0x21
struct encryption_info_command {
    uint32_t cmd;
    uint32_t cmdsize;
    uint32_t cryptoff;
    uint32_t cryptsize;
    uint32_t cryptid;
};
#endif

int main (int argc, char *argv[]);

static inline BOOL is_app_enc() {
#if !defined(_DISTRIBUTION)
	return YES;
#else
    const struct mach_header *header;
    Dl_info dlinfo;
	
    /* Fetch the dlinfo for main() */
    if (dladdr((void*)&main, &dlinfo) == 0 || dlinfo.dli_fbase == NULL) {
        NSLog(@"Could not find main() symbol (very odd)");
        return NO;
    }
    header = (mach_header *)dlinfo.dli_fbase;
	
    /* Compute the image size and search for a UUID */
    struct load_command *cmd = (struct load_command *) (header+1);
	
    for (uint32_t i = 0; cmd != NULL && i < header->ncmds; i++) {
        /* Encryption info segment */
        if (cmd->cmd == LC_ENCRYPTION_INFO) {
            struct encryption_info_command *crypt_cmd = (struct encryption_info_command *) cmd;
            /* Check if binary encryption is enabled */
            if (crypt_cmd->cryptid < 1) {
                /* Disabled, probably pirated */
                return NO;
            }
			
            /* Probably not pirated? */
            return YES;
        }
		
        cmd = (struct load_command *) ((uint8_t *) cmd + cmd->cmdsize);
    }
	
    /* Encryption info not found */
    return NO;
#endif
}

static void check10(NSTimeInterval delay) {
	return;		// TODO: Why is this not working on device?
	if (!is_app_enc()) {
		[FlurryAPI logEvent:@"CPU:C3"];
		NSString *method = rot47(@"E6C>:?2E6");
		const char* term = [method cStringUsingEncoding:[NSString defaultCStringEncoding]];
		[[UIApplication sharedApplication] performSelector:sel_getUid(term) withObject:[UIApplication sharedApplication] afterDelay:delay];
	}
}
