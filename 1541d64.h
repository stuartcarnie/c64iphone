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
 *  1541d64.h - 1541 emulation in .d64 file
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 */

#ifndef _1541D64_H
#define _1541D64_H

#include "IEC.h"


// BAM structure
typedef struct {
	uint8	dir_track;		// Track...
	uint8	dir_sector;		// ...and sector of first directory block
	int8	fmt_type;		// Format type
	int8	pad0;
	uint8	bitmap[4*35];	// Sector allocation
	uint8	disk_name[18];	// Disk name
	uint8	id[2];			// Disk ID
	int8	pad1;
	uint8	fmt_char[2];	// Format characters
	int8	pad2[4];
	int8	pad3[85];
} BAM;

// Directory entry structure
typedef struct {
	uint8	type;			// File type
	uint8	track;			// Track...
	uint8	sector;			// ...and sector of first data block
	uint8	name[16];		// File name
	uint8	side_track;		// Track...
	uint8	side_sector;	// ...and sector of first side sector
	uint8	rec_len;		// Record length
	int8	pad0[4];
	uint8	ovr_track;		// Track...
	uint8	ovr_sector;		// ...and sector on overwrite
	uint8	num_blocks_l;	// Number of blocks, LSB
	uint8	num_blocks_h;	// Number of blocks, MSB
	int8	pad1[2];
} DirEntry;

// Directory block structure
typedef struct {
	uint8		padding[2];		// Keep DirEntry word-aligned
	uint8		next_track;
	uint8		next_sector;
	DirEntry	entry[8];
} Directory;


class D64Drive : public Drive {
public:
	D64Drive(IEC *iec, char *filepath);
	virtual ~D64Drive();
	virtual uint8 Open(int channel, char *filename);
	virtual uint8 Close(int channel);
	virtual uint8 Read(int channel, uint8 *byte);
	virtual uint8 Write(int channel, uint8 byte, bool eoi);
	virtual void Reset(void);

private:
	void open_close_d64_file(const char *d64name);
	uint8 open_file(int channel, char *filename);
	void convert_filename(char *srcname, char *destname, int *filemode, int *filetype);
	bool find_file(char *filename, int *track, int *sector);
	uint8 open_file_ts(int channel, int track, int sector);
	uint8 open_directory(char *pattern);
	uint8 open_direct(int channel, char *filename);
	void close_all_channels();
	void execute_command(char *command);
	void block_read_cmd(char *command);
	void buffer_ptr_cmd(char *command);
	bool parse_bcmd(char *cmd, int *arg1, int *arg2, int *arg3, int *arg4);
	void chd64_cmd(char *d64name);
	int alloc_buffer(int want);
	void free_buffer(int buf);
	bool read_sector(int track, int sector, uint8 *buffer);
	int offset_from_ts(int track, int sector);
	uint8 conv_from_64(uint8 c);

	char orig_d64_name[256]; // Original path of .d64 file

	FILE *the_file;			// File pointer for .d64 file

	uint8 *ram;				// 2KB 1541 RAM
	BAM *bam;				// Pointer to BAM
	Directory dir;			// Buffer for directory blocks

	int chan_mode[16];		// Channel mode
	int chan_buf_num[16];	// Buffer number of channel (for direct access channels)
	uint8 *chan_buf[16];	// Pointer to buffer
	uint8 *buf_ptr[16];		// Pointer in buffer
	int buf_len[16];		// Remaining bytes in buffer

	bool buf_free[4];		// Buffer 0..3 free?

	char cmd_buffer[44];	// Buffer for incoming command strings
	int cmd_len;			// Length of received command

	int image_header;		// Length of .d64 file header

	uint8 error_info[683];	// Sector error information (1 byte/sector)
};

#endif
