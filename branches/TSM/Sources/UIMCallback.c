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

#include <uim.h>
#include <uim-helper.h>
#include <uim-im-switcher.h>

#include "MUIM.h"
#include "MUIMInputEvents.h"
#include "UIMCallback.h"
#include "CandidateCarbon.h"

extern MUIMSessionHandle gActiveSession;
extern int gNumSession;
extern MUIMSessionHandle *gSessionList;

extern MenuRef gPencilMenu;

#ifdef SYNC_MODE
extern SInt32 gMode;
#endif

#ifdef NEW_HELPER
extern Boolean gUimHelperConnected;
#else
extern int gUimFD;
#endif
extern CFSocketRef gUimSock;
extern CFRunLoopSourceRef gUimRun;
extern CFSocketContext gSockContext;

extern Boolean gActiveProp;

extern Boolean gEnableModeTips;
extern Boolean gCandVertical;

static Boolean gBlockUpdatePreedit = false;

#pragma mark -

static void
AddPreeditSegment(MUIMSessionHandle inHandle, int inAttr,
                  const char *inStr);

static void
HelperRead(CFSocketRef sock, CFSocketCallBackType callbackType, 
           CFDataRef address, const void *data, void *info);

static void
ParseHelperString(const char *str);

static void
ParseIMChangeString(const char *str);

#pragma mark -

void
UIMCommitString(void *ptr, const char *str)
{
  MUIMSessionHandle handle = (MUIMSessionHandle) ptr;
  //MUIMSessionHandle handle = gActiveSession;
  CFMutableStringRef cf_string;
  
  if (!handle || !(*handle)) return;

  cf_string = CFStringCreateMutable(NULL, 0);
  CFStringAppendCString(cf_string, str, kCFStringEncodingUTF8);

  (*handle)->fFixLen = CFStringGetLength(cf_string);
  (*handle)->fFixBuffer =
    (UniCharPtr) malloc(sizeof(UniChar) * ((*handle)->fFixLen + 1));
  CFStringGetCharacters(cf_string, CFRangeMake(0, (*handle)->fFixLen),
                        (*handle)->fFixBuffer);
  CFRelease(cf_string);

#if DEBUG_PREEDIT
  DEBUG_PRINT("UIMCommitString() len=%d fFixLen=%lu\n",
              strlen(str), (*handle)->fFixLen);
#endif

  if ((*handle)->fFixLen > 0) {
    MUIMUpdateActiveInputArea(handle, TRUE);
    free((*handle)->fFixBuffer);
    (*handle)->fFixBuffer = NULL;
    (*handle)->fFixLen = 0;
  }
}


void
UIMPreeditClear(void *ptr)
{
  MUIMSessionHandle handle = (MUIMSessionHandle) ptr;
  //MUIMSessionHandle handle = gActiveSession;
  UInt32 i;

#if DEBUG_PREEDIT
  DEBUG_PRINT("UIMPreeditClear()\n");
#endif
  
  if (!handle || !(*handle)) return;

  for (i = 0; i < (*handle)->fSegmentCount; i++)
    free((*handle)->fSegments[i].fBuffer);

  free((*handle)->fSegments);
  (*handle)->fSegments = NULL;
  (*handle)->fSegmentCount = 0;
}

void
UIMPreeditPushback(void *ptr, int attr, const char *str)
{
  MUIMSessionHandle handle = (MUIMSessionHandle) ptr;
  //MUIMSessionHandle handle = gActiveSession;

  if (!handle || !(*handle)) return;
  
#if DEBUG_PREEDIT
  {
    char attrstr[50] = { ' ', '\0' };

    if (attr & UPreeditAttr_None)
      strcpy(attrstr, "None");
    if (attr & UPreeditAttr_UnderLine)
      strcat(attrstr, " UnderLine");
    if (attr & UPreeditAttr_Reverse)
      strcat(attrstr, " Reverse");
    if (attr & UPreeditAttr_Cursor)
      strcat(attrstr, " Cursor");
    if (attr & UPreeditAttr_Separator)
      strcat(attrstr, " Separator");

    DEBUG_PRINT("UIMPreeditPushback() fSegmentCount=%lu attr=%s len=%lu str='%s'\n",
                (*handle)->fSegmentCount,
                attrstr, strlen(str), str);
  }
#endif

  AddPreeditSegment(handle, attr, str);
}

