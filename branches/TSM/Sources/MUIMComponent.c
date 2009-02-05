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

#include <Carbon/Carbon.h>

#include "MUIM.h"
#include "MUIMComponent.h"
#include "MUIMScript.h"

pascal ComponentResult MUIMComponentDispatch(ComponentParameters * inParams,
                                             Handle inSessionHandle);

extern MUIMSessionHandle gActiveSession;

long gInstanceRefCount = 0;
MenuRef gTextServiceMenu = nil;

static ComponentResult
CallMUIMFunction(ComponentParameters *inParams, ProcPtr inProcPtr,
                 SInt32 inProcInfo);

static ComponentResult
CallMUIMFunctionWithStorage(Handle inStorage, ComponentParameters *inParams,
                            ProcPtr inProcPtr, SInt32 inProcInfo);

#pragma mark -

/**
 * This routine is the main entry point for our text service component.
 * All calls to our component go through this entry point.
 * We examine the selector (inParams->what) and dispatch the call to the
 * appropriate handler.
 *
 * @param  inParams         Parameters for this call.
 * @param  inSessionHandle  Our session context.
 *
 * @return ComponentResult  A toolbox error code.
 */
pascal ComponentResult
MUIMComponentDispatch(ComponentParameters * inParams, Handle inSessionHandle)
{
  ComponentResult result = noErr;

#if DEBUG_COMPONENT
  DEBUG_PRINT("MUIMComponentDispatch() what=%ld\n", inParams->what);
#endif

  switch (inParams->what) {
  case kComponentOpenSelect:
    result = CallMUIMFunction(inParams, (ProcPtr) MUIMOpenComponent,
                              uppOpenComponentProcInfo);
    break;

  case kComponentCloseSelect:
    result = CallMUIMFunctionWithStorage(inSessionHandle, inParams,
                                         (ProcPtr) MUIMCloseComponent,
                                         uppCloseComponentProcInfo);
    break;

  case kComponentCanDoSelect:
    result = CallMUIMFunction(inParams, (ProcPtr) MUIMCanDo,
                              uppCanDoProcInfo);
    break;

  case kComponentVersionSelect:
    result = CallMUIMFunction(inParams, (ProcPtr) MUIMGetVersion,
                              uppGetVersionProcInfo);
    break;

  case kCMGetScriptLangSupport:
    result = CallMUIMFunctionWithStorage(inSessionHandle, inParams,
                                         (ProcPtr) MUIMGetScriptLangSupport,
                                         uppGetScriptLangSupportProcInfo);
    break;

  case kCMInitiateTextService:
    result = CallMUIMFunctionWithStorage(inSessionHandle, inParams,
                                         (ProcPtr) MUIMInitiateTextService,
                                         uppInitiateTextServiceProcInfo);
    break;

  case kCMTerminateTextService:
    result = CallMUIMFunctionWithStorage(inSessionHandle, inParams,
                                         (ProcPtr) MUIMTerminateTextService,
                                         uppTerminateTextServiceProcInfo);
    break;

  case kCMActivateTextService:
    result = CallMUIMFunctionWithStorage(inSessionHandle, inParams,
                                         (ProcPtr) MUIMActivateTextService,
                                         uppActivateTextServiceProcInfo);
    break;

  case kCMDeactivateTextService:
    result = CallMUIMFunctionWithStorage(inSessionHandle, inParams,
                                         (ProcPtr) MUIMDeactivateTextService,
                                         uppDeactivateTextServiceProcInfo);
    break;

  case kCMTextServiceEvent:
    result = CallMUIMFunctionWithStorage(inSessionHandle, inParams,
                                         (ProcPtr) MUIMTextServiceEventRef,
                                         uppTextServiceEventRefProcInfo);
    break;

  case kCMGetTextServiceMenu:
    result = CallMUIMFunctionWithStorage(inSessionHandle, inParams,
                                         (ProcPtr) MUIMGetTextServiceMenu,
                                         uppGetTextServiceMenuProcInfo);
    break;

  case kCMFixTextService:
    result = CallMUIMFunctionWithStorage(inSessionHandle, inParams,
                                         (ProcPtr) MUIMFixTextService,
                                         uppFixTextServiceProcInfo);
    break;

  case kCMHidePaletteWindows:
    break;

#if 0
  case kCMGetTextServiceProperty:
    result = CallMUIMFunctionWithStorage(inSessionHandle, inParams,
                                         (ProcPtr) MUIMGetTextServiceProperty,
                                         uppGetTextServicePropertyProcInfo);
    break;
#endif

  case kCMSetTextServiceProperty:
    result = CallMUIMFunctionWithStorage(inSessionHandle, inParams,
                                         (ProcPtr) MUIMSetTextServiceProperty,
                                         uppSetTextServicePropertyProcInfo);
    break;

  /*
  case kCMUCTextServiceEvent:
    DEBUG_PRINT("MUIMComponentDispatch() kCMUCTextServiceEvent¥n");
    break;
  case kCMCopyTextServiceInputModeList:
  */    

  default:
    result = badComponentSelector;
    break;
  }
  
#if DEBUG_COMPONENT
  DEBUG_PRINT("MUIMComponentDispatch() result=%d\n", result);
#endif
  
  return result;
}

