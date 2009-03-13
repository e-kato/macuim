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

#include "MUIM.h"
#include "MUIMInputEvents.h"
#include "CandidateCarbon.h"


extern uim_context gUC;

extern int gCandTransparency;

extern CFStringRef gCandFont;
extern float gCandFontSize;


static Boolean
TrimIndex(MUIMSessionHandle inHandle);

static void
UpdateCandidate(MUIMSessionHandle inHandle);

static OSStatus 
HandleBundleCommand(int commandID);

#pragma mark -

void
LayoutCandidate(MUIMSessionHandle inHandle)
{
  TSMStat tsmStat;
  OSErr err = noErr;

  if ((*inHandle)->fWindowOpened != true) return;
  
  // get the cursor position
  err = MUIMGetTSMStatus(inHandle, &tsmStat);

#if DEBUG_CANDIDATES
  DEBUG_PRINT("LayoutCandidate() tsmStat.fReplyPoint: v=%d h=%d\n",
              tsmStat.fReplyPoint.v, tsmStat.fReplyPoint.h);
  DEBUG_PRINT("LayoutCandidate() tsmStat.fReplyFont=%ld\n",
              tsmStat.fReplyFont);
  //DEBUG_PRINT("LayoutCandidate() tsmStat.fReplyPointSize=%ld\n",
  //            tsmStat.fReplyPointSize);
  DEBUG_PRINT("LayoutCandidate() tsmStat.fReplyLineHeight=%d\n",
              tsmStat.fReplyLineHeight);
#endif
 
  ShowCandidateWindow(inHandle, &tsmStat);
}

OSStatus
InitCandidateWindow(MUIMSessionHandle inHandle)
{
  OSStatus res = noErr;
  CFBundleRef appBundle = NULL;
  CFURLRef baseURL = NULL;
  CFURLRef baseURL2 = NULL;
  CFURLRef bundleURL = NULL;
  CFURLRef bundleURL2 = NULL;
  OSStatus (*initPtr)(void *);

  if ((*inHandle)->fBundleRef) return noErr;

  appBundle = CFBundleGetMainBundle();
  require(appBundle, CantFindMainBundle);
    
  //baseURL = CFBundleCopyPrivateFrameworksURL(appBundle);
  baseURL =
    CFURLCreateWithString(NULL,
                          CFSTR("/Library/Components/MacUIM.component/Contents/Frameworks/"),
                          NULL);
  baseURL2 =
    CFURLCreateWithString(NULL,
                          CFSTR("/Library/Frameworks/"),
                          NULL);
  require(baseURL, CantCopyURL);
  require(baseURL2, CantCopyURL);

  bundleURL =
    CFURLCreateCopyAppendingPathComponent(kCFAllocatorSystemDefault, baseURL,
                                          CFSTR("CocoaWinController.bundle"),
                                          false);
  require(bundleURL, CantCreateBundleURL);

  bundleURL2 =
    CFURLCreateCopyAppendingPathComponent(kCFAllocatorSystemDefault, baseURL2,
                                          CFSTR("CocoaWinController.bundle"),
                                          false);
  require(bundleURL2, CantCreateBundleURL);

  (*inHandle)->fBundleRef = CFBundleCreate(NULL, bundleURL);
  if (!((*inHandle)->fBundleRef))
    (*inHandle)->fBundleRef = CFBundleCreate(NULL, bundleURL2);
  require((*inHandle)->fBundleRef, CantCreateBundle);
                

  // call function to initialize bundle
  initPtr = CFBundleGetFunctionPointerForName((*inHandle)->fBundleRef,
                                              CFSTR("initializeBundle"));
  require(initPtr, CantFindFunction);

  res = (*initPtr)(HandleBundleCommand);
  require_noerr(res, CantInitializeBundle);
  
  SetCandidateFont(inHandle, gCandFont, gCandFontSize);
                
 CantCreateBundleURL:
 CantCreateBundle:
 CantCopyURL:
 CantFindMainBundle:
 CantFindFunction:
 CantInitializeBundle:
  if (bundleURL)
    CFRelease(bundleURL);
  if (bundleURL2)
    CFRelease(bundleURL2);
  if (baseURL)
    CFRelease(baseURL);
  if (baseURL2)
    CFRelease(baseURL2);

  return res;
}

