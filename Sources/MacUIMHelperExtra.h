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

#import <Foundation/Foundation.h>
#import <uim.h>
#import <uim-helper.h>
#import "SystemUIPlugin.h"
#import "MacUIMHelperView.h"


#define kMenuBarWidth   19
#define kMenuBarWidth2  38
#define kMenuBarWidth3  57
#define kMenuBarHeight  22


@interface MacUIMHelperExtra : NSMenuExtra
{
  NSMenu *menu;
  MacUIMHelperView *view;

#ifdef NEW_HELPER
  int is_helper_connect;
#else
  int uimFD;
#endif
  NSFileHandle *uimHandle;

  NSString *imName;

  NSMutableArray *branchPoints;
  NSMutableArray *modes;
  NSMutableArray *propNames;
  NSMutableArray *menuItems;

  NSMutableArray *labels;

  NSMutableArray *imNames;
  NSMutableArray *imItems;

  BOOL clicked;
}

- (NSImage *)createImage:(BOOL)alter;
- (void)renderFrame:(NSImage *)image;
- (void)renderText:(NSImage *)image;
- (void)updateMenu;
- (void)modeSelect:(id)sender;
- (void)imSelect:(id)sender;
- (void)openSystemPrefs:(id)sender;
- (int)helperConnect;
- (void)helperRead:(NSNotification *)notification;
- (void)helperParse:(char *)str;
- (void)helperClose;
- (void)helperDisconnect;
- (void)propListUpdate:(NSArray *)lines;
- (void)propLabelUpdate:(NSArray *)lines;
- (void)loadPrefs;

+ (id)sharedExtra;

@end
