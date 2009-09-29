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

#import "ModeTipsController.h"

static ModeTipsController *sharedController;

@implementation ModeTipsController

+ (id)sharedController
{
  return sharedController;
}

/*
 * Initialize the mode-tips contoller
 */
- (void)awakeFromNib
{
  sharedController = self;
  
  realModeTipsPanel = [[ModeTipsPanel alloc]
                        initWithContentRect:[[modeTipsPanel contentView] frame]
                                  styleMask:NSBorderlessWindowMask
                                    backing:[modeTipsPanel backingType]
                                      defer:NO];
  
  [realModeTipsPanel initView];
  
  [realModeTipsPanel setBackgroundColor:[NSColor whiteColor]];
  [realModeTipsPanel setHasShadow:YES];

  [realModeTipsPanel setBecomesKeyOnlyIfNeeded:NO];
  [realModeTipsPanel setHidesOnDeactivate:NO];
  
  modeTipsTimer = nil;
  lastLabel = nil;

  [realModeTipsPanel setFloatingPanel:YES];
}  

- (void)showModeTips:(NSRect)cursorRect:(NSArray *)lines
{
  float x, y;
  NSRect rect;
  NSArray *labels;
  NSPoint point = cursorRect.origin;

  if (point.x == 0 && point.y == 0) {
    // cannot get window position
    return;
  }
  
  if (!lines || [lines count] <= 0) {
    // there is no label string
    return;
  }
  
#if 0
  if (lastLabel &&
      [lastLabel compare:[lines objectAtIndex:0]] == NSOrderedSame) {
    // current label string is same as the last one
    return;
  }
#endif
  
  [lastLabel release];
  lastLabel = [lines objectAtIndex:0];
  [lastLabel retain];
  
  labels = lines;
  
  [realModeTipsPanel showLabels:labels];
  
  rect = [realModeTipsPanel frame];
  
  x = point.x;
  y = point.y - rect.size.height;
  [realModeTipsPanel setFrameOrigin:NSMakePoint(x, y)];
  
  [realModeTipsPanel orderFront:nil];
  [realModeTipsPanel setLevel:NSFloatingWindowLevel];
  
  if (modeTipsTimer)
    [modeTipsTimer invalidate];
  
  opacity = 100;
  
  modeTipsTimer =
    [NSTimer scheduledTimerWithTimeInterval:0.25
                                     target:self
                                   selector:@selector(modeTipsFadeStart:)
                                   userInfo:nil
                                    repeats:NO];
}

- (void)hideModeTips
{
  [realModeTipsPanel orderOut:nil];
}

- (void)modeTipsFadeStart:(NSTimer *)timer
{
  [modeTipsTimer invalidate];
  modeTipsTimer =
    [NSTimer scheduledTimerWithTimeInterval:0.05
                                     target:self
                                   selector:@selector(modeTipsFade:)
                                   userInfo:nil
                                    repeats:YES];
}

- (void)modeTipsFade:(NSTimer *)timer
{  
  opacity -= 5;
  
  if (opacity <= 0) {
    [self hideModeTips];
    [modeTipsTimer invalidate];
    modeTipsTimer = nil;
  }
  else {
    [realModeTipsPanel setAlphaValue:(float) opacity / 100.0];
    [[realModeTipsPanel view] setNeedsDisplay:YES];
  }
}

@end
