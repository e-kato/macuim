/* -*- mode:c; coding:utf-8; tab-width:8; c-basic-offset:2; indent-tabs-mode:nil -*- */
/*
  Copyright (c) 2003-2009 MacUIM contributors, All rights reserved.

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

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS IS'' AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE
  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
  SUCH DAMAGE.
*/

static struct {
  const unsigned char keycode;
  const int ukey;
  const char *label;
} KeycodeToUKey[] = {
  { 0x24, UKey_Return, "return" },
  { 0x30, UKey_Tab, "tab" },
  { 0x33, UKey_Backspace, "backspace" },
  { 0x34, UKey_Return, "return" },
  { 0x35, UKey_Escape, "escape" },
  { 0x4c, UKey_Return, "return" },
  { 0x60, UKey_F5, "F5" },
  { 0x61, UKey_F6, "F6" },
  { 0x62, UKey_F7, "F7" },
  { 0x63, UKey_F3, "F3" },
  { 0x64, UKey_F8, "F8" },
  { 0x65, UKey_F9, "F9" },
  { 0x66, UKey_Private1, "Private1" },  /* Eisu Key */
  { 0x67, UKey_F11, "F11" },
  { 0x68, UKey_Private2, "Private2" },  /* Kana Key */
  { 0x69, UKey_F13, "F13" },
  { 0x6b, UKey_F14, "F14" },
  { 0x6d, UKey_F10, "F10" },
  { 0x6f, UKey_F12, "F12" },
  { 0x71, UKey_F15, "F15" },
  { 0x73, UKey_Home, "home" },
  { 0x74, UKey_Prior, "prior" },
  { 0x75, UKey_Delete, "delete" },
  { 0x77, UKey_End, "end" },
  { 0x76, UKey_F4, "F4" },
  { 0x78, UKey_F2, "F2" },
  { 0x79, UKey_Next, "next" },
  { 0x7a, UKey_F1, "F1" },
  { 0x7b, UKey_Left, "left" },
  { 0x7c, UKey_Right, "right" },
  { 0x7d, UKey_Down, "down" },
  { 0x7e, UKey_Up, "up" },
  { 0, 0, 0 }
};

// convert control sequence to keycode
static struct {
  const unsigned char charcode;
  const int ckey; // with <control>
} CharToKey[] = {
  { 0x1f, '-' },
  { 0x36, '^' },
  { 0x1c, '\\' },
  { 0x32, '@' },
  { 0x1b, '[' },
  { 0x1d, ']' },
  { 0, 0 }
};
