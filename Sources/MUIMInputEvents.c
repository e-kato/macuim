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

#define TARGET_API_MAC_CARBON 1

#define OLDROUTINENAMES 1

#include <Carbon/Carbon.h>

#include "MUIM.h"
#include "MUIMInputEvents.h"

static void
SegmentToHiliteRange(MUIMSessionHandle inHandle, TextRangeArrayPtr *inRange);

static UInt32
SegmentToOffset(MUIMSessionHandle inHandle);

#pragma mark -

/**
 * Create and sends an "update active input area" event to our client
 * application. We use the Carbon event manager to create a Carbon event,
 * add the appropriate parameters and send it using SendTextInputEvent.
 *
 * @param  inHandle  a reference to the active session
 * @param  inFix     if TRUE, we are fixing the entire input area
 *                   Otherwise we are just updating the contents
 *
 * @return OSStatus  a toolbox error code
 */
OSErr
MUIMUpdateActiveInputArea(MUIMSessionHandle inHandle, Boolean inFix)
{
  OSErr error;
  EventRef event;
  ComponentInstance componentInstance;
  ScriptLanguageRecord scriptLanguageRecord;
  TextRange pinRange;
  TextRangeArrayPtr hiliteRangePtr;
  TextRangeArrayPtr updateRangePtr;
  UniCharPtr str = NULL;
  UInt32 len = 0, cursorPos = 0;
  SInt32 fixLen;

  if (!inFix) {
    GetPreeditString(inHandle, &str, &len, &cursorPos);

#if DEBUG_INPUT_EVENT
    DEBUG_PRINT("MUIMUpdateActiveInputArea() inFix=%s fOldPreeditLen=%lu len=%lu cursorPos=%lu\n",
                inFix ? "true" : "false",
                (*inHandle)->fOldPreeditLen, len, cursorPos);
#endif

    if ((*inHandle)->fOldPreedit != NULL &&
        (*inHandle)->fOldPreeditLen == 0 && len == 0) {
#if DEBUG_INPUT_EVENT
      DEBUG_PRINT("MUIMUpdateActiveInputArea() does not send event\n");
#endif
      free(str);
      return noErr;
    }
    free((*inHandle)->fOldPreedit);
    (*inHandle)->fOldPreedit = str;
    (*inHandle)->fOldPreeditLen = len;
    fixLen = 0;
  }
  else {
    len = cursorPos = (*inHandle)->fFixLen;
    fixLen = len * sizeof(UniChar);
    str = (*inHandle)->fFixBuffer;
  }

  hiliteRangePtr = nil;
  updateRangePtr = nil;

  // create an event
  error =
    CreateEvent(NULL, kEventClassTextInput,
                kEventTextInputUpdateActiveInputArea,
                GetCurrentEventTime(),
                kEventAttributeUserEvent, &event);

  // set a component instance
  if (error == noErr) {
    componentInstance = (*inHandle)->fComponentInstance;
    error = SetEventParameter(event,
                              kEventParamTextInputSendComponentInstance,
                              typeComponentInstance,
                              sizeof(ComponentInstance),
                              &componentInstance);
  }

  // set a script and language type
  if (error == noErr) {
    scriptLanguageRecord.fScript = smJapanese;
    scriptLanguageRecord.fLanguage = langJapanese;
    error = SetEventParameter(event, kEventParamTextInputSendSLRec,
                              typeIntlWritingCode,
                              sizeof(ScriptLanguageRecord),
                              &scriptLanguageRecord);
  }

  // set the string
  if (error == noErr)
    error = SetEventParameter(event, kEventParamTextInputSendText,
                              typeUnicodeText,
                              len * sizeof(UniChar), str);
 
  // set the fix length
  if (error == noErr)
    error = SetEventParameter(event, kEventParamTextInputSendFixLen,
                              typeLongInteger,
                              sizeof(SInt32), &fixLen);

  // set the update range
  if (error == noErr) {
    updateRangePtr =
      (TextRangeArrayPtr) NewPtrClear(sizeof(short) +
                                      sizeof(TextRange) * 2);
    if (updateRangePtr) {
      updateRangePtr->fNumOfRanges = 2;
      updateRangePtr->fRange[0].fStart = 0;
      updateRangePtr->fRange[0].fEnd = (*inHandle)->fLastUpdateLength * sizeof(UniChar);
      updateRangePtr->fRange[0].fHiliteStyle = 0;
      updateRangePtr->fRange[1].fStart = 0;
      updateRangePtr->fRange[1].fEnd = len * sizeof(UniChar);
      updateRangePtr->fRange[1].fHiliteStyle = 0;

      (*inHandle)->fLastUpdateLength = len;
    }
    else
      error = memFullErr;
  }
  if (error == noErr)
    error = SetEventParameter(event, kEventParamTextInputSendUpdateRng,
                              typeTextRangeArray,
                              sizeof(short) + sizeof(TextRange) * 2,
                              updateRangePtr);

#if DEBUG_INPUT_EVENT
  DEBUG_PRINT("MUIMUpdateActiveInputArea() [UpdateRng] fRange[0].fStart=%d fEnd=%d fRange[1].fStart=%d fEnd=%d\n",
              updateRangePtr->fRange[0].fStart, updateRangePtr->fRange[0].fEnd,
              updateRangePtr->fRange[1].fStart, updateRangePtr->fRange[1].fEnd);
#endif

  // set the hilite range
  if (error == noErr) {
    SegmentToHiliteRange(inHandle, &hiliteRangePtr);
    if (!hiliteRangePtr)
      error = memFullErr;
  }

#if DEBUG_HILITERANGE
  {
    int i;
    for (i = 0; i < hiliteRangePtr->fNumOfRanges; i++) {
      DEBUG_PRINT("MUIMUpdateActiveInputArea() [HiliteRng] fRange[%d].fStart=%d fEnd=%d fHiliteStyle=%d\n",
                  i, hiliteRangePtr->fRange[i].fStart, hiliteRangePtr->fRange[i].fEnd,
                  hiliteRangePtr->fRange[i].fHiliteStyle);
    }
  }
#endif

  if (error == noErr)
    error = SetEventParameter(event, kEventParamTextInputSendHiliteRng,
                              typeTextRangeArray,
                              sizeof(short) + sizeof(TextRange) * hiliteRangePtr->fNumOfRanges,
                              hiliteRangePtr);

  pinRange.fStart = 0;
  pinRange.fEnd = len * sizeof(UniChar);
  if (error == noErr)
    error = SetEventParameter(event, kEventParamTextInputSendPinRng,
                              typeTextRange, sizeof(TextRange), &pinRange);

#if DEBUG_INPUT_EVENT
  DEBUG_PRINT("MUIMUpdateActiveInputArea() pinRange.fStart=%d pinRange.fEnd=%d\n",
              pinRange.fStart, pinRange.fEnd);
#endif

  if (error == noErr)
    error = SendTextInputEvent(event);

  DisposePtr((Ptr) hiliteRangePtr);
  DisposePtr((Ptr) updateRangePtr);

  return error;
}

