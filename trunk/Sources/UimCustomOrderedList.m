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
#import "UimCustomOrderedList.h"
#import "UimCustomOrderedListController.h"


@implementation UimCustomOrderedList

- (id)initWithCustom:(struct uim_custom *)aCustom
{
  if (!(self = [super initWithCustom:aCustom]))
    return nil;

  if (!(controller = [[UimCustomOrderedListController alloc] init])) {
    [self release];
    return nil;
  }
  [controller retain];
  
  choiceArray = [[NSMutableArray alloc] init];
  [self rebuildChoiceArray];
  
  availableArray = [[NSMutableArray alloc] init];
  [self rebuildAvailableArray];
  
  [[(UimCustomOrderedListController *) controller listTable] setDelegate:self];
  [[(UimCustomOrderedListController *) controller listTable] setDataSource:self];
  [[(UimCustomOrderedListController *) controller listTable] registerForDraggedTypes:[NSArray arrayWithObjects:@"row", nil]];
  
  [[(UimCustomOrderedListController *) controller availableTable] setDataSource:self];

  [self displayCustom];
  [self setAction];
  
  return self;
}

- (void)dealloc
{
  [choiceArray release];
  [availableArray release];
  
  [super dealloc];
}

- (void)reloadCustom
{
  [super reloadCustom];
  
  [self rebuildChoiceArray];
  [self rebuildAvailableArray];
}

- (void)displayCustom
{
  if (custom->value->as_olist) {
    NSMutableString *str = [[[NSMutableString alloc] init] autorelease];
    int i;
    for (i = 0; i < [choiceArray count]; i++) {
      if (i > 0)
        [str appendString:@", "];
      [str appendString:[NSString stringWithUTF8String:[[choiceArray objectAtIndex:i] choice]->label]];
    }
    [[(UimCustomOrderedListController *) controller field] setTitleWithMnemonic:str];
  }
  [[(UimCustomOrderedListController *) controller field] setEnabled:custom->is_active];
}

- (void)setAction
{
  [[(UimCustomOrderedListController *) controller button] setTarget:self];
  [[(UimCustomOrderedListController *) controller button] setAction:@selector(click:)];
  
  [[(UimCustomOrderedListController *) controller listUpButton] setTarget:self];
  [[(UimCustomOrderedListController *) controller listUpButton] setAction:@selector(upClick:)];
  
  [[(UimCustomOrderedListController *) controller listDownButton] setTarget:self];
  [[(UimCustomOrderedListController *) controller listDownButton] setAction:@selector(downClick:)];
  
  [[(UimCustomOrderedListController *) controller listAddButton] setTarget:self];
  [[(UimCustomOrderedListController *) controller listAddButton] setAction:@selector(addClick:)];
}

- (void)setDefault
{
  int i, num;
  struct uim_custom_choice **olist;
  
  for (num = 0; custom->default_value->as_olist[num]; num++);
  
  olist = custom->value->as_olist;
  custom->value->as_olist = malloc(sizeof(struct uim_custom_choice *) * (num + 1));
  
  for (i = 0; i < num; i++) {
    custom->value->as_olist[i] = malloc(sizeof(struct uim_custom_choice));
    custom->value->as_olist[i]->symbol =
      strdup(custom->default_value->as_olist[i]->symbol);
    custom->value->as_olist[i]->label =
      strdup(custom->default_value->as_olist[i]->label);
    custom->value->as_olist[i]->desc =
      strdup(custom->default_value->as_olist[i]->desc);
  }
  custom->value->as_olist[num] = nil;

  for (i = 0; olist[i]; i++) {
    free(olist[i]->symbol);
    free(olist[i]->label);
    free(olist[i]->desc);
    free(olist[i]);
  }
  free(olist);
    
  [self rebuildChoiceArray];
  [self rebuildAvailableArray];
  [self displayCustom];
  
  uim_custom_set(custom);
}

- (void)rebuildChoiceArray
{
  struct uim_custom_choice *item;
  int i;
   
  [choiceArray removeAllObjects];
  
  for (item = custom->value->as_olist[0], i = 0;
       item;
       item = custom->value->as_olist[++i]) {
    [choiceArray addObject:[[[UimChoice alloc] initWithChoice:item] autorelease]];
  }
}

- (void)rebuildAvailableArray
{
  struct uim_custom_choice *item;
  int i;
  
  [availableArray removeAllObjects];
  
  for (item = custom->range->as_olist.valid_items[0], i = 0;
       item;
       item = custom->range->as_olist.valid_items[++i]) {
    struct uim_custom_choice *item2;
    int j;
    BOOL enable = NO;
    
    for (item2 = custom->value->as_olist[0], j = 0;
         item2;
         item2 = custom->value->as_olist[++j]) {
      if (!strcmp(item->symbol, item2->symbol)) {
        enable = YES;
        break;
      }
    }
    [availableArray addObject:[[[UimChoice alloc] initWithChoice:item
                                                     withEnabled:enable] autorelease]];
  }
}

