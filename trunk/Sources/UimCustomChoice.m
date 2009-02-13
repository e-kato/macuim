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
#import "UimCustomChoice.h"
#import "UimCustomChoiceController.h"


@implementation UimCustomChoice

- (id)initWithCustom:(struct uim_custom *)aCustom
{
  if (!(self = [super initWithCustom:aCustom]))
    return nil;

  if (!(controller = [[UimCustomChoiceController alloc] init])) {
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
  int i;
  
  [[(UimCustomChoiceController *) controller button] removeAllItems];
  for (i = 0;
       custom->range->as_choice.valid_items &&
       custom->range->as_choice.valid_items[i];
       i++) {
    [[(UimCustomChoiceController *) controller button] addItemWithTitle:[NSString stringWithUTF8String:custom->range->as_choice.valid_items[i]->label]];
    if (!strcmp(custom->range->as_choice.valid_items[i]->symbol,
                custom->value->as_choice->symbol))
      [[(UimCustomChoiceController *) controller button] selectItemAtIndex:i];
  }
  [[(UimCustomChoiceController *) controller button] setEnabled:custom->is_active];
  [[(UimCustomChoiceController *) controller button] sizeToFit];
  [[(UimCustomChoiceController *) controller view] setNeedsDisplay:YES];
}

- (void)setAction
{
  [[(UimCustomChoiceController *) controller button] setTarget:self];
  [[(UimCustomChoiceController *) controller button] setAction:@selector(click:)];
}

- (void)setDefault
{
  free(custom->value->as_choice->symbol);
  free(custom->value->as_choice->label);
  free(custom->value->as_choice->desc);
  custom->value->as_choice->symbol =
    strdup(custom->default_value->as_choice->symbol);
  custom->value->as_choice->label =
    strdup(custom->default_value->as_choice->label);
  custom->value->as_choice->desc =
    strdup(custom->default_value->as_choice->desc);
  uim_custom_set(custom);
}

#pragma mark -

//
// Actions
//

- (IBAction)click:(id)sender
{
  int index = [[(UimCustomChoiceController *) controller button] indexOfSelectedItem];
  
  free(custom->value->as_choice->symbol);
  free(custom->value->as_choice->label);
  free(custom->value->as_choice->desc);
  custom->value->as_choice->symbol =
    strdup(custom->range->as_choice.valid_items[index]->symbol);
  custom->value->as_choice->label =
    strdup(custom->range->as_choice.valid_items[index]->label);
  custom->value->as_choice->desc =
    strdup(custom->range->as_choice.valid_items[index]->desc);
  uim_custom_set(custom);
  
  if ([self isValidDelegateForSelector:@selector(uimCustomModified:)])
    [[self delegate] performSelector:@selector(uimCustomModified:)
                          withObject:self];
}

@end
