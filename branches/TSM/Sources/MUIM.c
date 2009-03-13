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

#define TARGET_API_MAC_CARBON  1

#include <Carbon/Carbon.h>

#include <sys/types.h>
#include <unistd.h>
#include <pwd.h>

#include "MUIM.h"
#include "MUIMInputEvents.h"
#include "MUIMScript.h"
#include "UIMCallback.h"
#include "CandidateCarbon.h"
#include "KeycodeToUKey.h"
#include "Preference.h"


const short kMENU_Pencil = kBaseResourceID + 1;
const short kICNx_Pencil = kBaseResourceID + 1;

enum
{
  kShowHideKeyboardPaletteMenuItem = 1,
  kShowHideSendEventPaletteMenuItem = 2,
  kConvertToLowercaseMenuItem = 4,
  kConvertToUppercaseMenuItem = 5
};

enum
{
  kShowHideKeyboardPaletteMenuCommand = 'SHKP',
  kShowHideSendEventPaletteMenuCommand = 'SHDP',
  kConvertToLowercaseMenuCommand = 'CLOW',
  kConvertToUppercaseMenuCommand = 'CUPP'
};

const short kSTRx_MenuItems = kBaseResourceID + 1;

enum
{
  kShowKeyboardPaletteMenuItemString = 1,
  kHideKeyboardPaletteMenuItemString = 2,
  kShowSendEventPaletteMenuItemString = 3,
  kHideSendEventPaletteMenuItemString = 4
};

Boolean gMacUIMDisable = FALSE;

MUIMSessionHandle gActiveSession;

int gNumSession = 0;
MUIMSessionHandle *gSessionList = NULL;

//static EventTime gDeactivateTime = 0.0;

#ifdef NEW_HELPER
Boolean gUimHelperConnected;
#else
int gUimFD;
#endif
CFSocketRef gUimSock;
CFRunLoopSourceRef gUimRun;
CFSocketContext gSockContext;

#ifdef SYNC_MODE
// current mode
SInt32 gMode = -1;
#endif

Boolean gActiveProp = TRUE;

CFStringRef gIMName = NULL;
Boolean gEnableModeTips = true;
Boolean gCandVertical = true;
int gCandTransparency = 0;
CFStringRef gCandFont = NULL;
float gCandFontSize = 0.0;

MenuRef gPencilMenu;

static CFStringRef gShowKeyboardPaletteMenuItemString;
static CFStringRef gHideKeyboardPaletteMenuItemString;
static CFStringRef gShowSendEventPaletteMenuItemString;
static CFStringRef gHideSendEventPaletteMenuItemString;

static pascal OSStatus
MUIMPencilMenuEventHandler(EventHandlerCallRef inEventHandlerCallRef,
                           EventRef inEventRef, void *inUserData);

static void
CreateUIMContext(MUIMSessionHandle inSessionHandle, CFStringRef inIMName);

static void
CreateAllUIMContext(CFStringRef inIMName);

static void
ReleaseAllUIMContext();

static void
NotificationCallback(CFNotificationCenterRef inCenter, void *inObserver, 
                     CFStringRef inName, const void *inObject, 
                     CFDictionaryRef inUserInfo);

static int
ConvertKeyVal(int inKey, int inMod);

static int
ConvertModifier(int inMod);

#pragma mark -

