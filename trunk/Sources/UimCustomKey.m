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

#import <uim.h>

#import "Debug.h"
#import "KeycodeToUKey.h"
#import "UimCustomKey.h"
#import "UimCustomKeyController.h"

static NSArray *noShiftKeys = nil;

static NSArray *uimKeys = nil;

@implementation UimCustomKey

- (id)initWithCustom:(struct uim_custom *)aCustom
{
  if (!noShiftKeys) {
    noShiftKeys = [[NSArray arrayWithObjects:
      @"!", @"\"", @"#", @"$", @"%", @"&", @"'", @"(", @")", @"=", @"~", @"|",
      @"`", @"{", @"+", @"*", @"}", @"<", @">", @"?", @"_",
      @"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H", @"I", @"J", @"K", @"L",
      @"M", @"N", @"O", @"P", @"Q", @"R", @"S", @"T", @"U", @"V", @"W", @"X",
      @"Y", @"Z",
      nil] retain];
  }
  
  if (!uimKeys) {
    uimKeys = [[NSArray arrayWithObjects:
      @"insert", @"zenkaku-hankaku", @"Multi_key", @"Mode_switch",
      @"Henkan_Mode", @"Muhenkan",
      nil] retain];
  }
  
  if (!(self = [super initWithCustom:aCustom]))
    return nil;
  
  if (!(controller = [[UimCustomKeyController alloc] init])) {
    [self release];
    return nil;
  }
  [controller retain];
  
  lastEvent = nil;
  
  keyArray = [[NSMutableArray alloc] init];
  [self rebuildKeyArray];

  [[(UimCustomKeyController *) controller panel] setDelegate:self];
  
  [[(UimCustomKeyController *) controller table] setDelegate:self];
  [[(UimCustomKeyController *) controller table] setDataSource:self];
  [[(UimCustomKeyController *) controller table] registerForDraggedTypes:[NSArray arrayWithObjects:@"row", nil]];
    
  [self displayCustom];
  [self setRange];
  [self setAction];
  
  return self;
}

- (void)dealloc
{
  [keyArray release];
  
  if (lastEvent)
    [lastEvent release];
  
  [super dealloc];
}

- (void)reloadCustom
{
  [super reloadCustom];
  
  [self rebuildKeyArray];
}

- (void)displayCustom
{
  if (custom->value->as_key) {
    NSMutableString *str = [[[NSMutableString alloc] init] autorelease];
    int i;
    for (i = 0; i < [keyArray count]; i++) {
      if (i > 0)
        [str appendString:@", "];
      [str appendString:[self uimKeyToString:[[keyArray objectAtIndex:i] uimKey]->literal]];
    }
    [[(UimCustomKeyController *) controller field] setTitleWithMnemonic:str];
  }
  [[(UimCustomKeyController *) controller field] setEnabled:custom->is_active];
}

- (void)setAction
{
  [[(UimCustomKeyController *) controller button] setTarget:self];
  [[(UimCustomKeyController *) controller button] setAction:@selector(click:)];
  
  [[(UimCustomKeyController *) controller upButton] setTarget:self];
  [[(UimCustomKeyController *) controller upButton] setAction:@selector(upClick:)];
  
  [[(UimCustomKeyController *) controller downButton] setTarget:self];
  [[(UimCustomKeyController *) controller downButton] setAction:@selector(downClick:)];
  
  [[(UimCustomKeyController *) controller addButton] setTarget:self];
  [[(UimCustomKeyController *) controller addButton] setAction:@selector(addClick:)];

  [[(UimCustomKeyController *) controller deleteButton] setTarget:self];
  [[(UimCustomKeyController *) controller deleteButton] setAction:@selector(deleteClick:)];
}