OSStatus
ShowCandidateWindow(MUIMSessionHandle inHandle,
                    TSMStat *inTSMStat)
{
  OSStatus res = noErr;
  UInt32 i;
  OSStatus (*showPtr)(SInt16, SInt16, SInt16, SInt16);
  OSStatus (*pagePtr)(int, int);

  if (!(*inHandle)->fBundleRef) return noErr;

  TrimIndex(inHandle);

  /* XXX: Consider if display_limit == 0 */
  for (i = 0;
       i < NR_CANDIDATES && i < (*inHandle)->fDisplayLimit; i++) {
    if (i < (*inHandle)->fNRCandidates - (*inHandle)->fLayoutBegin) {
      char *newCandStr;
      UniCharPtr newCandUni = NULL;
      UniCharPtr oldCandUni = NULL;
      CFMutableStringRef cfStr;
      int len;
      UniCharPtr (*getCandPtr)(UInt32);
      uim_candidate newCand =
        uim_get_candidate((*inHandle)->fUC,
                          (*inHandle)->fLayoutBegin + i, i);
      if (!newCand) return noErr;
      
      newCandStr = (char *) uim_candidate_get_cand_str(newCand);
      cfStr = CFStringCreateMutable(NULL, 0);
      CFStringAppendCString(cfStr, newCandStr, kCFStringEncodingUTF8);
      len = CFStringGetLength(cfStr);
      newCandUni = (UniCharPtr) malloc(sizeof(UniChar) * (len + 1));
      CFStringGetCharacters(cfStr, CFRangeMake(0, len), newCandUni);
      CFRelease(cfStr);

      getCandPtr = CFBundleGetFunctionPointerForName((*inHandle)->fBundleRef,
                                                     CFSTR("getCandidate"));
      if (getCandPtr)
        oldCandUni = (*getCandPtr)(i);
      else
        oldCandUni = NULL;

      /* Checking old cand and new cand is the same or not. If not, call update. 
        Caching new result is good idea for speed up and should be implement. */
      if (!oldCandUni
          //|| strcmp(newCandUni, oldCandUni) != 0
          ) {
        UpdateCandidate(inHandle);
        uim_candidate_free(newCand);
        break;
      }

      uim_candidate_free(newCand);
      free(oldCandUni);
      free(newCandUni);
    }
  }

  if ((*inHandle)->fCandidateIndex >= 0) {
    OSStatus (*selectPtr)(int);
    selectPtr = CFBundleGetFunctionPointerForName((*inHandle)->fBundleRef,
                                                  CFSTR("selectCandidate"));
    if (selectPtr)
      res = (*selectPtr)((*inHandle)->fCandidateIndex -
                         (*inHandle)->fLayoutBegin);

    pagePtr = CFBundleGetFunctionPointerForName((*inHandle)->fBundleRef,
                                                CFSTR("setPage"));
    if (pagePtr)
      res = (*pagePtr)((*inHandle)->fCandidateIndex + 1,
                       (*inHandle)->fNRCandidates);
  }
  else {
    OSStatus (*deselectPtr)();
    deselectPtr = CFBundleGetFunctionPointerForName((*inHandle)->fBundleRef,
                                                  CFSTR("deselectCandidate"));
    if (deselectPtr)
      res = (*deselectPtr)();

    pagePtr = CFBundleGetFunctionPointerForName((*inHandle)->fBundleRef,
                                                CFSTR("setPage"));
    if (pagePtr)
      res = (*pagePtr)(0, (*inHandle)->fNRCandidates);
  }

  // call function to show window
  showPtr = CFBundleGetFunctionPointerForName((*inHandle)->fBundleRef,
                                              CFSTR("orderWindowFront"));
  if (showPtr)
    res = (*showPtr)(inTSMStat->fReplyPoint.h,
                     inTSMStat->fReplyPoint.v,
                     inTSMStat->fReplyLineHeight,
                     gCandTransparency);

  //(*inHandle)->fWindowOpened = true;

  return res;
}