ComponentResult
MUIMInitialize(ComponentInstance inComponentInstance,
               MenuRef *outTextServiceMenu)
{
  ComponentResult result;
  short refNum;
  EventTypeSpec menuEventSpec;
  Handle iconData = NULL;
  Handle menuIconSuite;
  Str255 menuText;
  Boolean dummy;

  result = noErr;
  refNum = -1;

  gActiveSession = NULL;
  gPencilMenu = NULL;

  refNum = OpenComponentResFile((Component) inComponentInstance);
  result = ResError();
  if ((result == noErr) && (refNum == -1))
    result = resFNotFound;

  if (result == noErr) {
    gPencilMenu = GetMenu(kMENU_Pencil);
    if (gPencilMenu)
      *outTextServiceMenu = gPencilMenu;
    else
      result = resNotFound;
  }

  if (result == noErr)
    ChangeMenuAttributes(gPencilMenu, kMenuAttrUsePencilGlyph, 0);

  if (result == noErr) {
    menuEventSpec.eventClass = kEventClassCommand;
    menuEventSpec.eventKind = kEventProcessCommand;
    result = InstallMenuEventHandler(gPencilMenu,
                                     NewEventHandlerUPP
                                     (MUIMPencilMenuEventHandler), 1,
                                     &menuEventSpec, nil, nil);
  }

  if (result == noErr)
    result = NewIconSuite(&menuIconSuite);

  if (result == noErr) {
    iconData = GetResource('ics8', kICNx_Pencil);
    if (iconData == nil)
      result = resNotFound;
    else
      DetachResource(iconData);
  }
  if (result == noErr)
    result = AddIconToSuite(iconData, menuIconSuite, 'ics8');
  if (result == noErr) {
    iconData = GetResource('ics4', kICNx_Pencil);
    if (iconData == nil)
      result = resNotFound;
    else
      DetachResource(iconData);
  }
  if (result == noErr)
    result = AddIconToSuite(iconData, menuIconSuite, 'ics4');
  if (result == noErr) {
    iconData = GetResource('ics#', kICNx_Pencil);
    if (iconData == nil)
      result = resNotFound;
    else
      DetachResource(iconData);
  }
  if (result == noErr)
    result = AddIconToSuite(iconData, menuIconSuite, 'ics#');

  if (result == noErr) {
    menuText[0] = 5;
    menuText[1] = 1;
    *(Handle *) (&menuText[2]) = menuIconSuite;
    SetMenuTitle(gPencilMenu, menuText);
  }

  if (result == noErr) {
    GetIndString(menuText, kSTRx_MenuItems,
                 kShowKeyboardPaletteMenuItemString);
    gShowKeyboardPaletteMenuItemString =
      CFStringCreateWithPascalString(NULL, menuText,
                                     kTextEncodingMacRoman);
    GetIndString(menuText, kSTRx_MenuItems,
                 kHideKeyboardPaletteMenuItemString);
    gHideKeyboardPaletteMenuItemString =
      CFStringCreateWithPascalString(NULL, menuText,
                                     kTextEncodingMacRoman);
    GetIndString(menuText, kSTRx_MenuItems,
                 kShowSendEventPaletteMenuItemString);
    gShowSendEventPaletteMenuItemString =
      CFStringCreateWithPascalString(NULL, menuText,
                                     kTextEncodingMacRoman);
    GetIndString(menuText, kSTRx_MenuItems,
                 kHideSendEventPaletteMenuItemString);
    gHideSendEventPaletteMenuItemString =
      CFStringCreateWithPascalString(NULL, menuText,
                                     kTextEncodingMacRoman);
  }

  if (refNum != -1)
    CloseComponentResFile(refNum);

#if DEBUG_SESSION
  DEBUG_PRINT("MUIMInitialize() uid=%ld euid=%ld\n",
              getuid(), geteuid());
#endif

  if (result == noErr) {
    CFPropertyListRef propVal;
    
    if (CFPreferencesGetAppBooleanValue(CFSTR(kPrefHelperIM),
                                        CFSTR(kAppID), &dummy))
      gCandVertical = true;
    else
      gCandVertical = false;
  
    gCandTransparency =
      CFPreferencesGetAppIntegerValue(CFSTR(kPrefCandTransparency),
                                      CFSTR(kAppID), &dummy);
  
    propVal = CFPreferencesCopyAppValue(CFSTR(kPrefCandFont), CFSTR(kAppID));
    if (propVal && CFGetTypeID(propVal) == CFStringGetTypeID()) {
      gCandFont = (CFStringRef) propVal;
    } else {
      if (propVal)
	CFRelease(propVal);
    }
    
    propVal = CFPreferencesCopyAppValue(CFSTR(kPrefCandFontSize), CFSTR(kAppID));
    if (propVal && CFGetTypeID(propVal) == CFNumberGetTypeID())
      CFNumberGetValue((CFNumberRef) propVal, kCFNumberFloatType, &gCandFontSize);
    else {
      if (propVal)
	CFRelease(propVal);
    }
  
    if (CFPreferencesGetAppBooleanValue(CFSTR(kPrefModeTips),
                                        CFSTR(kAppID), &dummy))
      gEnableModeTips = true;
    else
      gEnableModeTips = false;
  }
  
#ifdef NEW_HELPER
  gUimHelperConnected = FALSE;
#else
  gUimFD = -1;
#endif
  
  gUimSock = NULL;
  gUimRun = NULL;
  
  if (getuid() == 0 && getuid() != geteuid()) {
    gMacUIMDisable = TRUE;
    //result = resNotFound;
    return result;
  }
  else {
    char *home = getenv("HOME");
    if (!home) {
      DEBUG_PRINT("MUIMInitialize() $HOME is NULL\n");
#if 0
      struct passwd *pw = NULL;
      uid_t uid = getuid();
      pw = getpwuid(uid);
      if (pw == NULL)
        setenv("HOME", "/", 0);
      else
        setenv("HOME", pw->pw_dir, 0);
#else
      gMacUIMDisable = TRUE;
      //result = resNotFound;
      return result;
#endif
    }
  }

#if DEBUG_UIM
  // Uim debug
  if (result == noErr) {
    char num[16];
    sprintf(num, "%d", DEBUG_UIM);
    setenv("LIBUIM_VERBOSE", num, 1);
  }
#endif

#if DEBUG_PRIME
  // PRIME debug
  if (result == noErr) {
    setenv("PRIME_DEBUG", "1", 1);
  }
#endif

  if (result == noErr) {
    uim_init();

    CFNotificationCenterRef center =
      CFNotificationCenterGetDistributedCenter();

    if (center) {
      CFNotificationCenterAddObserver(center, NULL, NotificationCallback,
                                      NULL, CFSTR(kAppID),
                                      //CFNotificationSuspensionBehaviorDrop
                                      CFNotificationSuspensionBehaviorCoalesce
                                      //CFNotificationSuspensionBehaviorHold
                                      //CFNotificationSuspensionBehaviorDeliverImmediately
                                      );
    }
  }

  return result;
}

