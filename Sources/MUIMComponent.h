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

#ifndef MUIMComponent_h
#define MUIMComponent_h

#include <Carbon/Carbon.h>

// Component callbacks

pascal ComponentResult
MUIMOpenComponent(ComponentInstance inComponentInstance);

pascal ComponentResult
MUIMCloseComponent(Handle inSessionHandle,
                   ComponentInstance inComponentInstance);

pascal ComponentResult
MUIMCanDo(SInt16 inSelector);

pascal ComponentResult
MUIMGetVersion(void);


// TSM callbacks

pascal ComponentResult
MUIMGetScriptLangSupport(Handle inSessionHandle,
                         ScriptLanguageSupportHandle *outScriptHandle);
pascal ComponentResult
MUIMInitiateTextService(Handle inSessionHandle);

pascal ComponentResult
MUIMTerminateTextService(Handle inSessionHandle);

pascal ComponentResult
MUIMActivateTextService(Handle inSessionHandle);

pascal ComponentResult
MUIMDeactivateTextService(Handle inSessionHandle);

pascal ComponentResult MUIMTextServiceEventRef(Handle inSessionHandle,
                                               EventRef inEventRef);

pascal ComponentResult
MUIMGetTextServiceMenu(Handle inSessionHandle, MenuHandle *outMenuHandle);

pascal ComponentResult
MUIMFixTextService(Handle inSessionHandle);

pascal ComponentResult
MUIMHidePaletteWindows(Handle inSessionHandle);

#if 0
pascal ComponentResult
MUIMGetTextServiceProperty(Handle inSessionHandle, OSType inPropSelector,
                           SInt32 *outProp);
#endif

pascal ComponentResult
MUIMSetTextServiceProperty(Handle inSessionHandle, OSType inPropSelector,
                           SInt32 inProp);

enum
{
    uppOpenComponentProcInfo = kPascalStackBased
    | RESULT_SIZE(SIZE_CODE(sizeof(ComponentResult)))
    | STACK_ROUTINE_PARAMETER(1, SIZE_CODE(sizeof(ComponentInstance))),

    uppCloseComponentProcInfo = kPascalStackBased
    | RESULT_SIZE(SIZE_CODE(sizeof(ComponentResult)))
    | STACK_ROUTINE_PARAMETER(1, SIZE_CODE(sizeof(Handle)))
    | STACK_ROUTINE_PARAMETER(2, SIZE_CODE(sizeof(ComponentInstance))),

    uppCanDoProcInfo = kPascalStackBased
    | RESULT_SIZE(SIZE_CODE(sizeof(ComponentResult)))
    | STACK_ROUTINE_PARAMETER(1, SIZE_CODE(sizeof(short))),

    uppGetVersionProcInfo = kPascalStackBased
    | RESULT_SIZE(SIZE_CODE(sizeof(ComponentResult))),

    uppGetScriptLangSupportProcInfo = kPascalStackBased
    | RESULT_SIZE(SIZE_CODE(sizeof(ComponentResult)))
    | STACK_ROUTINE_PARAMETER(1, SIZE_CODE(sizeof(Handle)))
    | STACK_ROUTINE_PARAMETER(2, SIZE_CODE(sizeof(ScriptLanguageSupportHandle *))),

    uppInitiateTextServiceProcInfo = kPascalStackBased
    | RESULT_SIZE(SIZE_CODE(sizeof(ComponentResult)))
    | STACK_ROUTINE_PARAMETER(1, SIZE_CODE(sizeof(Handle))),

    uppTerminateTextServiceProcInfo = kPascalStackBased
    | RESULT_SIZE(SIZE_CODE(sizeof(ComponentResult)))
    | STACK_ROUTINE_PARAMETER(1, SIZE_CODE(sizeof(Handle))),

    uppActivateTextServiceProcInfo = kPascalStackBased
    | RESULT_SIZE(SIZE_CODE(sizeof(ComponentResult)))
    | STACK_ROUTINE_PARAMETER(1, SIZE_CODE(sizeof(Handle))),

    uppDeactivateTextServiceProcInfo = kPascalStackBased
    | RESULT_SIZE(SIZE_CODE(sizeof(ComponentResult)))
    | STACK_ROUTINE_PARAMETER(1, SIZE_CODE(sizeof(Handle))),

    uppTextServiceEventRefProcInfo = kPascalStackBased
    | RESULT_SIZE(SIZE_CODE(sizeof(ComponentResult)))
    | STACK_ROUTINE_PARAMETER(1, SIZE_CODE(sizeof(Handle)))
    | STACK_ROUTINE_PARAMETER(2, SIZE_CODE(sizeof(EventRef))),

    uppGetTextServiceMenuProcInfo = kPascalStackBased
    | RESULT_SIZE(SIZE_CODE(sizeof(ComponentResult)))
    | STACK_ROUTINE_PARAMETER(1, SIZE_CODE(sizeof(Handle)))
    | STACK_ROUTINE_PARAMETER(2, SIZE_CODE(sizeof(MenuHandle *))),

    uppFixTextServiceProcInfo = kPascalStackBased
    | RESULT_SIZE(SIZE_CODE(sizeof(ComponentResult)))
    | STACK_ROUTINE_PARAMETER(1, SIZE_CODE(sizeof(Handle))),

    uppHidePaletteWindowsProcInfo = kPascalStackBased
    | RESULT_SIZE(SIZE_CODE(sizeof(ComponentResult)))
    | STACK_ROUTINE_PARAMETER(1, SIZE_CODE(sizeof(Handle))),

    uppGetTextServicePropertyProcInfo = kPascalStackBased
    | RESULT_SIZE(SIZE_CODE(sizeof(ComponentResult)))
    | STACK_ROUTINE_PARAMETER(1, SIZE_CODE(sizeof(Handle)))
    | STACK_ROUTINE_PARAMETER(2, SIZE_CODE(sizeof(OSType)))
    | STACK_ROUTINE_PARAMETER(2, SIZE_CODE(sizeof(SInt32 *))),

    uppSetTextServicePropertyProcInfo = kPascalStackBased
    | RESULT_SIZE(SIZE_CODE(sizeof(ComponentResult)))
    | STACK_ROUTINE_PARAMETER(1, SIZE_CODE(sizeof(Handle)))
    | STACK_ROUTINE_PARAMETER(2, SIZE_CODE(sizeof(OSType)))
    | STACK_ROUTINE_PARAMETER(2, SIZE_CODE(sizeof(SInt32)))
};

#endif  /* MUIMComponent_h */