- (void)setDefault
{
  int i, num;
  
  for (num = 0; custom->default_value->as_key[num]; num++);
  for (i = 0; custom->value->as_key[i]; i++) {
    free(custom->value->as_key[i]->literal);
    free(custom->value->as_key[i]->label);
    free(custom->value->as_key[i]->desc);
    free(custom->value->as_key[i]);
  }
  custom->value->as_key = realloc(custom->value->as_key,
                                  sizeof(struct uim_custom_key *) * (num + 1));
  for (i = 0; i < num; i++) {
    custom->value->as_key[i] = malloc(sizeof(struct uim_custom_key));
    *custom->value->as_key[i] = *custom->default_value->as_key[i];
    custom->value->as_key[i]->type =
      custom->default_value->as_key[i]->type;
    custom->value->as_key[i]->editor_type =
      custom->default_value->as_key[i]->editor_type;
    custom->value->as_key[i]->literal =
      strdup(custom->default_value->as_key[i]->literal);
    custom->value->as_key[i]->label =
      strdup(custom->default_value->as_key[i]->label);
    custom->value->as_key[i]->desc =
      strdup(custom->default_value->as_key[i]->desc);
  }
  custom->value->as_key[num] = nil;
  uim_custom_set(custom);
}

- (void)rebuildKeyArray
{
  struct uim_custom_key *item;
  int i;
  
  [keyArray removeAllObjects];
  
  for (item = custom->value->as_key[0], i = 0;
       item;
       item = custom->value->as_key[++i]) {
    [keyArray addObject:[[[UimKey alloc] initWithUimKey:item] autorelease]];
  }
}

- (NSString *)uimKeyToString:(const char *)key
{
  NSMutableString *str = [[[NSMutableString alloc] init] autorelease];
  
  while (YES) {
    if (!strncmp(key, "<Control>", 9)) {
      [str appendString:LocalizedString(@"<Control>")];
      key += 9;
    }
    else if (!strncmp(key, "<Shift>", 7)) {
      [str appendString:LocalizedString(@"<Shift>")];
      key += 7;
    }
    else if (!strncmp(key, "<Alt>", 5)) {
      [str appendString:LocalizedString(@"<Alt>")];
      key += 5;
    }
    else
      break;
  }
  
  // /System/Library/Frameworks/AppKit.framework/Versions/C/Headers/NSEvent.h
  
  if (!strcmp(key, "space"))
    [str appendString:LocalizedString(@"space")];
  else if (!strcmp(key, " "))
    [str appendString:LocalizedString(@"space")];
  else if (!strcmp(key, "backspace"))
    [str appendString:LocalizedString(@"backspace")];
  else if (!strcmp(key, "delete"))
    [str appendString:LocalizedString(@"delete")];
  else if (!strcmp(key, "escape"))
    [str appendString:LocalizedString(@"escape")];
  else if (!strcmp(key, "return"))
    [str appendString:LocalizedString(@"return")];
  else if (!strcmp(key, "tab"))
    [str appendString:LocalizedString(@"tab")];
  else if (!strcmp(key, "left"))
    [str appendString:LocalizedString(@"left")];
  else if (!strcmp(key, "up"))
    [str appendString:LocalizedString(@"up")];
  else if (!strcmp(key, "right"))
    [str appendString:LocalizedString(@"right")];
  else if (!strcmp(key, "down"))
    [str appendString:LocalizedString(@"down")];
  else if (!strcmp(key, "prior"))
    [str appendString:LocalizedString(@"prior")];
  else if (!strcmp(key, "next"))
    [str appendString:LocalizedString(@"next")];
  else if (!strcmp(key, "home"))
    [str appendString:LocalizedString(@"home")];
  else if (!strcmp(key, "end"))
    [str appendString:LocalizedString(@"end")];
  //else if (!strcmp(key, "insert"))
  //  [str appendString:LocalizedString(@"insert")];
  else if (!strcmp(key, "Private1"))
    [str appendString:LocalizedString(@"Private1")];
  else if (!strcmp(key, "Private2"))
    [str appendString:LocalizedString(@"Private2")];
  else
    [str appendString:[NSString stringWithUTF8String:key]];
  
  return str;
}