void
MUIMTerminate(ComponentInstance inComponentInstance)
{
#if DEBUG_SESSION
    DEBUG_PRINT("MUIMTerminate()\n");
#endif
    gActiveSession = NULL;
    gPencilMenu = NULL;
    
    if (gMacUIMDisable)
      return;
    
    UIMHelperClose();
    uim_quit();
}

ComponentResult
MUIMSessionOpen(ComponentInstance inComponentInstance,
                MUIMSessionHandle *outSessionHandle)
{
  ComponentResult result = noErr;
  
  if (*outSessionHandle == nil) {
    *outSessionHandle =
      (MUIMSessionHandle) NewHandle(sizeof(MUIMSessionRecord));
#if DEBUG_SESSION
    DEBUG_PRINT("MUIMSessionOpen() NewHandle=%p\n", *outSessionHandle);
#endif
  }

  if (*outSessionHandle) {
    gNumSession++;

    if (!gSessionList)
      gSessionList = (MUIMSessionHandle *)
        malloc(sizeof(MUIMSessionHandle) * gNumSession);
    else
      gSessionList = (MUIMSessionHandle *)
        realloc(gSessionList, sizeof(MUIMSessionHandle) * gNumSession);

    gSessionList[gNumSession - 1] = *outSessionHandle;

    (**outSessionHandle)->fComponentInstance = inComponentInstance;
    (**outSessionHandle)->fLastUpdateLength = 0;
    (**outSessionHandle)->fSegments = NULL;
    (**outSessionHandle)->fSegmentCount = 0;

    (**outSessionHandle)->fLastUpdateLength = 0;
    (**outSessionHandle)->fFixBuffer = NULL;
    (**outSessionHandle)->fFixLen = 0;
    (**outSessionHandle)->fOldPreedit = NULL;
    (**outSessionHandle)->fOldPreeditLen = 0;

    (**outSessionHandle)->fModeTipsBlock = TRUE;

    (**outSessionHandle)->fBundleRef = NULL;
    (**outSessionHandle)->fWindowOpened = false;
    
    (**outSessionHandle)->fLastMode = NULL;

    (**outSessionHandle)->fDeactivateTime = -1.0;
    
    (**outSessionHandle)->fUC = NULL;
    if (!gMacUIMDisable)
      CreateUIMContext(*outSessionHandle, NULL);
  }
  else
    result = memFullErr;

  if (result == noErr) {
    if (!gMacUIMDisable)
      InitCandidateWindow((*outSessionHandle));
  }

  return result;
}

void
MUIMSessionClose(MUIMSessionHandle inSessionHandle)
{
  UInt32 i, j;

#if DEBUG_SESSION
  DEBUG_PRINT("MUIMSessionClose() inSessionHandle=%p\n",
              inSessionHandle);
#endif
  
  for (i = 0; i < gNumSession; i++) {
    if (gSessionList[i] == inSessionHandle) {
      gSessionList[i] = NULL;
      for (j = i; j < gNumSession - 1; j++)
        gSessionList[j] = gSessionList[j + 1];
      break;
    }
  }
  if (i < gNumSession)
    gNumSession--;

  if (inSessionHandle) {
    for (i = 0; i < (*inSessionHandle)->fSegmentCount; i++)
      free((*inSessionHandle)->fSegments[i].fBuffer);

    free((*inSessionHandle)->fSegments);
    (*inSessionHandle)->fSegments = NULL;
    (*inSessionHandle)->fSegmentCount = 0;

    uim_release_context((*inSessionHandle)->fUC);
    DisposeHandle((Handle) inSessionHandle);
  }
}

