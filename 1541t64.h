/*
 Frodo, Commodore 64 emulator for the iPhone
 Copyright (C) 1994-1997,2002 Christian Bauer
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

/*
 *  1541t64.h - 1541 emulation in .t64/LYNX file
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 */

#ifndef _1541T64_H
#define _1541T64_H

#include "IEC.h"


// Information for file inside a .t64 file
typedef struct {
	char name[17];		// File name, PETSCII
	uint8 type;			// File type
	uint8 sa_lo, sa_hi;	// Start address
	int offset;			// Offset of first byte in .t64 file
	int length;			// Length of file
} FileInfo;


class T64Drive : public Drive {
public:
	T64Drive(IEC *iec, char *filepath);
	virtual ~T64Drive();
	virtual uint8 Open(int channel, char *filename);
	virtual uint8 Close(int channel);
	virtual uint8 Read(int channel, uint8 *byte);
	virtual uint8 Write(int channel, uint8 byte, bool eoi);
	virtual void Reset(void);

private:
	void open_close_t64_file(const char *t64name);
	bool parse_t64_file(void);
	bool parse_lynx_file(void);
	uint8 open_file(int channel, char *filename);
	uint8 open_directory(int channel, char *filename);
	void convert_filename(char *srcname, char *destname, int *filemode, int *filetype);
	bool find_first_file(char *name, int type, int *num);
	void close_all_channels(void);
	void execute_command(char *command);
	void cht64_cmd(char *t64path);
	uint8 conv_from_64(uint8 c);

	FILE *the_file;			// File pointer for .t64 file
	bool is_lynx;			// Flag: .t64 file is really a LYNX archive

	char orig_t64_name[256]; // Original path of .t64 file
	char dir_title[16];		// Directory title
	FILE *file[16];			// File pointers for each of the 16 channels (all temporary files)

	int num_files;			// Number of files in .t64 file and in file_info array
	FileInfo *file_info;	// Pointer to array of file information structs for each file

	char cmd_buffer[44];	// Buffer for incoming command strings
	int cmd_len;			// Length of received command

	uint8 read_char[16];	// Buffers for one-byte read-ahead
};

#endif