OSStatus
HideCandidateWindow(MUIMSessionHandle inHandle)
{
  OSStatus res = noErr;
  OSStatus (*hidePtr)();

  if (!(*inHandle)->fBundleRef)
    return noErr;

  // call function to hide window
  hidePtr = CFBundleGetFunctionPointerForName((*inHandle)->fBundleRef,
                                              CFSTR("orderWindowBack"));

  if (hidePtr)
    res = (*hidePtr)();

  //(*inHandle)->fWindowOpened = false;

  return res;
}

Boolean
CandidateWindowIsVisible(MUIMSessionHandle inHandle)
{
  Boolean res = false;
  OSStatus (*visiblePtr)();
  
  if (!(*inHandle)->fBundleRef)
    return noErr;
  
  // call function to hide window
  visiblePtr = CFBundleGetFunctionPointerForName((*inHandle)->fBundleRef,
                                              CFSTR("windowIsVisible"));
  
  if (visiblePtr)
    res = (*visiblePtr)();
  
  return res;
}

static Boolean
TrimIndex(MUIMSessionHandle inHandle)
{
  Boolean changed = false;

  if ((*inHandle)->fDisplayLimit != 0) {
    while ((*inHandle)->fLayoutBegin + (*inHandle)->fDisplayLimit
           <= (*inHandle)->fCandidateIndex) {
      changed = true;
      (*inHandle)->fLayoutBegin += (*inHandle)->fDisplayLimit;
    }  
    while ((*inHandle)->fLayoutBegin > (*inHandle)->fCandidateIndex) {
      changed = true;
      (*inHandle)->fLayoutBegin -= (*inHandle)->fDisplayLimit;
    }
    if ((*inHandle)->fLayoutBegin < 0) {
      changed = true;
      (*inHandle)->fLayoutBegin = 0;
    }
  }
  else {
    while ((*inHandle)->fLayoutBegin + NR_CANDIDATES
           <= (*inHandle)->fCandidateIndex) {
      changed = true;
      (*inHandle)->fLayoutBegin = NR_CANDIDATES;
    }  
    while ((*inHandle)->fLayoutBegin > (*inHandle)->fCandidateIndex) {
      changed = true;
      (*inHandle)->fLayoutBegin -= NR_CANDIDATES;
    }
    if ((*inHandle)->fLayoutBegin < 0) {
      changed = true;
      (*inHandle)->fLayoutBegin = 0;
    }
  }

  return changed;
}

static void
UpdateCandidate(MUIMSessionHandle inHandle)
{
  OSStatus res = noErr;
  int i;
  OSStatus (*clearCandPtr)();
  OSStatus (*addCandPtr)(UniCharPtr, int, UniCharPtr, int);
  
  clearCandPtr = CFBundleGetFunctionPointerForName((*inHandle)->fBundleRef,
                                                   CFSTR("clearCandidate"));

  if (clearCandPtr)
    res = (*clearCandPtr)();

  /* XXX: Consider if display_limit == 0 */
  for (i = 0;
       i < NR_CANDIDATES && i < (*inHandle)->fDisplayLimit; i++) {
    if (i < (*inHandle)->fNRCandidates - (*inHandle)->fLayoutBegin) {
      char *headStr, *candStr;
      CFMutableStringRef cfStr;
      int headLen, candLen;
      UniCharPtr headUni, candUni;
      uim_candidate cand =
        uim_get_candidate((*inHandle)->fUC,
                          (*inHandle)->fLayoutBegin + i, i);
      headStr = (char *) uim_candidate_get_heading_label(cand);
      candStr = (char *) uim_candidate_get_cand_str(cand);

      if (headStr && candStr) {
        cfStr = CFStringCreateMutable(NULL, 0);
        CFStringAppendCString(cfStr, headStr, kCFStringEncodingUTF8);
        headLen = CFStringGetLength(cfStr);
        headUni = (UniCharPtr) malloc(sizeof(UniChar) * (headLen + 1));
        CFStringGetCharacters(cfStr, CFRangeMake(0, headLen), headUni);
        CFRelease(cfStr);

        cfStr = CFStringCreateMutable(NULL, 0);
        CFStringAppendCString(cfStr, candStr, kCFStringEncodingUTF8);
        candLen = CFStringGetLength(cfStr);
        candUni = (UniCharPtr) malloc(sizeof(UniChar) * (candLen + 1));
        CFStringGetCharacters(cfStr, CFRangeMake(0, candLen), candUni);
        CFRelease(cfStr);

        if (headUni && candUni) {
          addCandPtr = CFBundleGetFunctionPointerForName((*inHandle)->fBundleRef,
                                                         CFSTR("addCandidate"));
          if (addCandPtr)
            res = (*addCandPtr)(headUni, headLen, candUni, candLen);
        }
      }
      uim_candidate_free(cand);
    }
    else {
      addCandPtr = CFBundleGetFunctionPointerForName((*inHandle)->fBundleRef,
                                                     CFSTR("addCandidate"));
      if (addCandPtr)
        res = (*addCandPtr)(NULL, 0, NULL, 0);
    }
  }
}