ComponentResult
MUIMSessionActivate(MUIMSessionHandle inSessionHandle)
{
  OSStatus result = noErr;
  long keyboardID = GetScriptVariable(GetScriptManagerVariable(smLastScript),
                                      smScriptKeys);
  SetScriptVariable(smJapanese, smScriptKeys, keyboardID);

  gActiveSession = inSessionHandle;
  
  (*inSessionHandle)->fModeTipsBlock = FALSE;

#if DEBUG_SESSION
  DEBUG_PRINT("MUIMSessionActivate() gActiveSession=%p (%p) time=%f deactivate=%f\n",
              gActiveSession, &gActiveSession, GetCurrentEventTime(),
              (*inSessionHandle)->fDeactivateTime);
#endif
  
  if (gMacUIMDisable)
    return noErr;

  //DEBUG_PRINT("activate start\n");
  
  if ((*inSessionHandle)->fWindowOpened)
    LayoutCandidate(inSessionHandle);
  
#ifdef SYNC_MODE
#if DEBUG_SYNCMODE
  DEBUG_PRINT("MUIMSessionActivate() gActiveSession=%p mode=%d gMode=%d\n",
              gActiveSession,
              uim_get_current_mode((*inSessionHandle)->fUC), gMode);
#endif

  UIMCheckHelper();
  
  uim_helper_client_focus_in((*inSessionHandle)->fUC);
  
  gActiveProp = TRUE;
  
  if (gMode >= 0) {
    if (gMode != uim_get_current_mode((*inSessionHandle)->fUC)) {
      // UIM mode was changed
#if DEBUG_HELPER
      DEBUG_PRINT("MUIMSessionActivate() set mode %d\n", gMode);
#endif
      uim_set_mode((*inSessionHandle)->fUC, gMode);
    }
#if DEBUG_HELPER
    DEBUG_PRINT("MUIMSessionActivate() label update\n");
#endif
    if ((*inSessionHandle)->fDeactivateTime != 0.0) {
      if ((*inSessionHandle)->fDeactivateTime + 0.05 > GetCurrentEventTime()) {
        uim_prop_label_update((*inSessionHandle)->fUC);
      }
      else {
        (*inSessionHandle)->fModeTipsBlock = TRUE;
        uim_prop_label_update((*inSessionHandle)->fUC);
        (*inSessionHandle)->fModeTipsBlock = FALSE;
      }
      (*inSessionHandle)->fDeactivateTime = 0.0;
    }
    else
      uim_prop_label_update((*inSessionHandle)->fUC);
  }
  else { // gMode == -1
    // first activation
#if DEBUG_HELPER
    DEBUG_PRINT("MUIMSessionActivate() list update\n");
#endif
    uim_prop_list_update((*inSessionHandle)->fUC);
  }
#endif // SYNC_MODE

#ifndef SYNC_MODE
  UIMCheckHelper();
  uim_helper_client_focus_in((*inSessionHandle)->fUC);
  uim_prop_list_update((*inSessionHandle)->fUC);
  uim_prop_label_update((*inSessionHandle)->fUC);
#endif // !SYNC_MODE
  
  return result;
}

ComponentResult
MUIMSessionDeactivate(MUIMSessionHandle inSessionHandle)
{
#if DEBUG_SESSION
  DEBUG_PRINT("MUIMSessionDeactivate() gActiveSession=%p time=%f\n",
              gActiveSession, GetCurrentEventTime());
#endif
  
  if (gMacUIMDisable)
    return noErr;

  (*inSessionHandle)->fDeactivateTime = GetCurrentEventTime();
  
  MUIMHideWindow(inSessionHandle);

  uim_helper_client_focus_out((*inSessionHandle)->fUC);
  
  (*inSessionHandle)->fModeTipsBlock = TRUE;

  /*
  if ((*inSessionHandle)->fLastMode) {
    CFRelease((*inSessionHandle)->fLastMode);
    (*inSessionHandle)->fLastMode = NULL;
  }
  */
  
  return noErr;
}

