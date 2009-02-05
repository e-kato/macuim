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

#import "Debug.h"
#import "UimCustom.h"
#import "UimCustomBooleanController.h"
#import "UimCustomIntegerController.h"
#import "UimCustomStringController.h"
#import "UimCustomPathnameController.h"
#import "UimCustomChoiceController.h"
#import "UimCustomOrderedListController.h"
#import "UimCustomKeyController.h"

#define LocalizedString(str) \
  ([[NSBundle bundleForClass:[self class]] localizedStringForKey:(str) value:nil table:nil])


static void UimUpdateCustom(void *ptr, const char *custom_sym);


@implementation UimCustomBase

- (void)dealloc
{
  [controller release];
}

- (UimCustomController *)controller
{
  return controller;
}

- (void)setController:(UimCustomController *)aController
{
  controller = aController;
}

@end


@implementation UimCustom

- (id)initWithCustom:(struct uim_custom *)aCustom
{
  [super init];

  custom = aCustom;
  
  [self setUimCallback];
  
  return self;
}

- (void)dealloc
{
  if (custom)
    uim_custom_free(custom);
  
  if (controller)
    [controller release];
  
  [super dealloc];
}

- (struct uim_custom *)custom
{
  return custom;
}

- (void)reloadCustom
{
  struct uim_custom *newCustom;
  
  newCustom = uim_custom_get(custom->symbol);
  uim_custom_free(custom);
  custom = newCustom;
}

- (void)displayCustom
{
}

- (void)setRange
{
}

- (void)setAction
{
}

- (void)setUimCallback
{
  uim_custom_cb_add(custom->symbol, self, UimUpdateCustom);
}

- (void)setDefault
{
}

- (id)delegate
{
  return delegate;
}

- (void)setDelegate:(id)obj
{
  NSParameterAssert([obj conformsToProtocol:@protocol(UimCustomModifiedProtocol)]);
  
  delegate = obj;
}

- (BOOL)isValidDelegateForSelector:(SEL)command
{
  return (([self delegate] != nil) &&
          [[self delegate] respondsToSelector:command]);
}

@end


@implementation UimCustomGroup

- (id)initWithCustomGroup:(struct uim_custom_group *)aCustomGroup
{
  [super init];
  
  custom_group = aCustomGroup;
  customs = [[NSMutableArray alloc] init];
  
  return self;
}

- (void)dealloc
{
  if (customs)
    [customs release];
  
  if (custom_group)
    uim_custom_group_free(custom_group);
}

- (struct uim_custom_group *)customGroup
{
  return custom_group;
}

- (NSArray *)customs
{
  return customs;
}

- (void)addCustom:(UimCustom *)custom
{
  [customs addObject:custom];
}

@end

#pragma mark -

//
// Uim callbacks
//

static void UimUpdateCustom(void *ptr, const char *custom_sym)
{
  UimCustom *self;
  NSAutoreleasePool *localPool;

  localPool = [[NSAutoreleasePool alloc] init];    
  
  self = (UimCustom *) ptr;
  [self reloadCustom];
  [self displayCustom];
  
  [localPool release];
}