#pragma mark -

/**
 * This routine is called directly via OpenComponent, or indirectly via
 * NewTSMDocument.
 * If this the first instance of our component, we initialize our global state
 * (IMInitialize).
 * Then we initialize a new session context (IMOpenSession). 
 *
 * @param  inComponentInstance  The component instance.
 *
 * @return ComponentResult      A toolbox error code.
 */
pascal ComponentResult
MUIMOpenComponent(ComponentInstance inComponentInstance)
{
  ComponentResult result = noErr;
  Handle sessionHandle = nil;

#if DEBUG_COMPONENT
  DEBUG_PRINT("MUIMOpenComponent() count=%ld + 1\n", gInstanceRefCount);
#endif

  if (gInstanceRefCount == 0)
    result = MUIMInitialize(inComponentInstance, &gTextServiceMenu);
  gInstanceRefCount++;

  if (result == noErr) {
    sessionHandle = GetComponentInstanceStorage(inComponentInstance);
    result = MUIMSessionOpen(inComponentInstance,
                             (MUIMSessionHandle *) &sessionHandle);

    if (result == noErr)
      SetComponentInstanceStorage(inComponentInstance, sessionHandle);
  }

  return result;
}

/**
 * This routine is called directly via CloseComponent, or indirectly via
 * DeleteTSMDocument.
 * In this routine we terminate the current session context (IMCloseSession).
 * If this the last remaining instance of our component, we also terminate our
 * global state (IMTerminate). 
 *
 * @param  inSessionHandle      Our session context.
 * @param  inComponentInstance  The component instance.
 *
 * @return ComponentResult      A toolbox error code.
 */
pascal ComponentResult
MUIMCloseComponent(Handle inSessionHandle, ComponentInstance inComponentInstance)
{
  ComponentResult result = noErr;

#if DEBUG_COMPONENT
  DEBUG_PRINT("MUIMCloseComponent() count=%d - 1\n", gInstanceRefCount);
#endif

  if (inComponentInstance == nil)
    result = paramErr;
  else {
    MUIMSessionClose((MUIMSessionHandle) inSessionHandle);
    SetComponentInstanceStorage(inComponentInstance, nil);

    gInstanceRefCount--;
    if (gInstanceRefCount == 0)
      MUIMTerminate(inComponentInstance);
  }

  return result;
}

/**
 * Return true if the routine indicated by "selector" is one that we support,
 * otherwise return false.
 * The Text Services Manager does not currently call this routine.
 *
 * @param  inSelector       The selector to check for.
 *
 * @return ComponentResult  True if we support the selector, otherwise false.
 */
pascal ComponentResult
MUIMCanDo(SInt16 inSelector)
{
  Boolean result;

#if DEBUG_COMPONENT
  DEBUG_PRINT("MUIMCanDo() inSelector=%d\n", inSelector);
#endif

  switch (inSelector) {
  case kComponentOpenSelect:
  case kComponentCloseSelect:
  case kComponentCanDoSelect:
  case kComponentVersionSelect:
  case kCMGetScriptLangSupport:
  case kCMInitiateTextService:
  case kCMTerminateTextService:
  case kCMActivateTextService:
  case kCMDeactivateTextService:
  case kCMTextServiceEvent:
  case kCMGetTextServiceMenu:
  case kCMFixTextService:
  case kCMHidePaletteWindows:
  //case kCMGetTextServiceProperty:
  case kCMSetTextServiceProperty:
  //case kCMUCTextServiceEvent:
    result = true;
    break;

  default:
    result = false;
    break;
  }
  return result;
}

/**
 * This routine is called directly via GetComponentVersion. The Text Services
 * Manager does not currently call this routine
 *
 * @return ComponentResult  The version of this component.
 *
 */
pascal ComponentResult
MUIMGetVersion(void)
{
#if DEBUG_COMPONENT
  DEBUG_PRINT("MUIMGetVersion()\n");
#endif

  return 0x00010000;
}

/**
 * This routine is called by the Text Services Manager to determine our input
 * method type.
 *
 * @param  inSessionHandle  Our session context.
 * @param  outScriptHandle  A handle to an array of script/language records.
 * @return ComponentResult  A toolbox error code.
 */