ComponentResult
MUIMSessionEvent(MUIMSessionHandle inSessionHandle, EventRef inEventRef)
{
  Boolean handled;
  UInt32 eventClass;
  UInt32 eventKind;

  handled = FALSE;
  
  if (gMacUIMDisable)
    return handled;

  eventClass = GetEventClass(inEventRef);
  eventKind = GetEventKind(inEventRef);

#if DEBUG_SESSION
  // kEventRawKeyDown = 1
  // kEventRawKeyRepeat = 2
  // kEventRawKeyUp = 3
  // kEventRawKeyModifiersChanged = 4
  // kEventHotKeyPressed = 5
  // kEventHotKeyReleased = 6
  DEBUG_PRINT("MUIMSessionEvent() eventClass=%lu eventKind=%lu\n",
              eventClass, eventKind);
#endif

  // kEventClassKeyboard:
  //   kEventRawKeyDown - A key was pressed
  //   kEventRawKeyRepeat - Sent periodically as a key is held down by the user
  //   kEventRawKeyUp - A key was released
  //   kEventRawKeyModifiersChanged - The keyboard modifiers (bucky bits) have changed

  /*
  if (eventKind == kEventRawKeyDown)
    DEBUG_PRINT("key down\n");
  else if (eventKind == kEventRawKeyRepeat)
    DEBUG_PRINT("key repeat\n");
  else if (eventKind == kEventRawKeyUp)
    DEBUG_PRINT("key up\n");
  else if (eventKind == kEventRawKeyModifiersChanged)
    DEBUG_PRINT("mod changed\n");
  */
  
  if (eventClass == kEventClassKeyboard &&
      (eventKind == kEventRawKeyDown ||
       eventKind == kEventRawKeyRepeat)) {
    UInt32 keyCode;
    unsigned char charCode;
    UInt32 modifiers;

    GetEventParameter(inEventRef, kEventParamKeyCode, typeUInt32, nil,
                      sizeof(keyCode), nil, &keyCode);

    GetEventParameter(inEventRef, kEventParamKeyMacCharCodes, typeChar, nil,
                      sizeof(charCode), nil, &charCode);

    GetEventParameter(inEventRef, kEventParamKeyModifiers, typeUInt32, nil,
                      sizeof(modifiers), nil, &modifiers);

#if DEBUG_KEYEVENT
    DEBUG_PRINT("MUIMSessionEvent() keycode=0x%lx, char=%c, charCode=0x%x, modifiers=0x%lx\n",
                keyCode, charCode, charCode, modifiers);
#endif

    if (!(modifiers & cmdKey))
       handled = MUIMHandleInput(inSessionHandle, keyCode, charCode, modifiers);
  }

  return handled;
}

ComponentResult
MUIMSessionFix(MUIMSessionHandle inSessionHandle)
{
  UniCharPtr str = NULL;
  UInt32 len = 0, cursorPos = 0;

#if DEBUG_PREEDIT
  DEBUG_PRINT("MUIMSessionFix() fFixLen=%lu\n", (*inSessionHandle)->fFixLen);
#endif

  if (gMacUIMDisable)
    return noErr;
  
  if ((*inSessionHandle)->fFixLen == 0) {
    // commit preedit string (single context)
    GetPreeditString(inSessionHandle, &str, &len, &cursorPos);
    if (len > 0) {
      uim_press_key((*inSessionHandle)->fUC, 'j', UMod_Control);
      uim_release_key((*inSessionHandle)->fUC, 'j', UMod_Control);
    }
    MUIMHideWindow(inSessionHandle);
  }

  return noErr;
}

ComponentResult
MUIMSetInputMode(MUIMSessionHandle inSessionHandle, CFStringRef inInputMode)
{
  ComponentResult result;
  char modeName[BUFSIZ];
  
  if (!inSessionHandle || !(*inSessionHandle) ||
      !(*inSessionHandle)->fUC || !inInputMode)
    return tsmInputModeChangeFailedErr;
  
  CFStringGetCString(inInputMode, modeName, BUFSIZ, kCFStringEncodingMacRoman);
  
#if DEBUG_INPUTMODE
  DEBUG_PRINT("MUIMSetInputMode() inInputModer='%s'\n", modeName);
#endif
  
  if (gMacUIMDisable)
    return tsmInputModeChangeFailedErr;
  
  TSMSelectInputMode((Component) (*inSessionHandle)->fComponentInstance,
                     inInputMode);
  
  if (!(*inSessionHandle)->fLastMode ||
      CFStringCompare(inInputMode, (*inSessionHandle)->fLastMode, 0)) {
    
    if (!CFStringCompare(inInputMode,
                         kTextServiceInputModeRoman, 0) ||
        !CFStringCompare(inInputMode,
                         kTextServiceInputModePassword, 0)) {
#if 0
      UInt32 i;
      for (i = 0; i < gNumSession; i++) {
        BlockUpdatePreedit();
        uim_press_key((*gSessionList[i])->fUC, UKey_Private1, 0);
        uim_release_key((*gSessionList[i])->fUC, UKey_Private1, 0);
        UnblockUpdatePreedit();
      }
#else
      BlockUpdatePreedit();
      uim_press_key((*inSessionHandle)->fUC, UKey_Private1, 0);
      uim_release_key((*inSessionHandle)->fUC, UKey_Private1, 0);
      UnblockUpdatePreedit();
#endif
    }
    else if (!CFStringCompare(inInputMode,
                              kTextServiceInputModeJapanese, 0) ||
             !CFStringCompare(inInputMode,
                              kTextServiceInputModeJapaneseHiragana, 0) ||
             !CFStringCompare(inInputMode,
                              kTextServiceInputModeJapaneseKatakana, 0) ||
             !CFStringCompare(inInputMode,
                              kTextServiceInputModeJapaneseHalfWidthKana, 0) ||
             !CFStringCompare(inInputMode,
                              kTextServiceInputModeJapaneseFullWidthRoman, 0) ||
             !CFStringCompare(inInputMode,
                              kTextServiceInputModeJapaneseFirstName, 0) ||
             !CFStringCompare(inInputMode,
                              kTextServiceInputModeJapaneseLastName, 0) ||
             !CFStringCompare(inInputMode,
                              kTextServiceInputModeJapanesePlaceName, 0)) {
#if 0
      UInt32 i;
      for (i = 0; i < gNumSession; i++) {
        BlockUpdatePreedit();
        uim_press_key((*gSessionList[i])->fUC, UKey_Private2, 0);
        uim_release_key((*gSessionList[i])->fUC, UKey_Private2, 0);
        UnblockUpdatePreedit();
      }
#else
      BlockUpdatePreedit();
      uim_press_key((*inSessionHandle)->fUC, UKey_Private2, 0);
      uim_release_key((*inSessionHandle)->fUC, UKey_Private2, 0);
      UnblockUpdatePreedit();
#endif
    }

    if ((*inSessionHandle)->fLastMode)
      CFRelease((*inSessionHandle)->fLastMode);
    (*inSessionHandle)->fLastMode = inInputMode;
    CFRetain((*inSessionHandle)->fLastMode);
  }
  
  return result;
}

