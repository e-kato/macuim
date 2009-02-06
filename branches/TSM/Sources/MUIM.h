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

#ifndef MUIM_h
#define MUIM_h

#include <Carbon/Carbon.h>

#include <uim.h>
#include <uim-helper.h>

#include "Utils.h"
#include "Debug.h"

#define ENABLE_HELPER  1
#define SYNC_MODE  1

/**
 * preedit segment
 */
typedef struct _PreeditSegment
{
  /** segment buffer */
  UniCharPtr fBuffer;

  /** segment length */
  UInt32 fLength;

  /** segment attributes */
  UInt32 fAttr;

} PreeditSegment;

/**
 * MacUIM session record
 */
typedef struct _MUIMSessionRecord
{
  /** component instance */
  ComponentInstance fComponentInstance;

  /** preedit segment array */
  PreeditSegment *fSegments;

  /** preedit segment count */
  UInt32 fSegmentCount;

  /** Uim context */
  uim_context fUC;

  /** last updated length */
  UInt32 fLastUpdateLength;
    
  /** current preedit buffer */
  UniCharPtr fFixBuffer;

  /** current preedit length */
  UInt32 fFixLen;

  /** old preedit buffer */
  UniCharPtr fOldPreedit;

  /** old preedit length */
  UInt32 fOldPreeditLen;

  /** total number of canddidates */
  SInt32 fNRCandidates;

  /** maximum number of candidate display */
  SInt32 fDisplayLimit;

  /** candidate index */
  SInt32 fCandidateIndex;

  /** page index */
  SInt32 fPageIndex;

  /** beginning index of displayed candidates */
  SInt32 fLayoutBegin;

  /** candidate window is active */
  UInt32 fIsActive;

  /** mode-tips block flag */
  Boolean fModeTipsBlock;

  /** bundle reference of candidate window */
  CFBundleRef fBundleRef;

  /** open candidate window when the context is activated */
  Boolean fWindowOpened;
  
  /** last input mode */
  CFStringRef fLastMode;
  
  /** deactivated time */
  EventTime fDeactivateTime;

} MUIMSessionRecord;

typedef MUIMSessionRecord *MUIMSessionPtr;
typedef MUIMSessionPtr *MUIMSessionHandle;

/**
 * TSM status
 */
typedef struct _TSMStat {
  long fRefCon;
  long fTextOffset;
  ScriptLanguageRecord fSLRec;
  Boolean fLeadingEdge;
  Point fReplyPoint;
  long fReplyFont;
  Fixed fReplyPointSize;
  short fReplyLineHeight;

} TSMStat;


ComponentResult
MUIMInitialize(ComponentInstance inComponentInstance,
               MenuRef *outTextServiceMenu);

void
MUIMTerminate(ComponentInstance inComponentInstance);

ComponentResult
MUIMSessionOpen(ComponentInstance inComponentInstance,
                MUIMSessionHandle *outSessionHandle);

void
MUIMSessionClose(MUIMSessionHandle sessionHandle);

ComponentResult
MUIMSessionActivate(MUIMSessionHandle sessionHandle);

ComponentResult
MUIMSessionDeactivate(MUIMSessionHandle sessionHandle);

ComponentResult
MUIMSessionEvent(MUIMSessionHandle sessionHandle, EventRef eventRef);

ComponentResult
MUIMSessionFix(MUIMSessionHandle sessionHandle);

ComponentResult
MUIMSetInputMode(MUIMSessionHandle inSessionHandle, CFStringRef inInputMode);

ComponentResult
MUIMHideWindow(MUIMSessionHandle inSessionHandle);

MUIMSessionHandle
MUIMGetActiveSession(void);

Boolean
MUIMHandleInput(MUIMSessionHandle inSessionHandle, UInt32 inKeycode, unsigned char inCharCode, UInt32 inModifiers);

void
CandClicked(UInt32 inRow);

void
GetPreeditSegment(PreeditSegment *inSegment, UniCharPtr *outStr,
                  UInt32 *outLen);

void
GetPreeditString(MUIMSessionHandle inHandle, UniCharPtr *outStr,
                 UInt32 *outLen, UInt32 *outCursorPos);

void
DumpString(const char *name, const char *str, int len);

void
BlockUpdatePreedit();

void
UnblockUpdatePreedit();

#endif // MUIM_h
