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
#import "UimPrefController.h"
#import "UimCustomBoolean.h"
#import "UimCustomInteger.h"
#import "UimCustomString.h"
#import "UimCustomPathname.h"
#import "UimCustomChoice.h"
#import "UimCustomOrderedList.h"
#import "UimCustomKey.h"
#import "UimCustomStringController.h"

static UimPrefController *sharedController;

@implementation UimPrefController

+ (UimPrefController *)sharedController
{
  return sharedController;
}

/*
 * Initialize the mode-tips contoller
 */
- (void)awakeFromNib
{
  char **groups, **grp;
  
  sharedController = self;

  if (uim_init() < 0) {
    NSLog(@"uim_init() failed\n");
    return;
  }
 
  if (!uim_custom_enable()) {
    NSLog(@"uim_custom_enable() failed\n");
    return;
  }

  customViewController =
    [[CustomViewController controllerWithViewColumn:valueColumn
                                    withOutlineView:outlineView] retain];
  [customViewController setDelegate:self];
  
  customGroups = [[NSMutableArray alloc] init];
  
  // load Uim custom groups
  groups = uim_custom_primary_groups();
  for (grp = groups; *grp; grp++) {
    UimCustomGroup *customGroup;
    char **customSyms, **customSym;
    
    customGroup =
      [[UimCustomGroup alloc] initWithCustomGroup:uim_custom_group_get(*grp)];
    [customGroups addObject:customGroup];

#if DEBUG_CUSTOM
    NSLog(@"group %s symbol='%s' label='%s' desc='%s'", *grp,
          [customGroup customGroup]->symbol,
          [customGroup customGroup]->label,
          [customGroup customGroup]->desc);
#endif
    
    customSyms = uim_custom_collect_by_group([customGroup customGroup]->symbol);
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
          custom = [[UimCustomBoolean alloc] initWithCustom:uc];
          break;
        case UCustom_Int:
          custom = [[UimCustomInteger alloc] initWithCustom:uc];
          break;
        case UCustom_Str:
          custom = [[UimCustomString alloc] initWithCustom:uc];
          break;
        case UCustom_Pathname:
          custom = [[UimCustomPathname alloc] initWithCustom:uc];
          break;
        case UCustom_Choice:
          custom = [[UimCustomChoice alloc] initWithCustom:uc];
          break;
        case UCustom_OrderedList:
          custom = [[UimCustomOrderedList alloc] initWithCustom:uc];
          break;
        case UCustom_Key:
          custom = [[UimCustomKey alloc] initWithCustom:uc];
          break;
      }
      
      if (custom) {
        [custom setDelegate:self];
        [customGroup addCustom:custom];
      }
    } // item loop
    
    uim_custom_symbol_list_free(customSyms);
    
  } // group loop
  
  //[outlineView setIntercellSpacing:NSMakeSize(0, 0)];
  
  //[outlineView reloadData];
  [customViewController reloadOutlineView];
}

- (void)dealloc
{
  if (customViewController)
    [customViewController release];
  
  if (customGroups)
    [customGroups release];
  
  [super dealloc];
}

- (CustomViewController *)customViewController
{
  return customViewController;
}

#pragma mark -

//
// Actions
//

- (IBAction)applyAction:(id)sender
{
  int i;
  
  // Save current editing text (Bad implementation...)
  for (i = 0; i < [customGroups count]; i++) {
    int j;
    UimCustomGroup *group = [customGroups objectAtIndex:i];
    for (j = 0; j < [[group customs] count]; j++) {
      UimCustom *custom = [[group customs] objectAtIndex:j];
      if ([custom custom]->type == UCustom_Str) {
        [[[(UimCustomStringController *) [custom controller] field] cell] endEditing:[[(UimCustomStringController *) [custom controller] field] currentEditor]];
      }
    }
  }
  
  uim_custom_save();
  uim_custom_broadcast();

  [applyButton setEnabled:NO];
}