- (NSString *)keyEventToString:(NSEvent *)theEvent
{
  NSMutableString *str = [[[NSMutableString alloc] init] autorelease];
  int i;

  // /System/Library/Frameworks/AppKit.framework/Versions/C/Headers/NSEvent.h
  
  //if ([theEvent modifierFlags] & NSAlphaShiftKeyMask)
  //  [str appendString:@"<AlphaShift>"];
  if ([theEvent modifierFlags] & NSShiftKeyMask) {
    int i;
    BOOL found = NO;
    for (i = 0; i < [noShiftKeys count]; i++) {
      if ([[noShiftKeys objectAtIndex:i] isEqualToString:[theEvent characters]]) {
        found = YES;
        break;
      }
    }
    if (!found)
      [str appendString:LocalizedString(@"<Shift>")];
  }
  if ([theEvent modifierFlags] & NSControlKeyMask)
    [str appendString:LocalizedString(@"<Control>")];
  if ([theEvent modifierFlags] & NSAlternateKeyMask)
    [str appendString:LocalizedString(@"<Alt>")];
  //if ([theEvent modifierFlags] & NSCommandKeyMask)
  //  [str appendString:@"<Command>"];
  //if ([theEvent modifierFlags] & NSNumericPadKeyMask)
  //  [str appendString:@"<NumericPad>"];
  //if ([theEvent modifierFlags] & NSHelpKeyMask)
  //  [str appendString:@"<Help>"];
  //if ([theEvent modifierFlags] & NSFunctionKeyMask)
  //  [str appendString:@"<Function>"];
  
  for (i = 0; KeycodeToUKey[i].ukey; i++) {
    if (KeycodeToUKey[i].keycode == [theEvent keyCode]) {
      [str appendString:LocalizedString([NSString stringWithUTF8String:KeycodeToUKey[i].label])];
      return str;
    }
  }
  
  if ([[theEvent charactersIgnoringModifiers] isEqualToString:@" "])
    [str appendString:LocalizedString(@"space")];
  else
    [str appendString:[theEvent charactersIgnoringModifiers]];
  return str;
}

- (NSString *)keyEventToUimLiteral:(NSEvent *)theEvent
{
  NSMutableString *str = [[[NSMutableString alloc] init] autorelease];
  int i;

  if ([theEvent modifierFlags] & NSShiftKeyMask) {
    int i;
    BOOL found = NO;
    for (i = 0; i < [noShiftKeys count]; i++) {
      if ([[noShiftKeys objectAtIndex:i] isEqualToString:[theEvent characters]]) {
        found = YES;
        break;
      }
    }
    if (!found)
      [str appendString:@"<Shift>"];
  }
  if ([theEvent modifierFlags] & NSControlKeyMask)
    [str appendString:@"<Control>"];
  if ([theEvent modifierFlags] & NSAlternateKeyMask)
    [str appendString:@"<Alt>"];
  
  for (i = 0; KeycodeToUKey[i].ukey; i++) {
    if (KeycodeToUKey[i].keycode == [theEvent keyCode]) {
      [str appendString:[NSString stringWithUTF8String:KeycodeToUKey[i].label]];
      return str;
    }
  }
  
  [str appendString:[theEvent charactersIgnoringModifiers]];
  
  return str;
}

- (void)printKeyEvent:(NSEvent *)theEvent
{
  NSMutableString *str = [[[NSMutableString alloc] init] autorelease];
  
  if ([theEvent modifierFlags] & NSAlphaShiftKeyMask)
    [str appendString:@"<AlphaShift>"];
  if ([theEvent modifierFlags] & NSShiftKeyMask)
    [str appendString:@"<Shift>"];
  if ([theEvent modifierFlags] & NSControlKeyMask)
    [str appendString:@"<Control>"];
  if ([theEvent modifierFlags] & NSAlternateKeyMask)
    [str appendString:@"<Alt>"];
  if ([theEvent modifierFlags] & NSCommandKeyMask)
    [str appendString:@"<Command>"];
  if ([theEvent modifierFlags] & NSNumericPadKeyMask)
    [str appendString:@"<NumericPad>"];
  if ([theEvent modifierFlags] & NSHelpKeyMask)
    [str appendString:@"<Help>"];
  if ([theEvent modifierFlags] & NSFunctionKeyMask)
    [str appendString:@"<Function>"];

  NSLog(@"key=%02x mod=%@ char='%@' ign='%@'",
        [theEvent keyCode], str, [theEvent characters],
        [theEvent charactersIgnoringModifiers]);
}

#pragma mark -

//
// Actions
//

