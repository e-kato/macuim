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

#import "ModeTipsPanel.h"

@implementation ModeTipsPanel

- (void)initView
{
  NSView *content;

  modeTipsView = [[ModeTipsView alloc] initWithFrame:[self frame]];
  image = nil;

  content = [[self contentView] retain];
  [content removeFromSuperview];
  [content release];

  [self setContentView:modeTipsView];
}

- (ModeTipsView *)view
{
  return modeTipsView;
}

- (BOOL)canBecomeMainWindow
{
  return YES;
}

- (BOOL)canBecomeKeyWindow
{
  return YES;
}

- (void)showLabels:(NSArray *)labels
{
  [self createImage:labels];
  [modeTipsView setImage:image];
  [self setAlphaValue:1.0];
  [modeTipsView setNeedsDisplay:YES];
}

- (void)createImage:(NSArray *)labels
{
  NSView *view = [self contentView];

  if ([labels count] <= 1) {
    [self setContentSize:NSMakeSize(kModeTipsWidth, kModeTipsHeight)];
    [view setFrameSize:NSMakeSize(kModeTipsWidth, [view frame].size.height)];
    image = [[[NSImage alloc] initWithSize:NSMakeSize(kModeTipsWidth, kModeTipsHeight)]
              autorelease];
  }
  else if ([labels count] == 2) {
    [self setContentSize:NSMakeSize(kModeTipsWidth2, kModeTipsHeight)];
    [view setFrameSize:NSMakeSize(kModeTipsWidth2, [view frame].size.height)];
    image = [[[NSImage alloc] initWithSize:NSMakeSize(kModeTipsWidth2, kModeTipsHeight)]
              autorelease];
  } else {
    [self setContentSize:NSMakeSize(kModeTipsWidth3, kModeTipsHeight)];
    [view setFrameSize:NSMakeSize(kModeTipsWidth3, [view frame].size.height)];
    image = [[[NSImage alloc] initWithSize:NSMakeSize(kModeTipsWidth3, kModeTipsHeight)]
              autorelease];
  }

  [self renderFrame:labels];
  [self renderText:labels];
}

- (void)renderFrame:(NSArray *)labels
{
  NSBezierPath *framePath;
  NSColor *color;

  color = [NSColor blackColor];

  [image lockFocus];

  if ([labels count] <= 1) {
    framePath =
      [NSBezierPath bezierPathWithRect:
        NSMakeRect(0.5, 0.5,
                   kModeTipsWidth - 1.0, kModeTipsHeight - 1.0)];
    [[NSColor whiteColor] set];
    [framePath fill];
  
    [color set];
    [framePath stroke];
  }
  else if ([labels count] == 2) {
    framePath =
      [NSBezierPath bezierPathWithRect:
        NSMakeRect(0.5, 0.5,
                   kModeTipsWidth2 - 1.0, kModeTipsHeight - 1.0)];
    [[NSColor whiteColor] set];
    [framePath fill];

    [color set];
    [framePath stroke];

    [[NSGraphicsContext currentContext] setShouldAntialias:NO];
    framePath = [NSBezierPath bezierPath];
    [framePath moveToPoint:NSMakePoint(kModeTipsWidth2 / 2.0, 0.5)];
    [framePath lineToPoint:NSMakePoint(kModeTipsWidth2 / 2.0, 0.5 + kModeTipsHeight - 1.0)];
    [color set];
    [framePath stroke];
    [[NSGraphicsContext currentContext] setShouldAntialias:YES];
  } else {
    framePath =
      [NSBezierPath bezierPathWithRect:
        NSMakeRect(0.5, 0.5,
                   kModeTipsWidth3 - 1.0, kModeTipsHeight - 1.0)];
    [[NSColor whiteColor] set];
    [framePath fill];
    [color set];
    [framePath stroke];


    [[NSGraphicsContext currentContext] setShouldAntialias:NO];
    framePath = [NSBezierPath bezierPath];
    [framePath moveToPoint:NSMakePoint(kModeTipsWidth3 / 3.0, 0.5)];
    [framePath lineToPoint:NSMakePoint(kModeTipsWidth3 / 3.0, 0.5 + kModeTipsHeight - 1.0)];
    [color set];
    [framePath stroke];

    framePath = [NSBezierPath bezierPath];
    [framePath moveToPoint:NSMakePoint(kModeTipsWidth3 * 2.0 / 3.0, 0.5)];
    [framePath lineToPoint:NSMakePoint(kModeTipsWidth3 * 2.0 / 3.0, 0.5 + kModeTipsHeight - 1.0)];
    [color set];
    [framePath stroke];
    [[NSGraphicsContext currentContext] setShouldAntialias:YES];
  }

  [image unlockFocus];
}

