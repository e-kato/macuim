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

#import "Debug.h"
#import "UimCustomPathname.h"
#import "UimCustomPathnameController.h"


@implementation UimCustomPathname

- (id)initWithCustom:(struct uim_custom *)aCustom
{
  if (!(self = [super initWithCustom:aCustom]))
    return nil;

  if (!(controller = [[UimCustomPathnameController alloc] init])) {
    [self release];
    return nil;
  }
  [controller retain];

  [self displayCustom];
  [self setAction];
  
  return self;
}

- (void)displayCustom
{
  [[(UimCustomPathnameController *) controller field] setTitleWithMnemonic:[NSString stringWithUTF8String:custom->value->as_pathname->str]];
  [[(UimCustomPathnameController *) controller field] setEnabled:custom->is_active];
}

- (void)setAction
{
  [[(UimCustomPathnameController *) controller button] setTarget:self];
  [[(UimCustomPathnameController *) controller button] setAction:@selector(click:)];
}

- (void)setDefault
{
  free(custom->value->as_pathname->str);
  custom->value->as_pathname->str =
    strdup(custom->default_value->as_pathname->str);
  uim_custom_set(custom);  
}

#pragma mark -

//
// Actions
//

- (IBAction)click:(id)sender
{
  NSOpenPanel *openPanel = [NSOpenPanel openPanel];
  
  [openPanel setCanChooseDirectories:YES];
  [openPanel setCanChooseFiles:YES];
  
  [openPanel beginSheetForDirectory:nil file:nil types:nil
                     modalForWindow:[[NSApplication sharedApplication] keyWindow]
                      modalDelegate:self
                     didEndSelector:@selector(pathnameSelectDidEnd:returnCode:contextInfo:)
                        contextInfo:nil];
}

- (void)pathnameSelectDidEnd:(NSOpenPanel *)sheet
                  returnCode:(int)returnCode
                 contextInfo:(void *)contextInfo
{
  if (!returnCode)
    return;
  
  free(custom->value->as_pathname->str);
  custom->value->as_pathname->str = (char *) strdup([[sheet filename] UTF8String]);
  uim_custom_set(custom);
  
  if ([self isValidDelegateForSelector:@selector(uimCustomModified:)])
    [[self delegate] performSelector:@selector(uimCustomModified:)
                          withObject:self];
}

@end