void
UIMPreeditUpdate(void *ptr)
{
  MUIMSessionHandle handle = (MUIMSessionHandle) ptr;
  //MUIMSessionHandle handle = gActiveSession;

  if (!handle || !(*handle)) return;
  
#if DEBUG_PREEDIT
  DEBUG_PRINT("UIMPreeditUpdate()\n");
#endif

  // Avoid a crash when Firefox is launched with uim(Japanese)
  if (!gBlockUpdatePreedit)
    MUIMUpdateActiveInputArea(handle, false);
}

/**
 * Candidate window activate callback
 */
void
UIMCandAcivate(void *inPtr, int inNR, int inLimit)
{
  MUIMSessionHandle handle = (MUIMSessionHandle) inPtr;
  //MUIMSessionHandle handl/e = gActiveSession;

  if (!handle || !(*handle)) return;
  
#if DEBUG_CANDIDATES
  DEBUG_PRINT("UIMCandAcivate() inNR=%d inLimit=%d\n", inNR, inLimit);
#endif

  //InitCandidateWindow(handle);

  (*handle)->fIsActive = true;
  (*handle)->fCandidateIndex = -1;
  (*handle)->fPageIndex = -1;
  (*handle)->fNRCandidates = inNR;
  (*handle)->fDisplayLimit = inLimit;
  (*handle)->fLayoutBegin = 0;

  (*handle)->fWindowOpened = true;

  LayoutCandidate(handle);
}

/**
 * Candidate window select callback
 */
void
UIMCandSelect(void *inPtr, int inIndex)
{
  MUIMSessionHandle handle = (MUIMSessionHandle) inPtr;
  //MUIMSessionHandle handle = gActiveSession;

  if (!handle || !(*handle)) return;
  
#if DEBUG_CANDIDATES
  DEBUG_PRINT("UIMCandSelect() inIndex=%d\n", inIndex);
#endif

  (*handle)->fCandidateIndex = inIndex;
  (*handle)->fPageIndex = (*handle)->fCandidateIndex / (*handle)->fDisplayLimit;

  LayoutCandidate(handle);
}

/**
 * Candidate window page shift callback
 */
void
UIMCandShiftPage(void *inPtr, int inForward)
{
  MUIMSessionHandle handle = (MUIMSessionHandle) inPtr;
  //MUIMSessionHandle handle = gActiveSession;
  
  if (!handle || !(*handle)) return;

  if (inForward) { // next page
    if ((*handle)->fNRCandidates <=
        (*handle)->fCandidateIndex + (*handle)->fDisplayLimit) {
      // if the next page is not exist
      // move to top page and select first candidate
      (*handle)->fCandidateIndex = 0;
      (*handle)->fPageIndex = 0;
    }
    else {
      // move to next page
      (*handle)->fCandidateIndex += (*handle)->fDisplayLimit;
      (*handle)->fPageIndex++;
    }
  }
  else { // previous page
    if ((*handle)->fCandidateIndex - (*handle)->fDisplayLimit < 0) {
      // if the previous page is not exist
      // move to buttom page and select last candidate
      (*handle)->fCandidateIndex = (*handle)->fNRCandidates - 1;
      (*handle)->fPageIndex = (*handle)->fNRCandidates
        / (*handle)->fDisplayLimit
        + (((*handle)->fNRCandidates % (*handle)->fDisplayLimit) ? 1 : 0) - 1;
    }
    else {
      (*handle)->fCandidateIndex -= (*handle)->fDisplayLimit;
      (*handle)->fPageIndex--;
    }
  }

#if DEBUG_CANDIDATES
  DEBUG_PRINT("UIMCandShiftPage() inForward=%d fCandidateIndex=%ld\n",
              inForward, (*handle)->fCandidateIndex);
#endif

  LayoutCandidate(handle);
  uim_set_candidate_index((*handle)->fUC, (*handle)->fCandidateIndex);
}

