/* -*- mode:c; coding:utf-8; tab-width:8; c-basic-offset:2; indent-tabs-mode:nil -*- */
/*
  Copyright (c) 2003-2005 MacUIM contributors, All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:

  1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.
  2. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.
  3. Neither the name of authors nor the names of its contributors
     may be used to endorse or promote products derived from this software
     without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
  SUCH DAMAGE.
*/

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdarg.h>
#include <Carbon/Carbon.h>

#include "Utils.h"

static char *levelmsg[] = {
  "Fatal", "Error", "Warning", "Debug"
};

#if DEBUG
static UInt32 sDebugLevel = ERROR_DEBUG;
#else
static UInt32 sDebugLevel = ERROR_WARNING;
#endif
static Boolean sPrintTime = FALSE;
static Boolean sPrintSrc  = FALSE;

void
ErrorPrint(UInt32 level, const char *file, UInt32 line,
           const char *fmt, ...)
{
  char msg[ERRMSG_LEN];
  char errmsg[ERRMSG_LEN + 64];
  va_list ap;

  if (sDebugLevel < level)
    return;

  va_start(ap, fmt);
  vsnprintf(msg, ERRMSG_LEN, fmt, ap);
  va_end(ap);

  if (sPrintTime) {
    char timestr[26];
    time_t tm = time(0);
    ctime_r(&tm, timestr);
    timestr[strlen(timestr) - 1] = '\0';
    if (sPrintSrc)
      snprintf(errmsg, ERRMSG_LEN + 64, "MacUIM [%s] %s\n (%s:%lu)\n  %s",
               timestr, levelmsg[level], file, line, msg);
    else
      snprintf(errmsg, ERRMSG_LEN + 64, "MacUIM [%s] %s\n  %s\n",
               timestr, levelmsg[level], msg);
  }
  else {
    if (sPrintSrc)
      snprintf(errmsg, ERRMSG_LEN + 64, "MacUIM %s (%s:%lu) %s",
               levelmsg[level], file, line, msg);
    else
      snprintf(errmsg, ERRMSG_LEN + 64, "MacUIM %s %s",
               levelmsg[level], msg);
  }

  fprintf(stderr, errmsg);
  fflush(NULL);
}

void
DumpString(const char *name, const char *str, int len)
{
  int i;
  char msg[BUFSIZ];
  char ch[3];

  sprintf(msg, "%s: ", name);

  for (i = 0; i < len; i++) {
    if (i > 0)
      strcat(msg, " ");
    sprintf(ch, "%02x", (int) str[i]);
    strcat(msg, ch);
  }
  DEBUG_PRINT("%s\n", msg);
}
