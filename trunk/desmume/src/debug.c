/*  Copyright 2005 Guillaume Duhamel

    This file is part of DeSmuME.

    DeSmuME is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    DeSmuME is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with DeSmuME; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#include "debug.h"

#include <stdarg.h>
#include <stdlib.h>
#include <string.h>

/////// Console vars
#define BUFFER_SIZE 100
#ifdef WIN32
HANDLE hConsole;
#endif
///////

//////////////////////////////////////////////////////////////////////////////

Debug * DebugInit(const char * n, DebugOutType t, char * s) {
	Debug * d;

        if ((d = (Debug *) malloc(sizeof(Debug))) == NULL)
           return NULL;

	d->output_type = t;

        if ((d->name = strdup(n)) == NULL)
        {
           free(d);
           return NULL;
        }

	switch(t) {
	case DEBUG_STREAM:
                d->output.stream = fopen(s, "w");
		break;
	case DEBUG_STRING:
		d->output.string = s;
		break;
	case DEBUG_STDOUT:
		d->output.stream = stdout;
		break;
	case DEBUG_STDERR:
		d->output.stream = stderr;
		break;
	}

	return d;
}

//////////////////////////////////////////////////////////////////////////////

void DebugDeInit(Debug * d) {
        if (d == NULL)
           return;

	switch(d->output_type) {
	case DEBUG_STREAM:
                if (d->output.stream)
                   fclose(d->output.stream);
		break;
	case DEBUG_STRING:
	case DEBUG_STDOUT:
	case DEBUG_STDERR:
		break;
	}
        if (d->name)
           free(d->name);
	free(d);
}

//////////////////////////////////////////////////////////////////////////////

void DebugChangeOutput(Debug * d, DebugOutType t, char * s) {
	if (t != d->output_type) {
		if (d->output_type == DEBUG_STREAM)
                {
                   if (d->output.stream)
			fclose(d->output.stream);
                }
		d->output_type = t;
	}
	switch(t) {
	case DEBUG_STREAM:
		d->output.stream = fopen(s, "w");
		break;
	case DEBUG_STRING:
		d->output.string = s;
		break;
	case DEBUG_STDOUT:
		d->output.stream = stdout;
		break;
	case DEBUG_STDERR:
		d->output.stream = stderr;
		break;
	}
}

//////////////////////////////////////////////////////////////////////////////

void DebugPrintf(Debug * d, const char * file, u32 line, const char * format, ...) {
	va_list l;

        if (d == NULL)
           return;

	va_start(l, format);

	switch(d->output_type) {
	case DEBUG_STDOUT:
	case DEBUG_STDERR:
	case DEBUG_STREAM:
                if (d->output.stream == NULL)
                   break;
		fprintf(d->output.stream, "%s (%s:%ld): ", d->name, file, line);
		vfprintf(d->output.stream, format, l);
		break;
	case DEBUG_STRING:
		{
			int i;
                        if (d->output.string == NULL)
                           break;

			i = sprintf(d->output.string, "%s (%s:%ld): ", d->name, file, line);
			vsprintf(d->output.string + i, format, l);
		}
		break;
	}

	va_end(l);
}

//////////////////////////////////////////////////////////////////////////////

Debug * MainLog;

//////////////////////////////////////////////////////////////////////////////

void LogStart(void) {
        MainLog = DebugInit("main", DEBUG_STDERR, NULL);
//        MainLog = DebugInit("main", DEBUG_STREAM, "stdout.txt");
}

//////////////////////////////////////////////////////////////////////////////

void LogStop(void) {
	DebugDeInit(MainLog);
}

//////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////// Console
#ifdef WIN32
#ifdef BETA_VERSION
void OpenConsole() 
{
	COORD csize;
	CONSOLE_SCREEN_BUFFER_INFO csbiInfo; 
	SMALL_RECT srect;
	char buf[256];

	if (hConsole) return;
	AllocConsole();
	memset(buf,0,256);
	sprintf(buf,"DeSmuME v%s OUTPUT", VERSION);
	SetConsoleTitle(TEXT(buf));
	csize.X = 60;
	csize.Y = 800;
	SetConsoleScreenBufferSize(GetStdHandle(STD_OUTPUT_HANDLE), csize);
	GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &csbiInfo);
	srect = csbiInfo.srWindow;
	srect.Right = srect.Left + 99;
	srect.Bottom = srect.Top + 64;
	SetConsoleWindowInfo(GetStdHandle(STD_OUTPUT_HANDLE), TRUE, &srect);
	hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
}

void CloseConsole() {
	if (hConsole == NULL) return;
	FreeConsole(); 
	hConsole = NULL;
}

void printlog(char *fmt, ...) {
	va_list list;
	char msg[512],msg2[522];
	wchar_t msg3[522];
	char *ptr;
	DWORD tmp;
	int len, s;
	int i, j;

	LPWSTR ret;

	va_start(list,fmt);
	_vsnprintf(msg,511,fmt,list);
	msg[511] = '\0';
	va_end(list);
	ptr=msg; len=strlen(msg);
	WriteConsole(hConsole,ptr, (DWORD)len, &tmp, 0);
}
#endif
#endif