- (void)renderText:(NSArray *)labels
{
  NSMutableAttributedString *text;
  NSMutableString *label = nil;
  NSColor *color;
  int i;

  color = [NSColor blackColor];

  [image lockFocus];

  [[NSGraphicsContext currentContext] setShouldAntialias:YES];

  if ([labels count] < 1)
    label = [[NSMutableString alloc] initWithString:@"?"];

  i = 0;
  do {
    if (!label)
      label = [[NSMutableString alloc] initWithString:[labels objectAtIndex:i]];

    if ([labels count] <= 1) {
      text = [[NSAttributedString alloc]
              initWithString:label
                  attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                    [NSFont boldSystemFontOfSize:12],
                    NSFontAttributeName,
                    color,
                    NSForegroundColorAttributeName,
                    nil]];
      [text drawAtPoint:NSMakePoint(0.5 + 0.5 +
                                    (kModeTipsWidth - 1.0 -
                                     ceil([text size].width + 0.5)) / 2.0,
                                    (kModeTipsHeight - ceil([text size].height)) / 2.0)];
    }
    else if ([labels count] == 2) {
      text = [[NSAttributedString alloc]
              initWithString:label
                  attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                    [NSFont boldSystemFontOfSize:11],
                    NSFontAttributeName,
                    color,
                    NSForegroundColorAttributeName,
                    nil]];
      [text drawAtPoint:NSMakePoint(0.5 + 0.5 +
                                    (i > 0 ? (kModeTipsWidth2 - 1.0) / 2.0 : 0)
                                    + (kModeTipsWidth2 / 2.0 - 0.5 -
                                     ceil([text size].width + 0.5)) / 2.0,
                                    (kModeTipsHeight - ceil([text size].height)) / 2.0)];
    } else {
      text = [[NSAttributedString alloc]
              initWithString:label
                  attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                    [NSFont boldSystemFontOfSize:11],
                    NSFontAttributeName,
                    color,
                    NSForegroundColorAttributeName,
                    nil]];
      if (i == 0) {
      [text drawAtPoint:NSMakePoint(0.5 + 0.5 +
                                    0
                                    + (kModeTipsWidth3 / 3.0 - 0.5 -
                                     ceil([text size].width + 0.5)) / 2.0,
                                    (kModeTipsHeight - ceil([text size].height)) / 2.0)];
      } else if (i == 1) {
      [text drawAtPoint:NSMakePoint(0.5 + 0.5 +
                                    kModeTipsWidth3 / 3.0
                                    + (kModeTipsWidth3 / 3.0 - 0.5 -
                                     ceil([text size].width + 0.5)) / 2.0,
                                    (kModeTipsHeight - ceil([text size].height)) / 2.0)];
      } else if (i == 2) {
      [text drawAtPoint:NSMakePoint(0.5 + 0.5 +
                                    kModeTipsWidth3 * 2.0 / 3.0
                                    + (kModeTipsWidth3 / 3.0 - 0.5 -
                                     ceil([text size].width + 0.5)) / 2.0,
                                    (kModeTipsHeight - ceil([text size].height)) / 2.0)];
      }

    }

    [text release];
    [label release];
    label = nil;

  } while (++i < [labels count]);

  [image unlockFocus];
}

@end