/**
 * Candidate window deactivate callback
 */
void
UIMCandDeactivate(void *inPtr)
{
  MUIMSessionHandle handle = (MUIMSessionHandle) inPtr;
  //MUIMSessionHandle handle = gActiveSession;

  if (!handle || !(*handle)) return;
  
#if DEBUG_CANDIDATES
  DEBUG_PRINT("UIMCandDeactivate()\n");
#endif

  HideCandidateWindow(handle);
  (*handle)->fWindowOpened = false;
}

char *
get_caret_state_label_from_prop_list(const char *str)
{
  const char *p, *q;
  char *state_label = NULL;
  char label[10];
  int len, state_label_len = 0;

  p = str;
  while ((p = strstr(p, "branch\t"))) {
    if ((p = strchr(p + 7, '\t'))) {
      p++;
      q = strchr(p, '\t');
      len = q - p;
      if (q && len < 10) {
        strncpy(label, p, len);
        label[len] = '\0';
        if (!state_label) {
          state_label_len = len;
          state_label = strdup(label);
        }
        else {
          state_label_len += (len + 1);
          state_label = (char *) realloc(state_label, state_label_len + 1);
          if (state_label) {
            strcat(state_label, "\t");
            strcat(state_label, label);
            state_label[state_label_len] = '\0';
          }
        }
      }
    }
  }

  return state_label;
}

void
UIMUpdatePropList(void *inPtr, const char *inStr)
{
  MUIMSessionHandle handle = (MUIMSessionHandle) inPtr;
  //MUIMSessionHandle handle = gActiveSession;
  char *tmp;
  
  if (!handle || !(*handle)) return;
  if (!gActiveSession || !gPencilMenu || !gActiveProp) return;
  if (gActiveSession != handle) return;

  tmp = (char *) malloc(sizeof(char) *
                        (strlen(kPropListUpdate) + 1 +
                         strlen(inStr) + 1));
  if (tmp) {
#ifdef NEW_HELPER
    if (gUimHelperConnected)
#else
    if (gUimFD >= 0)
#endif
    {
      snprintf(tmp, strlen(kPropListUpdate) + 1 + strlen(inStr) + 1,
               "%s\n%s",
               kPropListUpdate, inStr);
#ifdef NEW_HELPER
      uim_helper_send_message(tmp);
#else
      uim_helper_send_message(gUimFD, tmp);
#endif
    }
    free(tmp);
  }

  if (gEnableModeTips
      && !(*handle)->fModeTipsBlock
      ) {
    char *label = get_caret_state_label_from_prop_list(inStr);;
    CFStringRef allstr =
      CFStringCreateWithCString(kCFAllocatorDefault,
                                label, kCFStringEncodingUTF8);
    free(label);
    if (!allstr) return;
    
    CFArrayRef array =
      CFStringCreateArrayBySeparatingStrings(kCFAllocatorDefault,
                                             allstr, CFSTR("\t"));
    CFRelease(allstr);
    if (array) {
      ShowModeTips(handle, array);
      CFRelease(array);
    }
  }
}