ComponentResult
MUIMHideWindow(MUIMSessionHandle inSessionHandle)
{
#if DEBUG_SESSION
  DEBUG_PRINT("MUIMHidePaletteWindow()\n");
#endif

  HideCandidateWindow(inSessionHandle);

  return noErr;
}

MUIMSessionHandle
MUIMGetActiveSession(void)
{
#if DEBUG_SESSION
  DEBUG_PRINT("MUIMGetActiveSession()\n");
#endif

  return gActiveSession;
}

Boolean
MUIMHandleInput(MUIMSessionHandle inSessionHandle, UInt32 inKeycode,
                unsigned char inCharCode, UInt32 inModifiers)
{
  Boolean handled;
  Boolean isScriptKey;
  int key = 0, mod = 0;
  int rv;
  int i;

  handled = FALSE;
  isScriptKey = FALSE;

#if DEBUG_KEYEVENT
  DEBUG_PRINT("MUIMHandleInput() inCharCode=%02x inModifiers=%lx\n",
              inCharCode, inModifiers);
#endif

  if (CandidateWindowIsVisible(inSessionHandle) &&
      inModifiers == 0 &&
      (*inSessionHandle)->fCandidateIndex >= 0 && // PRIME - if there is no selection delegate the input event to prime.scm
      (inCharCode >= '0' && inCharCode <= '9')) {
    UInt32 row = inCharCode == '0' ? 9 : inCharCode - '1';
#if DEBUG_KEYEVENT
    DEBUG_PRINT("MUIMHandleInput() select candidate %lu index=%ld begin=%ld end=%ld row=%lu\n",
                row, (*inSessionHandle)->fCandidateIndex,
                (*inSessionHandle)->fLayoutBegin,
                (*inSessionHandle)->fNRCandidates, row);
#endif
    if ((*inSessionHandle)->fLayoutBegin + row <
        (*inSessionHandle)->fNRCandidates)
      CandClicked(row);
    return TRUE;
  }

  /* Check for special keys first */
  for (i = 0; KeycodeToUKey[i].ukey; i++) {
    if (KeycodeToUKey[i].keycode == inKeycode) {
      key = KeycodeToUKey[i].ukey;
      break;
    }
  }
  if (key == UKey_Private1 || key == UKey_Private2)
    isScriptKey = TRUE;
    
  /* Then convert normal keys */
  if (key == 0) {
    key = ConvertKeyVal(inCharCode, inModifiers);

    // convert control sequence to normal charactor
    // (when <control> + <special charactor>)
    if (inModifiers & controlKey) {
      for (i = 0; CharToKey[i].ckey; i++) {
        if (CharToKey[i].charcode == inCharCode) {
          key = CharToKey[i].ckey;
          break;
        }
      }
    }
  }

  mod = ConvertModifier(inModifiers);

#if DEBUG_KEYEVENT
  DEBUG_PRINT("MUIMHandleInput() key=0x%x mod=0x%x\n", key, mod);
#endif

  rv = uim_press_key((*inSessionHandle)->fUC, key, mod);
  uim_release_key((*inSessionHandle)->fUC, key, mod);

  if (!rv || isScriptKey)
    handled = TRUE;

#if DEBUG_KEYEVENT
  DEBUG_PRINT("MUIMHandleInput() uim_press_key handled=%s\n",
              handled ? "true" : "false");
#endif
  
  return handled;
}

