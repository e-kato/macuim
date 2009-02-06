/* -*- mode:c; coding:utf-8; tab-width:8; c-basic-offset:4; indent-tabs-mode:nil -*- */
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

#ifndef __UIM_CALLBACK_H__
#define __UIM_CALLBACK_H__

#include <uim.h>
#include <uim-helper.h>


#define kPropListUpdate   "prop_list_update\ncharset=UTF-8"

#define kPropLabelUpdate  "prop_label_update\ncharset=UTF-8"


void
UIMCommitString(void *ptr, const char *str);

void
UIMPreeditClear(void *ptr);

void
UIMPreeditPushback(void *ptr, int attr, const char *str);

void
UIMPreeditUpdate(void *ptr);

void
UIMCandAcivate(void *inPtr, int inNR, int inLimit);

void
UIMCandSelect(void *inPtr, int inIndex);

void
UIMCandShiftPage(void *inPtr, int inForward);

void
UIMCandDeactivate(void *inPtr);

void
UIMUpdatePropList(void *inPtr, const char *inStr);

void
UIMUpdatePropLabel(void *inPtr, const char *inStr);

void
UIMCheckHelper();

void
UIMHelperDisconnect();

void
UIMHelperClose();

void
UIMModeUpdate(void *inPtr, int inMode);

#endif  /* __UIM_CALLBACK_H__ */
