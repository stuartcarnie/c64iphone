#ifndef _LITEUNZIP_H
#define _LITEUNZIP_H

/*
 * LiteUnzip.h 
 *
 * For decompressing the contents of zip archives using LITEUNZIP.DLL.
 *
 * This file is a repackaged form of extracts from the zlib code available
 * at www.gzip.org/zlib, by Jean-Loup Gailly and Mark Adler. The original
 * copyright notice may be found in unzip.cpp. The repackaging was done
 * by Lucian Wischik to simplify and extend its use in Windows/C++. Also
 * encryption and unicode filenames have been added. Code was further
 * revamped and turned into a DLL by Jeff Glatt.
 */

#ifdef __cplusplus
extern "C" {
#endif

#include <sys/time.h>
#include <limits.h>
#ifndef DWORD
#define WINAPI
typedef unsigned long	DWORD;
typedef short			WCHAR;
typedef void			* HANDLE;
#define MAX_PATH		PATH_MAX
typedef unsigned char	BYTE;
typedef unsigned short	WORD;
typedef signed char		BOOL;
#endif

// An HUNZIP identifies a zip archive that has been opened
#define HUNZIP	void *

// Struct used to retrieve info about an entry in an archive
typedef struct
{
	DWORD			Index;
	DWORD			Attributes;
	time_t			AccessTime, CreateTime, ModifyTime;
	unsigned long	CompressedSize;
	unsigned long	UncompressedSize;
	char			Name[MAX_PATH];
} ZIPENTRY;

// Functions for opening a ZIP archive
DWORD WINAPI UnzipOpenFileA(HUNZIP *, const char *, const char *);
DWORD WINAPI UnzipOpenFileW(HUNZIP *, const WCHAR *, const char *);
DWORD WINAPI UnzipOpenFileRawA(HUNZIP *, const char *, const char *);
DWORD WINAPI UnzipOpenFileRawW(HUNZIP *, const WCHAR *, const char *);
#define UnzipOpenFile UnzipOpenFileA
#define UnzipOpenFileRaw UnzipOpenFileRawA

DWORD WINAPI UnzipOpenBuffer(HUNZIP *, void *, DWORD, const char *);
DWORD WINAPI UnzipOpenBufferRaw(HUNZIP *, void *, DWORD, const char *);
DWORD WINAPI UnzipOpenHandle(HUNZIP *, HANDLE, const char *);
DWORD WINAPI UnzipOpenHandleRaw(HUNZIP *, HANDLE, const char *);

// Functions to get information about an "entry" within a ZIP archive
DWORD WINAPI UnzipGetItemW(HUNZIP, ZIPENTRY *);
DWORD WINAPI UnzipGetItemA(HUNZIP, ZIPENTRY *);
#define UnzipGetItem UnzipGetItemA
	
//DWORD WINAPI UnzipGetNextItem(HUNZIP, ZIPENTRY *);

DWORD WINAPI UnzipFindItemW(HUNZIP, ZIPENTRY *, BOOL);
DWORD WINAPI UnzipFindItemA(HUNZIP, ZIPENTRY *, BOOL);
#define UnzipFindItem UnzipFindItemA

// Functions to unzip an "entry" within a ZIP archive
DWORD WINAPI UnzipItemToFileW(HUNZIP, const WCHAR *, ZIPENTRY *);
DWORD WINAPI UnzipItemToFileA(HUNZIP, const char *, ZIPENTRY *);
#define UnzipItemToFile UnzipItemToFileA

DWORD WINAPI UnzipItemToHandle(HUNZIP, HANDLE, ZIPENTRY *);

DWORD WINAPI UnzipItemToBuffer(HUNZIP, void *, DWORD, ZIPENTRY *);

// Function to set the base directory
DWORD WINAPI UnzipSetBaseDirW(HUNZIP, const WCHAR *);
DWORD WINAPI UnzipSetBaseDirA(HUNZIP, const char *);
#define UnzipSetBaseDir UnzipSetBaseDirA

// Function to close an archive
DWORD WINAPI UnzipClose(HUNZIP);

// Function to get an appropriate error message for a given error code return by Unzip functions
DWORD WINAPI UnzipFormatMessageW(DWORD, WCHAR *, DWORD);
DWORD WINAPI UnzipFormatMessageA(DWORD, char *, DWORD);
#define UnzipFormatMessage UnzipFormatMessageA

#if !defined(ZR_OK)
// These are the return codes from Unzip functions
#define ZR_OK			0		// Success
// The following come from general system stuff (e.g. files not openable)
#define ZR_NOFILE		1		// Can't create/open the file
#define ZR_NOALLOC		2		// Failed to allocate memory
#define ZR_WRITE		3		// A general error writing to the file
#define ZR_NOTFOUND		4		// Can't find the specified file in the zip
#define ZR_MORE			5		// There's still more data to be unzipped
#define ZR_CORRUPT		6		// The zipfile is corrupt or not a zipfile
#define ZR_READ			7		// An error reading the file
#define ZR_NOTSUPPORTED	8		// The entry is in a format that can't be decompressed by this Unzip add-on
// The following come from mistakes on the part of the caller
#define ZR_ARGS			9		// Bad arguments passed
#define ZR_NOTMMAP		10		// Tried to ZipGetMemory, but that only works on mmap zipfiles, which yours wasn't
#define ZR_MEMSIZE		11		// The memory-buffer size is too small
#define ZR_FAILED		12		// Already failed when you called this function
#define ZR_ENDED		13		// The zip creation has already been closed
#define ZR_MISSIZE		14		// The source file size turned out mistaken
#define ZR_ZMODE		15		// Tried to mix creating/opening a zip 
// The following come from bugs within the zip library itself
#define ZR_SEEK			16		// trying to seek in an unseekable file
#define ZR_NOCHANGE		17		// changed its mind on storage, but not allowed
#define ZR_FLATE		18		// An error in the de/inflation code
#define ZR_PASSWORD		19		// Password is incorrect
#endif

#ifdef __cplusplus
}
#endif

#endif // _LITEUNZIP_H