OSStatus
SetCandidateFont(MUIMSessionHandle inHandle, CFStringRef name, float size)
{
  OSStatus res = noErr;
  OSStatus (*funcPtr)(CFStringRef, float);
  
  if (!(*inHandle)->fBundleRef)
    return noErr;
  
  funcPtr = CFBundleGetFunctionPointerForName((*inHandle)->fBundleRef,
                                              CFSTR("setFont"));
  
  if (funcPtr)
    res = (*funcPtr)(name, size);
  
  return res;
}

#pragma mark -

OSStatus
ShowModeTips(MUIMSessionHandle inHandle, CFArrayRef inLines)
{
  OSStatus res = noErr;
  OSStatus (*showPtr)(SInt16, SInt16, SInt16, CFArrayRef);
  TSMStat tsmStat;
  
  //DEBUG_PRINT("ShowModeTips()\n");

  //(*inHandle)->fModeTipsBlock = TRUE;
  
  // get the cursor position
  res = MUIMGetTSMStatus(inHandle, &tsmStat);
  
  if (!(*inHandle)->fBundleRef)
    return noErr;
  
  showPtr = CFBundleGetFunctionPointerForName((*inHandle)->fBundleRef,
                                              CFSTR("showModeTips"));
  
  if (showPtr)
    res = (*showPtr)(tsmStat.fReplyPoint.h,
                     tsmStat.fReplyPoint.v,
                     tsmStat.fReplyLineHeight,
                     inLines);
  
  return res;
}

#if 0
OSStatus
ShowLastModeTips(MUIMSessionHandle inHandle)
{
  OSStatus res = noErr;
  
  CFArrayRef array =
    CFStringCreateArrayBySeparatingStrings(kCFAllocatorDefault,
                                           (*inHandle)->fLastModeTips, CFSTR("\n"));
  if (array) {
    res = ShowModeTips(inHandle, array);
    CFRelease(array);
  }
  
  return res;
}
#endif

OSStatus
HideModeTips(MUIMSessionHandle inHandle)
{
  OSStatus res = noErr;
  OSStatus (*hidePtr)();
  
  if (!(*inHandle)->fBundleRef)
    return noErr;
  
  hidePtr = CFBundleGetFunctionPointerForName((*inHandle)->fBundleRef,
                                              CFSTR("hideModeTips"));
  
  if (hidePtr)
    res = (*hidePtr)();
  
  return res;
}

#pragma mark -

static OSStatus 
HandleBundleCommand(int inRow)
{
  OSStatus res = noErr;

#if DEBUG_CANDIDATES
  DEBUG_PRINT("HandleBundleCommand() inRow=%d\n", inRow);
#endif

  CandClicked(inRow);

#if 0
  if (commandID == kEventCandClicked) {
    OSStatus (*funcPtr)(CFStringRef message);

    funcPtr = CFBundleGetFunctionPointerForName(fBundleRef, CFSTR("changeText"));
    require(funcPtr, CantFindFunction);
    res = (*funcPtr)(CFSTR("button pressed!"));
    require_noerr(osStatus, CantCallFunction);
  }
 CantFindFunction:
 CantCallFunction:
#endif

  return res;
}