/**
 * Get a TSM status
 *
 * @param inHandle   a reference to the active session
 * @param outStat    TSM status
 *
 * @return OSStatus  a toolbox error code
 */
OSErr
MUIMGetTSMStatus(MUIMSessionHandle inHandle, TSMStat *outStat)
{
  OSErr error = noErr;
  ComponentInstance componentInstance;
  EventRef event;

  outStat->fRefCon = 0;
  outStat->fTextOffset = 0;
  outStat->fSLRec.fScript = smJapanese;
  outStat->fSLRec.fLanguage = langJapanese;
  outStat->fLeadingEdge = FALSE;
  outStat->fReplyPoint.v = 0;
  outStat->fReplyPoint.h = 0;
  outStat->fReplyFont = 0;
  outStat->fReplyPointSize = 0;
  outStat->fReplyLineHeight = 0;
  
  // create an event
  error = CreateEvent(NULL, kEventClassTextInput,
                      kEventTextInputOffsetToPos,
                      GetCurrentEventTime(),
                      kEventAttributeUserEvent,
                      &event);

  // set a component instance
  if (error == noErr) {
    componentInstance = (*inHandle)->fComponentInstance;
    error = SetEventParameter(event,
                              kEventParamTextInputSendComponentInstance,
                              typeComponentInstance,
                              sizeof(ComponentInstance),
                              &componentInstance);
  }

  if (error == noErr)
    error = SetEventParameter(event,
                              kEventParamTextInputSendRefCon,
                              typeLongInteger,
                              sizeof(long),
                              &outStat->fRefCon);

  // set the cursor offset
  if (error == noErr) {
    outStat->fTextOffset = SegmentToOffset(inHandle);
    error = SetEventParameter(event,
                              kEventParamTextInputSendTextOffset,
                              typeLongInteger,
                              sizeof(long),
                              &outStat->fTextOffset);
  }

  if (error == noErr)
    error = SetEventParameter(event,
                              kEventParamTextInputSendSLRec,
                              typeIntlWritingCode,
                              sizeof(ScriptLanguageRecord),
                              &outStat->fSLRec);

  if (error == noErr)
    error = SetEventParameter(event,
                              kEventParamTextInputSendLeadingEdge,
                              typeBoolean,
                              sizeof(Boolean),
                              &outStat->fLeadingEdge);

  // send a event
  if (error == noErr)
    error = SendTextInputEvent(event);

  //DEBUG_PRINT("MUIMGetTSMStatus() error=%ld (send)\n", error);

  // get a reply point
  if (error == noErr)
    error = GetEventParameter(event,
                              kEventParamTextInputReplyPoint,
                              typeQDPoint,
                              NULL, sizeof(Point), NULL,
                              &outStat->fReplyPoint);

  //DEBUG_PRINT("MUIMGetTSMStatus() error=%ld (reply point) v=%d h=%d\n",
  //            error, outStat->fReplyPoint.v, outStat->fReplyPoint.h);
  

  // get a reply font
  if (error == noErr)
    error = GetEventParameter(event,
                              kEventParamTextInputReplyFont,
                              typeLongInteger,
                              NULL, sizeof(long), NULL,
                              &outStat->fReplyFont);

  //DEBUG_PRINT("MUIMGetTSMStatus() error=%ld ReplyFont=%ld\n",
  //            error, outStat->fReplyFont);

#if 0
  // get a font size
  if (error == noErr)
    error = GetEventParameter(event,
                              kEventParamTextInputReplyPointSize,
                              typeFixed,
                              NULL, sizeof(Fixed), NULL,
                              &outStat->fReplyPointSize);

  //DEBUG_PRINT("MUIMGetTSMStatus() error=%ld ReplyPointSize=%d\n",
  //            error, outStat->fReplyPointSize);
#endif

  // get a line height
  if (error == noErr)
    error = GetEventParameter(event,
                              kEventParamTextInputReplyLineHeight,
                              typeShortInteger,
                              NULL, sizeof(short), NULL,
                              &outStat->fReplyLineHeight);

  //DEBUG_PRINT("MUIMGetTSMStatus() error=%ld (line height)\n", error);

  if (event)
    ReleaseEvent(event);

  //DEBUG_PRINT("MUIMGetTSMStatus() error=%ld\n", error);

  return error;
}