#pragma mark -

//
// Actions
//

// Edit button clicked
- (IBAction)click:(id)sender
{
  [[(UimCustomOrderedListController *) controller listTable] reloadData];
  [[NSApplication sharedApplication] beginSheet:[(UimCustomOrderedListController *) controller listPanel]
                                 modalForWindow:[[NSApplication sharedApplication] keyWindow]
                                  modalDelegate:self
                                 didEndSelector:@selector(listPanelDidEnd:returnCode:contextInfo:) 
                                    contextInfo:nil];
}

#pragma mark -

//
// List-dialog actions
//

- (void)listPanelDidEnd:(NSWindow*)sheet 
             returnCode:(int)returnCode 
            contextInfo:(void *)contextInfo
{
  if (returnCode) {
    int i;
    struct uim_custom_choice *item;
    struct uim_custom_choice **olist = custom->value->as_olist;
    
    custom->value->as_olist = malloc(sizeof(struct uim_custom_choice *) *
                                     ([choiceArray count] + 1));
    for (i = 0; i < [choiceArray count]; i++) {
      item = [[choiceArray objectAtIndex:i] choice];
      custom->value->as_olist[i] = malloc(sizeof(struct uim_custom_choice));
      custom->value->as_olist[i]->symbol = strdup(item->symbol);
      custom->value->as_olist[i]->label = strdup(item->label);
      custom->value->as_olist[i]->desc = strdup(item->desc);
    }
    custom->value->as_olist[i] = nil;
    
    for (item = olist[0], i = 0; item; item = olist[++i]) {
      free(item->symbol);
      free(item->label);
      free(item->desc);
      free(item);
    }
    free(olist);
    
    uim_custom_set(custom);
  
    if ([self isValidDelegateForSelector:@selector(uimCustomModified:)])
      [[self delegate] performSelector:@selector(uimCustomModified:)
                            withObject:self];
  }
  else {
    // discard changes
    [self reloadCustom];
  }
}

- (IBAction)upClick:(id)sender
{
  int row = [[(UimCustomOrderedListController *) controller listTable] selectedRow];
  
  if (row <= 0) {
    NSBeep();
    return;
  }
  
  [choiceArray exchangeObjectAtIndex:row
                   withObjectAtIndex:row - 1];
  [[(UimCustomOrderedListController *) controller listTable] reloadData];
  [[(UimCustomOrderedListController *) controller listTable] selectRowIndexes:[NSIndexSet indexSetWithIndex:row - 1]
                                                         byExtendingSelection:NO];
  [[(UimCustomOrderedListController *) controller listTable] scrollRowToVisible:row - 1];
}

- (IBAction)downClick:(id)sender
{
  int row = [[(UimCustomOrderedListController *) controller listTable] selectedRow];
  
  if (row >= [choiceArray count] - 1) {
    NSBeep();
    return;
  }
  
  [choiceArray exchangeObjectAtIndex:row
                   withObjectAtIndex:row + 1];
  [[(UimCustomOrderedListController *) controller listTable] reloadData];
  [[(UimCustomOrderedListController *) controller listTable] selectRowIndexes:[NSIndexSet indexSetWithIndex:row + 1]
                                                         byExtendingSelection:NO];
  [[(UimCustomOrderedListController *) controller listTable] scrollRowToVisible:row + 1];
}

- (IBAction)addClick:(id)sender
{
  [[(UimCustomOrderedListController *) controller availableTable] reloadData];
  [[NSApplication sharedApplication] beginSheet:[(UimCustomOrderedListController *) controller availablePanel]
                                 modalForWindow:[[NSApplication sharedApplication] keyWindow]
                                  modalDelegate:self
                                 didEndSelector:@selector(availablePanelDidEnd:returnCode:contextInfo:) 
                                    contextInfo:nil];
}

#pragma mark -

//
// Available-dialog actions
//

- (void)availablePanelDidEnd:(NSWindow*)sheet 
                  returnCode:(int)returnCode 
                 contextInfo:(void *)contextInfo
{
  if (returnCode) {
    int i;
    for (i = 0; i < [availableArray count]; i++) {
      UimChoice *choice = [availableArray objectAtIndex:i];
      int found = -1;
      int j;
      
      for (j = 0; j < [choiceArray count]; j++) {
        UimChoice *choice2 = [choiceArray objectAtIndex:j];
        if (!strcmp([choice choice]->symbol, [choice2 choice]->symbol)) {
          found = j;
          break;
        }
      }
      if (found < 0 && [choice enabled])
        [choiceArray addObject:choice];
      else if (found >= 0 && ![choice enabled])
        [choiceArray removeObjectAtIndex:found];

      [[(UimCustomOrderedListController *) controller listTable] reloadData];
    }
  }
  else {
    // discard changes
    [self rebuildAvailableArray];
  }
}