void
UIMUpdatePropLabel(void *inPtr, const char *inStr)
{
  MUIMSessionHandle handle = (MUIMSessionHandle) inPtr;
  //MUIMSessionHandle handle = gActiveSession;
  char *tmp;

  if (!handle || !(*handle)) return;

#if DEBUG_HELPER
  DEBUG_PRINT("UIMUpdatePropLabel() time=%f handle=%p gActiveSession=%p\n",
              GetCurrentEventTime(),
              handle, gActiveSession);
#endif

  if (!gActiveSession || !gPencilMenu || !gActiveProp) return;

  if (gActiveSession != handle)
    return;

  tmp = (char *) malloc(sizeof(char) *
                        (strlen(kPropLabelUpdate) + 1 +
                         strlen(inStr) + 1));
  if (tmp) {
#if NEW_HELPER
    if (gUimHelperConnected)
#else
    if (gUimFD >= 0)
#endif
    {
      snprintf(tmp, strlen(kPropLabelUpdate) + 1 + strlen(inStr) + 1,
               "%s\n%s",
               kPropLabelUpdate, inStr);
#ifdef NEW_HELPER
      uim_helper_send_message(tmp);
#else
      uim_helper_send_message(gUimFD, tmp);
#endif
    }
    free(tmp);
  }

  if (gEnableModeTips && !(*handle)->fModeTipsBlock) {
    CFStringRef allstr =
      CFStringCreateWithCString(kCFAllocatorDefault,
                                inStr, kCFStringEncodingUTF8);
    if (!allstr) return;
    
    CFArrayRef array =
      CFStringCreateArrayBySeparatingStrings(kCFAllocatorDefault,
                                             allstr, CFSTR("\n"));
    CFRelease(allstr);
    if (array) {
      ShowModeTips(handle, array);
      CFRelease(array);
    }
  }
}

void
UIMCheckHelper()
{
#ifdef NEW_HELPER
  if (!gUimHelperConnected) {
    if (uim_helper_init_client(UIMHelperDisconnect) == 0) {
      gUimHelperConnected = TRUE;

#if DEBUG_HELPER
      DEBUG_PRINT("UIMCheckHelper() gUimHelperConnected=%d\n",
                  gUimHelperConnected);
#endif

      if (gUimHelperConnected) {
        if (!gUimSock) {
          gSockContext.version = 0;
          gSockContext.info = NULL;
          gSockContext.retain = NULL;
          gSockContext.release = NULL;
          gSockContext.copyDescription = NULL;
          
          gUimSock = CFSocketCreateWithNative(kCFAllocatorDefault,
                                              uim_helper_get_client_fd(),
                                              kCFSocketReadCallBack,
                                              HelperRead,
                                              &gSockContext);
          if (!gUimSock) return;
        }

        if (!gUimRun) {
          gUimRun = CFSocketCreateRunLoopSource(kCFAllocatorDefault,
                                                gUimSock, 0);
          if (!gUimRun) {
            CFRelease(gUimSock);
            gUimSock = NULL;
            return;
          }
          CFRunLoopAddSource(CFRunLoopGetCurrent(), gUimRun,
                             kCFRunLoopDefaultMode);
#if DEBUG_HELPER
          DEBUG_PRINT("UIMCheckHelper() CFRunLoopGetCurrent()\n");
#endif
        }
      }
    }
  }

#else // NEW_HELPER

  if (gUimFD < 0) {
    gUimFD = uim_helper_init_client_fd(UIMHelperDisconnect);

#if DEBUG_HELPER
    DEBUG_PRINT("UIMCheckHelper() gUimFD=%d(%p)\n", gUimFD, &gUimFD);
#endif

    if (gUimFD >= 0) {
      if (!gUimSock) {
        gSockContext.version = 0;
        gSockContext.info = NULL;
        gSockContext.retain = NULL;
        gSockContext.release = NULL;
        gSockContext.copyDescription = NULL;

        gUimSock = CFSocketCreateWithNative(kCFAllocatorDefault, gUimFD,
                                            kCFSocketReadCallBack, HelperRead,
                                            &gSockContext);
        if (!gUimSock) return;
      }

      if (!gUimRun) {
        gUimRun = CFSocketCreateRunLoopSource(kCFAllocatorDefault, gUimSock, 0);
        if (!gUimRun) {
          CFRelease(gUimSock);
          gUimSock = NULL;
          return;
        }
        CFRunLoopAddSource(CFRunLoopGetCurrent(), gUimRun,
                           kCFRunLoopDefaultMode);
#if DEBUG_HELPER
        DEBUG_PRINT("UIMCheckHelper() CFRunLoopGetCurrent()\n");
#endif
      }
    }
  }
#endif
}