void
MUIMUpdateShowHideKeyboardPaletteMenuItem(Boolean inIsHidden)
{
#if DEBUG_CANDIDATES
  DEBUG_PRINT("MUIMUpdateShowHideKeyboardPaletteMenuItem() inIsHidden=%d\n",
              inIsHidden);
#endif

  if (inIsHidden)
    SetMenuItemTextWithCFString(gPencilMenu,
                                kShowHideKeyboardPaletteMenuItem,
                                gShowKeyboardPaletteMenuItemString);
  else
    SetMenuItemTextWithCFString(gPencilMenu,
                                kShowHideKeyboardPaletteMenuItem,
                                gHideKeyboardPaletteMenuItemString);
}

void
MUIMUpdateShowHideSendEventPaletteMenuItem(Boolean inIsHidden)
{
#if DEBUG_CANDIDATES
  DEBUG_PRINT("MUIMUpdateShowHideSendEventPaletteMenuItem() inIsHidden=%d\n",
              inIsHidden);
#endif

  if (inIsHidden)
    SetMenuItemTextWithCFString(gPencilMenu,
                                kShowHideSendEventPaletteMenuItem,
                                gShowSendEventPaletteMenuItemString);
  else
    SetMenuItemTextWithCFString(gPencilMenu,
                                kShowHideSendEventPaletteMenuItem,
                                gHideSendEventPaletteMenuItemString);
}

static pascal OSStatus
MUIMPencilMenuEventHandler(EventHandlerCallRef inEventHandlerCallRef,
                           EventRef inEventRef, void *inUserData)
{
  OSStatus result;
  HICommand command;

#if DEBUG_MENU
  DEBUG_PRINT("MUIMPencilMenuEventHandler()\n");
#endif

  result =
    GetEventParameter(inEventRef, kEventParamDirectObject, typeHICommand,
                      nil, sizeof(command), nil, &command);
  if (result == noErr) {
    switch (command.commandID) {

    case kShowHideKeyboardPaletteMenuCommand:
      break;

    case kShowHideSendEventPaletteMenuCommand:
      break;

    case kConvertToLowercaseMenuCommand:
      break;

    case kConvertToUppercaseMenuCommand:
      break;

    default:
      result = eventNotHandledErr;
      break;
    }
  }
  else
    result = eventNotHandledErr;
  return result;
}

#pragma mark -

static void
CreateUIMContext(MUIMSessionHandle inSessionHandle, CFStringRef inIMName)
{
  char imName[BUFSIZ];
  CFPropertyListRef imVal = NULL;

  if (inIMName)
    CFStringGetCString(inIMName, imName, BUFSIZ, kCFStringEncodingMacRoman);
  else if (gIMName)
    CFStringGetCString(gIMName, imName, BUFSIZ, kCFStringEncodingMacRoman);
  else {
    // Load the preferences
    imVal = CFPreferencesCopyAppValue(CFSTR(kPrefIM), CFSTR(kAppID));
    if (imVal && CFGetTypeID(imVal) == CFStringGetTypeID())
      CFStringGetCString((CFStringRef) imVal, imName, BUFSIZ,
                         kCFStringEncodingMacRoman);
    else
      strcpy(imName, kDefaultIM);
  }

  (*inSessionHandle)->fUC =
    uim_create_context(inSessionHandle,
                       "UTF-8", NULL, imName,
                       NULL, UIMCommitString);

  if (imVal)
    CFRelease(imVal);

  if (!(*inSessionHandle)->fUC)
    return;

  uim_set_preedit_cb((*inSessionHandle)->fUC,
                     UIMPreeditClear,
                     UIMPreeditPushback,
                     UIMPreeditUpdate);

  UIMCheckHelper();
  uim_set_prop_list_update_cb((*inSessionHandle)->fUC, UIMUpdatePropList);
  uim_set_prop_label_update_cb((*inSessionHandle)->fUC, UIMUpdatePropLabel);
#ifndef SYNC_MODE
  uim_prop_list_update((*inSessionHandle)->fUC);
  uim_prop_label_update((*inSessionHandle)->fUC);
#endif // SYNC_MODE

  uim_set_candidate_selector_cb((*inSessionHandle)->fUC,
                                UIMCandAcivate,
                                UIMCandSelect,
                                UIMCandShiftPage,
                                UIMCandDeactivate);

#ifdef SYNC_MODE
  uim_set_mode_cb((*inSessionHandle)->fUC,
                  UIMModeUpdate);
#endif
}

static void
CreateAllUIMContext(CFStringRef inIMName)
{
  UInt32 i;

  for (i = 0; i < gNumSession; i++)
    CreateUIMContext(gSessionList[i], inIMName);
}

static void
ReleaseAllUIMContext()
{
  UInt32 i;

  for (i = 0; i < gNumSession; i++) {
    MUIMSessionFix(gSessionList[i]);

    HideCandidateWindow(gSessionList[i]);
    (*gSessionList[i])->fWindowOpened = false;

    uim_release_context((*gSessionList[i])->fUC);
    (*gSessionList[i])->fUC = NULL;
  }
}