- (IBAction)click:(id)sender
{
  [[(UimCustomKeyController *) controller table] reloadData];
  if (lastFieldEditor)
    [lastFieldEditor setString:@" "];
  [[NSApplication sharedApplication] beginSheet:[(UimCustomKeyController *) controller panel]
                                 modalForWindow:[[NSApplication sharedApplication] keyWindow]
                                  modalDelegate:self
                                 didEndSelector:@selector(panelDidEnd:returnCode:contextInfo:) 
                                    contextInfo:nil];
}

#pragma mark -

//
// Dialog actions
//

- (void)panelDidEnd:(NSWindow*)sheet 
          returnCode:(int)returnCode 
         contextInfo:(void *)contextInfo
{
  if (returnCode) {
    int i;
    struct uim_custom_key *item;
    struct uim_custom_key **keyList = custom->value->as_key;
    
    custom->value->as_key = malloc(sizeof(struct uim_custom_key *) *
                                   ([keyArray count] + 1));
    for (i = 0; i < [keyArray count]; i++) {
      item = [[keyArray objectAtIndex:i] uimKey];
      custom->value->as_key[i] = malloc(sizeof(struct uim_custom_key));
      custom->value->as_key[i]->type = item->type;
      custom->value->as_key[i]->editor_type = item->editor_type;
      custom->value->as_key[i]->literal = strdup(item->literal);
      custom->value->as_key[i]->label = strdup(item->label);
      custom->value->as_key[i]->desc = strdup(item->desc);
    }
    custom->value->as_key[i] = nil;
    
    for (item = keyList[0], i = 0; item; item = keyList[++i]) {
      free(item->literal);
      free(item->label);
      free(item->desc);
      free(item);
    }
    free(keyList);
    
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
  int row = [[(UimCustomKeyController *) controller table] selectedRow];
  
  if (row <= 0) {
    NSBeep();
    return;
  }
  
  [keyArray exchangeObjectAtIndex:row
                withObjectAtIndex:row - 1];
  [[(UimCustomKeyController *) controller table] reloadData];
  [[(UimCustomKeyController *) controller table] selectRowIndexes:[NSIndexSet indexSetWithIndex:row - 1]
                                             byExtendingSelection:NO];
  [[(UimCustomKeyController *) controller table] scrollRowToVisible:row - 1];
}

- (IBAction)downClick:(id)sender
{
  int row = [[(UimCustomKeyController *) controller table] selectedRow];
  
  if (row >= [keyArray count] - 1) {
    NSBeep();
    return;
  }
  
  [keyArray exchangeObjectAtIndex:row
                withObjectAtIndex:row + 1];
  [[(UimCustomKeyController *) controller table] reloadData];
  [[(UimCustomKeyController *) controller table] selectRowIndexes:[NSIndexSet indexSetWithIndex:row + 1]
                                             byExtendingSelection:NO];
  [[(UimCustomKeyController *) controller table] scrollRowToVisible:row + 1];  
}

- (IBAction)addClick:(id)sender
{
  struct uim_custom_key *item;
  
  item = malloc(sizeof(struct uim_custom_key));
  item->type = UCustomKey_Regular;
  item->editor_type = UCustomKeyEditor_Basic;
  item->literal = strdup([[self keyEventToUimLiteral:lastEvent] UTF8String]);
  item->label = strdup("");
  item->desc = strdup("");
  [keyArray addObject:[[[UimKey alloc] initWithUimKey:item
                                                added:YES] autorelease]];
  
  [[(UimCustomKeyController *) controller addButton] setEnabled:NO];
  [lastFieldEditor setString:@" "];
  
  [[(UimCustomKeyController *) controller table] reloadData];
}

- (IBAction)deleteClick:(id)sender
{
  int row = [[(UimCustomKeyController *) controller table] selectedRow];
  
  if (row < 0) {
    NSBeep();
    return;
  }
  
  [keyArray removeObjectAtIndex:row];
  [[(UimCustomKeyController *) controller table] reloadData];
}
  
#pragma mark -

//
// NSWindow delegate method
//

- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject
{
  if (anObject == [(UimCustomKeyController *) controller combo]) {
    KeyFieldEditor *editor = [[[KeyFieldEditor alloc] init] autorelease];
    [editor setDelegate:anObject];
    [editor setInputDelegate:self];
    return editor;
  }
  
  return nil;
}

#pragma mark -

//
// Table data source
//

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [keyArray count];
}