pascal ComponentResult
MUIMGetScriptLangSupport(Handle inSessionHandle,
                         ScriptLanguageSupportHandle * outScriptHandle)
{
#pragma unused (inSessionHandle)

#if DEBUG_COMPONENT
  DEBUG_PRINT("MUIMGetScriptLangSupport()\n");
#endif

  OSStatus result;
  ScriptLanguageRecord scriptLanguageRecord;

  result = noErr;

  if (*outScriptHandle == NULL) {
    *outScriptHandle =
      (ScriptLanguageSupportHandle) NewHandle(sizeof(SInt16));
    if (*outScriptHandle == NULL)
      result = memFullErr;
  }

  if (result == noErr) {
    SetHandleSize((Handle) *outScriptHandle, sizeof(SInt16));
    result = MemError();
    if (result == noErr)
      (**outScriptHandle)->fScriptLanguageCount = 0;
  }

  if (result == noErr) {
    scriptLanguageRecord.fScript = kTextEncodingUnicodeDefault;
    scriptLanguageRecord.fLanguage = kMUIMLanguage;
    result = PtrAndHand(&scriptLanguageRecord, (Handle) *outScriptHandle,
                        sizeof(ScriptLanguageRecord));
    if (result == noErr)
      (**outScriptHandle)->fScriptLanguageCount++;
  }

  if (result) {
    if (*outScriptHandle) {
      DisposeHandle((Handle) *outScriptHandle);
      *outScriptHandle = NULL;
    }
  }
  return result;
}

/***
 * This routine is called by the Text Services Manager whenever an application
 * calls NewTSMDocument. However, since MUIMTerminateTextService is never
 * called, we do nothing.
 *
 * @param  inSessionHandle  Our session context.
 *
 * @return ComponentResult  A toolbox error code.
 */
pascal ComponentResult
MUIMInitiateTextService(Handle inSessionHandle)
{
#pragma unused (inSessionHandle)

#if DEBUG_COMPONENT
  DEBUG_PRINT("MUIMInitiateTextService()\n");
#endif

  return noErr;
}

/**
 * This routine is never called by the Text Services Manager. Do nothing.
 *
 * @param  inSessionHandle  Our session context.
 *
 * @return ComponentResult  A toolbox error code.
 */
pascal ComponentResult
MUIMTerminateTextService(Handle inSessionHandle)
{
#pragma unused (inSessionHandle)

#if DEBUG_COMPONENT
  DEBUG_PRINT("MUIMTerminateTextService()\n");
#endif

  return noErr;
}

/**
 * This routine is called by the Text Services Manager whenever an application
 * calls NewTSMDocument or ActivateTSMDocument. The appropriate response to
 * ActivateTextService is to restore our active state, including displaying all
 * floating windows if they have been hidden, and redisplaying any inconfirmed
 * text in the currently active input area.
 * We call our core routine MUIMSessionActivate() to handle activation.
 *
 * @param  inSessionHandle  Our session context.
 *
 * @return ComponentResult  A toolbox error code.
 */
pascal ComponentResult
MUIMActivateTextService(Handle inSessionHandle)
{
#if DEBUG_COMPONENT
  DEBUG_PRINT("MUIMActivateTextService()\n");
#endif

  return MUIMSessionActivate((MUIMSessionHandle) inSessionHandle);
}

/**
 * This routine is called by the Text Services Manager whenever an application
 * calls DeactivateTSMDocument. We are responsible for saving whatever state
 * information we need to save so that we can restore it again when we are
 * reactivated. We should not confirm any unconfirmed text in the active input
 * area, but save it until reactivation. We should not hide our floating
 * windows either.
 * We call our core routine MUIMSessionDeactivate() to handle deactivation.
 *
 * @param  inSessionHandle  Our session context.
 *
 * @return ComponentResult  A toolbox error code.
 */
pascal ComponentResult
MUIMDeactivateTextService(Handle inSessionHandle)
{
#if DEBUG_COMPONENT
  DEBUG_PRINT("MUIMDeactivateTextService()\n");
#endif

  return MUIMSessionDeactivate((MUIMSessionHandle) inSessionHandle);
}

/**
 * This routine is called in response to a user event (currently only key
 * events and mouse events are passed) within our current context.
 * We call our core routine MUIMSessionEvent() to handle the event.
 *
 * @param inSessionHandle   Our session context.
 * @param inEventRef        The event that needs to be handled.
 *
 * @return ComponentResult  A toolbox error code.
 */
