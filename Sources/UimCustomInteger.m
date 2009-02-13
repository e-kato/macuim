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
#import "UimCustomInteger.h"
#import "UimCustomIntegerController.h"


@implementation UimCustomInteger

- (id)initWithCustom:(struct uim_custom *)aCustom
{
  if (!(self = [super initWithCustom:aCustom]))
    return nil;

  if (!(controller = [[UimCustomIntegerController alloc] init])) {
    [self release];
    return nil;
  }
  [controller retain];

  [self displayCustom];
  [self setRange];
  [self setAction];
  
  return self;
}

- (void)displayCustom
{
  [[(UimCustomIntegerController *) controller field] setTitleWithMnemonic:[NSString stringWithFormat:@"%d", custom->value->as_int]];
  [[(UimCustomIntegerController *) controller stepper] setIntValue:custom->value->as_int];
  [[(UimCustomIntegerController *) controller field] setEnabled:custom->is_active];
  [[(UimCustomIntegerController *) controller stepper] setEnabled:custom->is_active];
}

- (void)setRange
{
  [[[(UimCustomIntegerController *) controller field] formatter] setMinimum:[NSDecimalNumber decimalNumberWithString:[NSString stringWithFormat:@"%d", custom->range->as_int.min]]];
  [[[(UimCustomIntegerController *) controller field] formatter] setMaximum:[NSDecimalNumber decimalNumberWithString:[NSString stringWithFormat:@"%d", custom->range->as_int.max]]];
  [[(UimCustomIntegerController *) controller stepper] setMinValue:custom->range->as_int.min];
  [[(UimCustomIntegerController *) controller stepper] setMaxValue:custom->range->as_int.max];
}

- (void)setAction
{
  [[(UimCustomIntegerController *) controller field] setTarget:self];
  [[(UimCustomIntegerController *) controller field] setAction:@selector(change:)];
  [[(UimCustomIntegerController *) controller stepper] setTarget:self];
  [[(UimCustomIntegerController *) controller stepper] setAction:@selector(change:)];
}

- (void)setDefault
{
  custom->value->as_int = custom->default_value->as_int;
  uim_custom_set(custom);
}

#pragma mark -

//
// Actions
//

- (IBAction)change:(id)sender
{
  custom->value->as_int = [sender intValue];
  uim_custom_set(custom);
  
  if ([self isValidDelegateForSelector:@selector(uimCustomModified:)])
    [[self delegate] performSelector:@selector(uimCustomModified:)
                          withObject:self];
}

@end