#pragma mark -

void
CandClicked(UInt32 inRow)
{
  UInt32 idx = 0;
  
  idx = (*gActiveSession)->fDisplayLimit * (*gActiveSession)->fPageIndex + inRow;
  
#if DEBUG_CANDIDATES
  DEBUG_PRINT("CandClicked() inRow=%lu fPageIndex=%ld idx=%lu\n",
              inRow, (*gActiveSession)->fPageIndex, idx);
#endif
  
  uim_set_candidate_index((*gActiveSession)->fUC, idx);
  
  uim_press_key((*gActiveSession)->fUC, 'j', UMod_Control);
  uim_release_key((*gActiveSession)->fUC, 'j', UMod_Control);
}

static void
NotificationCallback(CFNotificationCenterRef inCenter, void *inObserver, 
                     CFStringRef inName, const void *inObject, 
                     CFDictionaryRef inUserInfo)
{
  CFStringRef im;
  char imName[BUFSIZ];
  CFBooleanRef on;
  CFStringRef fontName;
  CFNumberRef fontSize;
  CFNumberRef trans;
  UInt32 i;
  
  im = CFDictionaryGetValue(inUserInfo, CFSTR(kPrefIM));
  CFStringGetCString(im, imName, BUFSIZ, kCFStringEncodingMacRoman);

#if DEBUG_NOTIFY
  DEGUG_PRINT("NotificationCallback() im='%s'\n", imName);
#endif
  
  if ((on = CFDictionaryGetValue(inUserInfo, CFSTR(kPrefCandVertical))))
    gCandVertical = on == kCFBooleanTrue ? true : false;
  
  // candidate font
  if ((fontName = CFDictionaryGetValue(inUserInfo, CFSTR(kPrefCandFont)))) {
    if (gCandFont)
      CFRelease(gCandFont);
    gCandFont = CFRetain(fontName);
    if ((fontSize = CFDictionaryGetValue(inUserInfo, CFSTR(kPrefCandFontSize))))
      CFNumberGetValue(fontSize, kCFNumberFloatType, &gCandFontSize);

    for (i = 0; i < gNumSession; i++)
      SetCandidateFont(gSessionList[i], gCandFont, gCandFontSize);
  }
    
  if ((trans = CFDictionaryGetValue(inUserInfo, CFSTR(kPrefCandTransparency))))
    CFNumberGetValue(trans, kCFNumberIntType, &gCandTransparency);
  
  if ((on = CFDictionaryGetValue(inUserInfo, CFSTR(kPrefModeTips))))
    gEnableModeTips = on == kCFBooleanTrue ? true : false;
  
#if DEBUG_NOTIFY
  DEBUG_PRINT("NotificationCallback() vertical=%s transparency=%s modetips=%s\n",
              gCandVertical ? "true" : "false",
              gCandTransparency ? "true" : "false",
              gEnableModeTips ? "true" : "false");
#endif

  if (im) {
    if (gIMName)
      CFRelease(gIMName);
    gIMName = im;
    CFRetain(im);
  
    ReleaseAllUIMContext();
    CreateAllUIMContext(im);

#ifdef SYNC_MODE
    DEBUG_PRINT("NotificationCallback() gMode=%d -> -1\n", gMode);
    gMode = -1;
    for (i = 0; i < gNumSession; i++) {
      uim_prop_list_update((*gSessionList[i])->fUC);
      uim_prop_label_update((*gSessionList[i])->fUC);
    }
#else
    uim_prop_list_update((*gActiveSession)->fUC);
    uim_prop_label_update((*gActiveSession)->fUC);
#endif
  }
}

#pragma mark -

/*
 * key codes are defined in
 * /System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/Headers/Events.h
 */
static int
ConvertKeyVal(int inKey, int inMod)
{
  int key = inKey;

#if DEBUG_KEYEVENT
  DEBUG_PRINT("ConvertKeyVal() inKey=0x%02x inMod=0x%02x\n", inKey, inMod);
#endif

  if (inKey >= 0x01 && inKey <= 0x1a) {
    if (inMod & shiftKey)
      key += 0x40;
    else
      key += 0x60;
  }

  return key;
}

static int
ConvertModifier(int inMod)
{
  int modifier = 0;

#if DEBUG_KEYEVENT
  DEBUG_PRINT("ConvertModifier() inMod=0x%02x\n", inMod);
#endif

  if (inMod & shiftKey)
    modifier += UMod_Shift;
  if (inMod & controlKey)
    modifier += UMod_Control;
  if (inMod & optionKey)
    modifier += UMod_Alt;

  return modifier;
}