- (IBAction)defaultAction:(id)sender
{
  NSBeginAlertSheet(LocalizedString(@"All parameters will be set to the default value. OK?"),
                    LocalizedString(@"OK"),
                    LocalizedString(@"Cancel"),
                    @"",
                    [[NSApplication sharedApplication] keyWindow],
                    self,
                    @selector(dialogDidEnd:returnCode:contextInfo:),
                    nil, nil, @"");
}

- (void)dialogDidEnd:(NSOpenPanel *)sheet
         returnCode:(int)returnCode
        contextInfo:(void *)contextInfo
{
  int i;
  
  if (!returnCode) return;

  for (i = 0; i < [customGroups count]; i++) {
    UimCustomGroup *group = [customGroups objectAtIndex:i];
    int j;
    for (j = 0; j < [[group customs] count]; j++)
      [[[group customs] objectAtIndex:j] setDefault];
  }
  
  [applyButton setEnabled:YES];
}

#pragma mark -

//
// UimCustom delegate method
//

- (void)uimCustomModified:(UimCustom *)custom
{
  [applyButton setEnabled:YES];
}

#pragma mark -

//
// NSOutlineView delegate methods
//

- (BOOL)outlineView:(NSOutlineView *)outlineView
   isItemExpandable:(id)item
{
  if (!item)
    return YES;
  
  return [[item className] isEqualToString:@"UimCustomGroup"];
}

- (int)outlineView:(NSOutlineView *)outlineView
 numberOfChildrenOfItem:(id)item
{
  if (!item)
    return [customGroups count];
  
  return [[item customs] count];
}

- (id)outlineView:(NSOutlineView *)outlineView
            child:(int)index
           ofItem:(id)item
{
  if (!item)
    return [customGroups objectAtIndex:index];
  
  return [[item customs] objectAtIndex:index];
}

#if 0
- (id)outlineView:(NSOutlineView *)outlineView
 objectValueForTableColumn:(NSTableColumn *)tableColumn
           byItem:(id)item
{
  id colID = [tableColumn identifier];
  
  if ([[item className] isEqualToString:@"UimCustomGroup"])  {
    if ([colID isEqualToString:@"name"])
        return [NSString stringWithUTF8String:[item customGroup]->label];
  }
  else {
    if ([colID isEqualToString:@"name"]) {
      char *p;
      if ((p = strstr([item custom]->label, "] ")))
        return [NSString stringWithUTF8String:p + 2];
      else
        return [NSString stringWithUTF8String:[item custom]->label];
    }
    else if ([colID isEqualToString:@"value"])
      return @"value";
  }
  
  return nil;
}
#endif

- (void)outlineView:(NSOutlineView *)aOutlineView
    willDisplayCell:(id)cell
     forTableColumn:(NSTableColumn *)aTableColumn
               item:(id)item
{
  if ([[item className] isEqualToString:@"UimCustomGroup"]) {
    if (aTableColumn == labelColumn) {
      [cell setStringValue:[NSString stringWithUTF8String:[item customGroup]->label]];
      [cell setFont:[NSFont fontWithName:[[cell font] fontName]
                                    size:13]];
    }
  }
  else {
    if (aTableColumn == labelColumn) {
      char *p;
      if ((p = strstr([item custom]->label, "] ")))
        [cell setStringValue:[NSString stringWithUTF8String:p + 2]];
      else
        [cell setStringValue:[NSString stringWithUTF8String:[item custom]->label]];
      [cell setFont:[NSFont fontWithName:[[cell font] fontName]
                                    size:11]];
    }
  }
}

- (void)outlineViewItemDidCollapse:(NSNotification *)notification
{
  while ([[outlineView subviews] count] > 0)
    [[[outlineView subviews] lastObject] removeFromSuperviewWithoutNeedingDisplay];
}

- (void)outlineViewItemDidExpand:(NSNotification *)notification
{
  while ([[outlineView subviews] count] > 0)
    [[[outlineView subviews] lastObject] removeFromSuperviewWithoutNeedingDisplay];
}

#pragma mark -

//
// CustomViewController delegate method
//

- (NSView *)outlineView:(NSOutlineView *)outlineView
            viewForItem:(id)item;
{
  NSView *view = nil;

  if ([item controller])
    view = [[item controller] view];
  
  return view;
}

@end
