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

#import <Cocoa/Cocoa.h>

#import "UimCustom.h"
#import "UimCustomKeyController.h"


@interface UimCustomKey : UimCustom <KeyFieldEditorInputProtocol>
{
  NSMutableArray *keyArray;
  NSEvent *lastEvent;
  NSText *lastFieldEditor;
}

- (void)reloadCustom;
- (void)displayCustom;
- (void)setAction;
- (void)setDefault;

- (void)rebuildKeyArray;

- (NSString *)uimKeyToString:(const char *)key;
- (NSString *)keyEventToString:(NSEvent *)theEvent;
- (NSString *)keyEventToUimLiteral:(NSEvent *)theEvent;

- (IBAction)click:(id)sender;

- (NSString *)keyFieldEditor:(KeyFieldEditor *)editor
                  inputEvent:(NSEvent *)theEvent;

@end


@interface UimKey : NSObject
{
  struct uim_custom_key *uimKey;
  BOOL added;
}

- (id)initWithUimKey:(struct uim_custom_key *)aUimKey;
- (id)initWithUimKey:(struct uim_custom_key *)aUimKey
               added:(BOOL)add;
- (struct uim_custom_key *)uimKey;
- (void)setUimKey:(struct uim_custom_key *)aUimKey;

@end