static void
HelperRead(CFSocketRef sock, CFSocketCallBackType callbackType, 
           CFDataRef address, const void *data, void *info)
{
  char *tmp;

#if DEBUG_HELPER
  DEBUG_PRINT("HelperRead()\n");
#endif

  uim_helper_read_proc(CFSocketGetNative(sock));
  while ((tmp = uim_helper_get_message())) {
    ParseHelperString(tmp);
    free(tmp);
  }
}

static void
ParseHelperString(const char *str)
{
  UInt32 i;

#if DEBUG_HELPER
  DEBUG_PRINT("ParseHelperString() str='%s'\n", str);
#endif

  if (!gActiveSession) return;

  if (strncmp("im_change", str, 9) == 0) {
    if (gActiveProp)
      ParseIMChangeString(str);
  }
  else if (strncmp("prop_list_get", str, 13) == 0) {
    if (gActiveProp)
      uim_prop_list_update((*gActiveSession)->fUC);
  }
  else if (strncmp("prop_label_get", str, 14) == 0) {
    if (gActiveProp)
      uim_prop_label_update((*gActiveSession)->fUC);
  }
  else if (strncmp("prop_activate", str, 13) == 0 &&
		  gActiveProp) {
    CFMutableStringRef cfstr;
    CFArrayRef array;
    CFStringRef first;

    cfstr = CFStringCreateMutable(NULL, 0);
    CFStringAppendCString(cfstr, str, kCFStringEncodingUTF8);

    array = CFStringCreateArrayBySeparatingStrings(kCFAllocatorDefault,
                                                   cfstr, CFSTR("\n"));

    if (array && CFArrayGetCount(array) > 0 &&
        (first = CFArrayGetValueAtIndex(array, 0))) {
      CFStringRef second = CFArrayGetValueAtIndex(array, 1);     
      if (second) {
        char how[64];
        CFStringGetCString(second, how, 64, kCFStringEncodingUTF8);
        BlockUpdatePreedit();
        for (i = 0; i < gNumSession; i++)
          uim_prop_activate((*gSessionList[i])->fUC, how);
        UnblockUpdatePreedit();
      }
    }
    CFRelease(array);
    CFRelease(cfstr);
  }
  else if (strncmp("prop_list_update", str, 16) == 0) {
  }
  else if (strncmp("prop_label_update", str, 17) == 0) {
  }
  else if (strncmp("focus_in", str, 8) == 0) {
    gActiveProp = false;
  }
}

static void
ParseIMChangeString(const char *str)
{
  UInt32 i;
  char *eol, *im;
  
  eol = strchr(str, '\n');
  if (eol == NULL) return;
  im = eol + 1;
  eol = strchr(im, '\n');
  if (eol == NULL) return;
  *eol = '\0';
  
  for (i = 0; i < gNumSession; i++)
    uim_switch_im((*gSessionList[i])->fUC, im);
}

void
UIMHelperDisconnect()
{
#if DEBUG_HELPER
  DEBUG_PRINT("UIMHelperDisconnect()\n");
#endif

  CFRunLoopRemoveSource(CFRunLoopGetCurrent(), gUimRun, kCFRunLoopDefaultMode);

  CFRelease(gUimRun);
  CFRelease(gUimSock);

  gUimRun = NULL;
  gUimSock = NULL;

#ifdef NEW_HELPER
  gUimHelperConnected = false;
#else
  gUimFD = -1;
#endif
}

void
UIMHelperClose()
{
#if DEBUG_HELPER
  DEBUG_PRINT("UIMHelperClose()\n");
#endif

#ifdef NEW_HELPER
  if (gUimHelperConnected)
    uim_helper_close_client();
#else
  if (gUimFD >= 0)
    uim_helper_close_client_fd(gUimFD);
  gUimFD = -1;
#endif
}