#pragma mark -

static void
SegmentToHiliteRange(MUIMSessionHandle inHandle, TextRangeArrayPtr *inRange)
{
  UInt32 i, j = 0;
  UInt32 pos = 0;
  SInt32 caret = -1;
  Boolean revExist = FALSE;

  /*
   * Uim attribute:
   *
   * 0: UPreeditAttr_None
   * 1: UPreeditAttr_UnderLine
   * 2: UPreeditAttr_Reverse
   * 4: UPreeditAttr_Cursor
   * 8: UPreeditAttr_Separator
   */

  /*
   * TSM HiliteStyle:
   *
   * 1: kCaretPosition
   * 2: kRawText
   * 3: kSelectedRawText
   * 4: kConvertedText
   * 5: kSelectedConvertedText
   * 6: kBlockFillText  ?
   * 7: kOutlineText  ?
   * 8: kSelectedText
   */
  
  (*inRange) = (TextRangeArrayPtr) NewPtrClear(sizeof(short) +
                                               sizeof(TextRange) *
                                               ((*inHandle)->fSegmentCount + 1));
  
  for (i = 0; i < (*inHandle)->fSegmentCount; i++) {
#if DEBUG_HILITERANGE
    DEBUG_PRINT("SegmentToHiliteRange() %lu pos=%lu len=%lu attr=%lu\n",
                i, pos, (*inHandle)->fSegments[i].fLength,
                (*inHandle)->fSegments[i].fAttr);
#endif
    // caret
    // string length is 0 or greaer than 0
    if ((*inHandle)->fSegments[i].fAttr & UPreeditAttr_Cursor) {
      (*inRange)->fRange[j].fStart = (*inRange)->fRange[j].fEnd = pos * sizeof(UniChar);
      (*inRange)->fRange[j].fHiliteStyle = kCaretPosition;
      caret = j;
      j++;
    }

    if ((*inHandle)->fSegments[i].fLength > 0) {
      (*inRange)->fRange[j].fStart = pos * sizeof(UniChar);
      pos += (*inHandle)->fSegments[i].fLength;
      (*inRange)->fRange[j].fEnd = pos * sizeof(UniChar);

      if ((*inHandle)->fSegments[i].fAttr & UPreeditAttr_Reverse) {
        (*inRange)->fRange[j].fHiliteStyle = kSelectedConvertedText;
        revExist = TRUE;
      }
      else if ((*inHandle)->fSegments[i].fAttr & UPreeditAttr_UnderLine)
        (*inRange)->fRange[j].fHiliteStyle = kConvertedText;
      else
        (*inRange)->fRange[j].fHiliteStyle = kRawText;
      j++;
    }
  }
  (*inRange)->fNumOfRanges = j;

  if (!revExist) {
    for (i = 0; i < (*inRange)->fNumOfRanges; i++) {
      if ((*inRange)->fRange[i].fHiliteStyle == kConvertedText)
        (*inRange)->fRange[i].fHiliteStyle = kSelectedRawText;
    }
  }
}

static UInt32
SegmentToOffset(MUIMSessionHandle inHandle)
{
  UInt32 i, seg_count, len = 0, pos = 0, prev_pos = 0;
  Boolean cursor_found = FALSE;
  
  seg_count = (*inHandle)->fSegmentCount;
  if (seg_count <= 1)
    return 0;
  
  if ((*inHandle)->fSegments[seg_count - 1].fLength == 0 &&
      (*inHandle)->fSegments[seg_count - 1].fAttr == UPreeditAttr_Cursor)
    return 0;
  
  for (i = 0; i < seg_count; i++) {
    if ((*inHandle)->fSegments[i].fAttr & UPreeditAttr_Cursor)
      cursor_found = TRUE;
    if ((*inHandle)->fSegments[i].fLength > 0) {
      prev_pos = pos;
      if (!cursor_found)
        pos += (*inHandle)->fSegments[i].fLength;
      len += (*inHandle)->fSegments[i].fLength;
    }
  }
  
  if (pos == len)
    pos = prev_pos;
  
  return pos * sizeof(UniChar);
}

