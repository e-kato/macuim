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
#import "UimCustom.h"
#import "UimCustomBooleanController.h"
#import "UimCustomIntegerController.h"
#import "UimCustomStringController.h"
#import "UimCustomPathnameController.h"
#import "UimCustomChoiceController.h"
#import "UimCustomOrderedListController.h"
#import "UimCustomKeyController.h"
#import "UimCustomBoolean.h"
#import "UimCustomInteger.h"
#import "UimCustomString.h"
#import "UimCustomPathname.h"
#import "UimCustomChoice.h"
#import "UimCustomOrderedList.h"
#import "UimCustomKey.h"
#import "UimPrefController.h"

#define LocalizedString(str) \
  ([[NSBundle bundleForClass:[self class]] localizedStringForKey:(str) value:nil table:nil])


static void UimUpdateCustom(void *ptr, const char *custom_sym);


@implementation UimCustomBase

- (void)dealloc
{
  [controller release];
  [super dealloc];
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
  loaded = NO;
  
  return self;
}

- (void)dealloc
{
  if (customs)
    [customs release];
  
  if (custom_group)
    uim_custom_group_free(custom_group);

  [super dealloc];
}

- (struct uim_custom_group *)customGroup
{
  return custom_group;
}

- (NSArray *)customs
{
  return customs;
}

- (void)loadCustoms
{
    char **customSyms, **customSym, **subGroupSyms, **subGroupSym;

    subGroupSyms = uim_custom_group_subgroups(custom_group->symbol);

    for (subGroupSym = subGroupSyms; *subGroupSym; subGroupSym++) {
	struct uim_custom_group *subgroup = uim_custom_group_get(*subGroupSym);
	char *subgroup_str;

	if (!subgroup)
	    continue;

	/* XXX quick hack to use AND expression of groups */
	asprintf(&subgroup_str, "%s '%s", custom_group->symbol, *subGroupSym);
        customSyms = uim_custom_collect_by_group(subgroup_str);
	free(subgroup_str);

	if (!customSyms)
	    continue;

	for (customSym = customSyms; *customSym; customSym++) {
	    UimCustom *custom = nil;
	    struct uim_custom *uc = uim_custom_get(*customSym);
#if DEBUG_CUSTOM
	    /*
	     * enum UCustomType {
	     *   UCustom_Bool,        // 0
	     *   UCustom_Int,         // 1
	     *   UCustom_Str,         // 2
	     *   UCustom_Pathname,    // 3
	     *   UCustom_Choice,      // 4
	     *   UCustom_OrderedList, // 5
	     *   UCustom_Key          // 6
	     * };
	     */       
	    NSLog(@"  custom symbol='%s' label='%s' type=%d is_active=%d",
		  uc->symbol, uc->label, uc->type, uc->is_active);
#endif
      
	    switch (uc->type) {
	    case UCustom_Bool:
	          custom = [[[UimCustomBoolean alloc] initWithCustom:uc] autorelease];
	          break;
	    case UCustom_Int:
	          custom = [[[UimCustomInteger alloc] initWithCustom:uc] autorelease];
	          break;
	    case UCustom_Str:
	          custom = [[[UimCustomString alloc] initWithCustom:uc] autorelease];
	          break;
	    case UCustom_Pathname:
	          custom = [[[UimCustomPathname alloc] initWithCustom:uc] autorelease];
	          break;
	    case UCustom_Choice:
	          custom = [[[UimCustomChoice alloc] initWithCustom:uc] autorelease];
	          break;
	    case UCustom_OrderedList:
	          custom = [[[UimCustomOrderedList alloc] initWithCustom:uc] autorelease];
	          break;
	    case UCustom_Key:
	          custom = [[[UimCustomKey alloc] initWithCustom:uc] autorelease];
	          break;
	    }
	      
	    if (custom) {
	        [custom setDelegate:[UimPrefController sharedController]];
	        [self addCustom:custom];
	    }

	}
	uim_custom_symbol_list_free(customSyms);
	uim_custom_group_free(subgroup);
    }
    uim_custom_symbol_list_free(subGroupSyms);

    loaded = YES;
}

- (BOOL)loaded
{
	return loaded;
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
