/* -*- mode:objc; coding:utf-8; tab-width:8; c-basic-offset:2; indent-tabs-mode:nil -*- */
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

#ifndef Preference_h
#define Preference_h


// ID of MacUIM component
#define kAppID                "info.yatsu.MacUIM"

// ID of HelperApplet
#define kHelperID             @"info.yatsu.MacUIM.Helper"

// ID of MenuCracker
#define kMenuCrackerBundleID  @"net.sourceforge.menucracker"

// default input method
#define kDefaultIM            "anthy"

// preference attribute name
#define kPrefIM               "InputMethod"

// display direction of candidate window
#define kPrefCandVertical     "CandListVertical"

// transparency of candidate window
#define kPrefCandTransparency "CandTransparency"

// candidate font name
#define kPrefCandFont         "CandFont"

// candidate font size
#define kPrefCandFontSize     "CandFontSize"

// mode-tips enable flag
#define kPrefModeTips         "ShowModeTips"

// annotation enable flag
#define kPrefAnnotation         "ShowAnnotation"

// selectable IMs in helper-applet
#define kPrefHelperIM         "HelperIMSwitch"

// preference changed notification
#define kPrefChanged         "Preferences Chagned"

#endif // Preference_h