#ifdef SYNC_MODE
void
UIMModeUpdate(void *inPtr, int inMode)
{
  MUIMSessionHandle handle = (MUIMSessionHandle) inPtr;
  //MUIMSessionHandle handle = gActiveSession;
  
  if (!handle || !(*handle)) return;

#if DEBUG_SYNCMODE
  DEBUG_PRINT("UIMModeUpdate() gMode=%d inMode=%d\n", gMode, inMode);
#endif

  gMode = inMode;
}
#endif

#pragma mark -

static void
AddPreeditSegment(MUIMSessionHandle inHandle, int inAttr,
                  const char *inStr)
{
  CFMutableStringRef cf_string;
  int len;
  UniCharPtr unistr;

  cf_string = CFStringCreateMutable(NULL, 0);
  CFStringAppendCString(cf_string, inStr, kCFStringEncodingUTF8);

  len = CFStringGetLength(cf_string);
  unistr = (UniCharPtr) malloc(sizeof(UniChar) * (len + 1));
  CFStringGetCharacters(cf_string, CFRangeMake(0, len), unistr);

  (*inHandle)->fSegments = realloc((*inHandle)->fSegments,
                                   sizeof(PreeditSegment) *
                                   ((*inHandle)->fSegmentCount + 1));
  (*inHandle)->fSegments[(*inHandle)->fSegmentCount].fBuffer = unistr;
  (*inHandle)->fSegments[(*inHandle)->fSegmentCount].fLength = len;
  (*inHandle)->fSegments[(*inHandle)->fSegmentCount].fAttr = inAttr;
  (*inHandle)->fSegmentCount++;

  CFRelease(cf_string);
}

void
GetPreeditSegment(PreeditSegment *inSegment, UniCharPtr *outStr,
                  UInt32 *outLen)
{
  UniCharPtr tmp = (UniCharPtr) malloc(sizeof(UniChar) * (*outLen + 1));
  memcpy(tmp, *outStr, sizeof(UniChar) * (*outLen));

#if DEBUG_PREEDIT
  DEBUG_PRINT("GetPreeditSegment() outLen=%lu, fLength=%lu\n",
              *outLen, inSegment->fLength);
#endif

  if (inSegment->fLength > 0) {
    (*outStr) = (UniCharPtr) realloc(*outStr, sizeof(UniChar) *
                                     ((*outLen) + inSegment->fLength + 1));

    memcpy(*outStr, tmp, sizeof(UniChar) * (*outLen));
    memcpy(&((*outStr)[(*outLen)]),
           inSegment->fBuffer, sizeof(UniChar) * inSegment->fLength);
    *outLen += inSegment->fLength;
  }

  free(tmp);
}

void
GetPreeditString(MUIMSessionHandle inHandle, UniCharPtr *outStr,
                 UInt32 *outLen, UInt32 *outCursorPos)
{
  UniCharPtr str;
  UInt32 i, pos = 0, len = 0;

  str = (UniCharPtr) malloc(sizeof(UniChar));
  str[0] = '\0';

#if DEBUG_PREEDIT
  DEBUG_PRINT("GetPreeditString() fSegmentCount=%lu\n",
              (*inHandle)->fSegmentCount);
#endif

  for (i = 0; i < (*inHandle)->fSegmentCount; i++) {
    GetPreeditSegment(&((*inHandle)->fSegments[i]), &str, &len);
    if ((*inHandle)->fSegments[i].fAttr & UPreeditAttr_Cursor) {
      pos = len;
    }
#if DEBUG_PREEDIT
    DEBUG_PRINT("GetPreeditString() i=%lu len=%lu\n", i, len);
#endif
  }
#if DEBUG_PREEDIT
  DEBUG_PRINT("GetPreeditString() len=%lu pos=%lu\n", len, pos);
#endif

  if (outCursorPos)
    *outCursorPos = pos;

  if (outLen)
    *outLen = len;

  if (outStr)
    *outStr = str;
  else
    free(str);
}

void
BlockUpdatePreedit()
{
  gBlockUpdatePreedit = true;
}

void
UnblockUpdatePreedit()
{
  gBlockUpdatePreedit = false;
}