pascal ComponentResult
MUIMTextServiceEventRef(Handle inSessionHandle, EventRef inEventRef)
{
#if DEBUG_COMPONENT
  DEBUG_PRINT("MUIMTextServiceEventRef()\n");
#endif

  return MUIMSessionEvent((MUIMSessionHandle) inSessionHandle, inEventRef);
}

/**
 * This routine is called by the Text Services Manager when our text service
 * component is opened or activated, so that it can put our component's menu on
 * the menu bar.
 * We return a reference to our text service (pencil) menu handle in
 * outMenuHandle.
 *
 * @param  inSessionHandle  Our session context.
 *
 * @param  outMenuHandle    reference to our text service (pencil) menu.
 * @return ComponentResult  A toolbox error code.
 */
pascal ComponentResult
MUIMGetTextServiceMenu(Handle inSessionHandle, MenuHandle * outMenuHandle)
{
#if DEBUG_COMPONENT
  DEBUG_PRINT("MUIMGetTextServiceMenu()\n");
#endif

  *outMenuHandle = gTextServiceMenu;
  
  return noErr;
}

/**
 * This routine is called by the Text Services Manager to notify us that we
 * must "fix" or complete processing of any input that is in progress.
 * We call our core routine MUIMSessionFix() to handle the event.
 *
 * @param  inSessionHandle  Our session context.
 *
 * @return ComponentResult  A toolbox error code.
 */
pascal ComponentResult
MUIMFixTextService(Handle inSessionHandle)
{
#if DEBUG_COMPONENT
  DEBUG_PRINT("MUIMFixTextService()\n");
#endif

  return MUIMSessionFix((MUIMSessionHandle) inSessionHandle);
}

#if 0
pascal ComponentResult
MUIMGetTextServiceProperty(Handle inSessionHandle, OSType inPropSelector,
                           SInt32 *outProp)
{
#if DEBUG_INPUTMODE
  DEBUG_PRINT("MUIMGetTextServiceProperty %ul %ul\n",
              inPropSelector, kTextServiceInputModePropertyTag);
#endif
  
  return noErr;
}
#endif

pascal ComponentResult
MUIMSetTextServiceProperty(Handle inSessionHandle, OSType inPropSelector,
                           SInt32 inProp)
{
  ComponentResult result;
  
  switch (inPropSelector) {
  //case kTextServiceJaTypingMethodPropertyTag:
  case kTextServiceInputModePropertyTag:
  case kIMJaTypingMethodProperty:
  case kIMJaTypingMethodRoman:
  case kIMJaTypingMethodKana:
    DEBUG_PRINT("MUIMSetTextServiceProperty() inPropSelector=%ld\n",
                inPropSelector);
    result = noErr;
    break;

  default:
    result = MUIMSetInputMode((MUIMSessionHandle) inSessionHandle,
                              (CFStringRef) inPropSelector);
  }

  return result;
}

#pragma mark -

/**
 * Glue code to create a Universal Procedure Pointer for our internal dispatch
 * routines and call them.
 *
 * @param inParams          Component Manager parameters.
 * @param inProcPtr         A pointer to the procedure to call.
 * @param inProcInfo        Paramters accepted by the procedure.
 *
 * @return ComponentResult  A toolbox error code.
 */
static ComponentResult
CallMUIMFunction(ComponentParameters *inParams, ProcPtr inProcPtr,
                 SInt32 inProcInfo)
{
  ComponentResult result = noErr;
  ComponentFunctionUPP componentFunctionUPP;

  componentFunctionUPP = NewComponentFunctionUPP(inProcPtr, inProcInfo);
  result = CallComponentFunction(inParams, componentFunctionUPP);
  DisposeComponentFunctionUPP(componentFunctionUPP);
  
  return result;
}

/**
 * Glue code to create a Universal Procedure Pointer for our internal dispatch
 * routines and call them. This takes an additional inStorage parameter for
 * routines that require a reference to the current session handle.
 *
 * @param  inStorage        The session handle.
 * @param  inParams         Component Manager parameters.
 * @param  inProcPtr        A pointer to the procedure to call.
 * @param  inProcInfo       Paramters accepted by the procedure.
 *
 * @return ComponentResult  A toolbox error code.
 */
static ComponentResult
CallMUIMFunctionWithStorage(Handle inStorage, ComponentParameters *inParams,
                            ProcPtr inProcPtr, SInt32 inProcInfo)
{
  ComponentResult result = noErr;
  ComponentFunctionUPP componentFunctionUPP;

  componentFunctionUPP = NewComponentFunctionUPP(inProcPtr, inProcInfo);
  result =
    CallComponentFunctionWithStorage(inStorage, inParams,
                                     componentFunctionUPP);
  DisposeComponentFunctionUPP(componentFunctionUPP);
  
  return result;
}