- (id)tableView:(NSTableView *)aTableView
 objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(NSInteger)rowIndex
{
  return [self uimKeyToString:[[keyArray objectAtIndex:rowIndex] uimKey]->literal];
}

- (BOOL)tableView:(NSTableView *)tableView
        writeRows:(NSArray *)rows
     toPasteboard:(NSPasteboard *)pboard
{
  [pboard declareTypes:[NSArray arrayWithObjects:@"row", nil] owner:self];
  [pboard setPropertyList:rows forType:@"row"];
  return YES;
}

- (NSDragOperation)tableView:(NSTableView *)tableView
                validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)operation
{
  NSPasteboard *pboard = [info draggingPasteboard];
  
  if (operation == NSTableViewDropAbove &&
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
  
  if (operation == NSTableViewDropAbove &&
      [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"row", nil]]) {
    NSNumber *number = [[pboard propertyListForType:@"row"] objectAtIndex:0];
    int oldRow = [number intValue];
    
    [keyArray insertObject:[keyArray objectAtIndex:oldRow] atIndex:row];
    
    if (oldRow < row)
      row--;
    else
      oldRow++;
    
    [keyArray removeObjectAtIndex:oldRow];   
    
    [[(UimCustomKeyController *) controller table] reloadData];
    [[(UimCustomKeyController *) controller table] selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                                               byExtendingSelection:NO];
    [[(UimCustomKeyController *) controller table] scrollRowToVisible:row];
    
    return YES;
  }
  
  return NO;
}

#pragma mark -

//
// Table delegate method
//

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
  int row = [[(UimCustomKeyController *) controller table] selectedRow];

  if (row < 0) {
    [[(UimCustomKeyController *) controller upButton] setEnabled:NO];
    [[(UimCustomKeyController *) controller downButton] setEnabled:NO];
    [[(UimCustomKeyController *) controller deleteButton] setEnabled:NO];
    return;
  }

  [[(UimCustomKeyController *) controller deleteButton] setEnabled:YES];
  
  if (row == 0)
    [[(UimCustomKeyController *) controller upButton] setEnabled:NO];
  else
    [[(UimCustomKeyController *) controller upButton] setEnabled:YES];
  
  if (row == [keyArray count] - 1)
    [[(UimCustomKeyController *) controller downButton] setEnabled:NO];
  else
    [[(UimCustomKeyController *) controller downButton] setEnabled:YES];
}

#pragma mark -

//
// KeyFieldEditor delegate method
//

- (NSString *)keyFieldEditor:(KeyFieldEditor *)editor
                  inputEvent:(NSEvent *)theEvent
{
  NSString *str;
  
  //[self printKeyEvent:theEvent];
  
  if (lastFieldEditor)
    [lastFieldEditor release];
  lastFieldEditor = editor;
  [lastFieldEditor retain];
  
  if (lastEvent)
    [lastEvent release];
  lastEvent = theEvent;
  [lastEvent retain];
  
  str = [self keyEventToString:theEvent];
  
  if ([str length] > 0)
    [[(UimCustomKeyController *) controller addButton] setEnabled:YES];
  
  return str;
}

@end


@implementation UimKey

- (id)initWithUimKey:(struct uim_custom_key *)aUimKey
{
  self = [super init];
  
  uimKey = aUimKey;
  added = NO;
  
  return self;
}

- (id)initWithUimKey:(struct uim_custom_key *)aUimKey
               added:(BOOL)add;
{
  self = [super init];
  
  uimKey = aUimKey;
  added = add;
  
  return self;
}

- (void)dealloc
{
  if (added) {
    free(uimKey->literal);
    free(uimKey->label);
    free(uimKey->desc);
    free(uimKey);
  }
  
  [super dealloc];
}

- (struct uim_custom_key *)uimKey
{
  return uimKey;
}

- (void)setUimKey:(struct uim_custom_key *)aUimKey
{
  uimKey = aUimKey;
}

@end