#pragma mark -

//
// Table data source
//

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  if (aTableView == [(UimCustomOrderedListController *) controller listTable])
    return [choiceArray count];
  else if (aTableView == [(UimCustomOrderedListController *) controller availableTable])
    return [availableArray count];
  
  return 0;
}

- (id)tableView:(NSTableView *)aTableView
 objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(NSInteger)rowIndex
{
  if ([[aTableColumn identifier] isEqualToString:@"list"])
    return [NSString stringWithUTF8String:[[choiceArray objectAtIndex:rowIndex] choice]->label];
  else if ([[aTableColumn identifier] isEqualToString:@"on"])
    return [NSNumber numberWithBool:[[availableArray objectAtIndex:rowIndex] enabled]];
  else if ([[aTableColumn identifier] isEqualToString:@"available"])
    return [NSString stringWithUTF8String:[[availableArray objectAtIndex:rowIndex] choice]->label];
  
  return nil;
}

- (void)tableView:(NSTableView *)tableView
   setObjectValue:(id)object 
   forTableColumn:(NSTableColumn *)tableColumn 
              row:(NSInteger)rowIndex;
{
  if ([[tableColumn identifier] isEqualToString:@"on"])
    [[availableArray objectAtIndex:rowIndex] setEnabled:[object intValue]];
}

- (BOOL)tableView:(NSTableView *)tableView
        writeRows:(NSArray *)rows
     toPasteboard:(NSPasteboard *)pboard
{
  if (tableView == [(UimCustomOrderedListController *) controller listTable]) {
    [pboard declareTypes:[NSArray arrayWithObjects:@"row", nil] owner:self];
    [pboard setPropertyList:rows forType:@"row"];
    return YES;
  }

  return NO;
}

- (NSDragOperation)tableView:(NSTableView *)tableView
                validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)operation
{
  NSPasteboard *pboard = [info draggingPasteboard];
  
  if (tableView == [(UimCustomOrderedListController *) controller listTable] &&
      operation == NSTableViewDropAbove &&
      [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"row", nil]]) {
    return NSDragOperationGeneric;
  }

  return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tableView
       acceptDrop:(id <NSDraggingInfo>)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)operation
{
  NSPasteboard *pboard = [info draggingPasteboard];
  
  if (tableView == [(UimCustomOrderedListController *) controller listTable] &&
      operation == NSTableViewDropAbove &&
      [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"row", nil]]) {
    NSNumber *number = [[pboard propertyListForType:@"row"] objectAtIndex:0];
    int oldRow = [number intValue];
    
    [choiceArray insertObject:[choiceArray objectAtIndex:oldRow] atIndex:row];

    if (oldRow < row)
      row--;
    else
      oldRow++;
   
    [choiceArray removeObjectAtIndex:oldRow];   
    
    [[(UimCustomOrderedListController *) controller listTable] reloadData];
    [[(UimCustomOrderedListController *) controller listTable] selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                                                           byExtendingSelection:NO];
    [[(UimCustomOrderedListController *) controller listTable] scrollRowToVisible:row];
   
    return YES;
  }
 
  return NO;
}

#pragma mark -

//
// List-table delegate method
//

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
  int row = [[(UimCustomOrderedListController *) controller listTable] selectedRow];
  
  if (row == 0)
    [[(UimCustomOrderedListController *) controller listUpButton] setEnabled:NO];
  else
    [[(UimCustomOrderedListController *) controller listUpButton] setEnabled:YES];
  
  if (row == [choiceArray count] - 1)
    [[(UimCustomOrderedListController *) controller listDownButton] setEnabled:NO];
  else
    [[(UimCustomOrderedListController *) controller listDownButton] setEnabled:YES];
}

@end


@implementation UimChoice

- (id)initWithChoice:(struct uim_custom_choice *)aChoice
{
  self = [super init];
  
  choice = aChoice;
  enabled = YES;
  
  return self;
}

- (id)initWithChoice:(struct uim_custom_choice *)aChoice
         withEnabled:(BOOL)enable
{
  self = [super init];
  
  choice = aChoice;
  enabled = enable;
  
  return self;
}

- (struct uim_custom_choice *)choice
{
  return choice;
}

- (void)setChoice:(struct uim_custom_choice *)aChoice
{
  choice = aChoice;
}

- (BOOL)enabled
{
  return enabled;
}

- (void)setEnabled:(BOOL)enable
{
  enabled = enable;
}

@end
