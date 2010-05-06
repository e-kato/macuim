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
#import "CustomViewController.h"
#import "CustomViewCell.h"
#import "UimCustom.h"


@implementation CustomViewController

- (id)initWithViewColumn:(NSTableColumn *)col
         withOutlineView:aOutlineView
{
  if (!(self = [super init]))
    return nil;
  
  valueColumn = col;
  outlineView = aOutlineView;

  [outlineView setDataSource:self];
  [outlineView setDelegate:self];
    
  [valueColumn setDataCell:[[[CustomViewCell alloc] init] autorelease]];
    
  [valueColumn setEditable:NO];
  
  return self;
}

- (void)dealloc
{
  outlineView = nil;
  valueColumn = nil;
  delegate = nil;
  
  [super dealloc];
}

+ (id)controllerWithViewColumn:(NSTableColumn *)col
               withOutlineView:aOutlineView
{
  return [[[self alloc] initWithViewColumn:col
                           withOutlineView:aOutlineView] autorelease];
}

- (id)delegate
{
  return delegate;
}

- (void)setDelegate:(id)obj
{
  NSParameterAssert([obj conformsToProtocol:@protocol(CustomViewControllerDataSourceProtocol)]);
  
  delegate = obj;
}

- (void)reloadOutlineView
{
  while ([[outlineView subviews] count] > 0)
    [[[outlineView subviews] lastObject] removeFromSuperviewWithoutNeedingDisplay];

  [outlineView reloadData];
}

- (BOOL)isValidDelegateForSelector:(SEL)command
{
  return (([self delegate] != nil) &&
          [[self delegate] respondsToSelector:command]);
}

#pragma mark -

//
// NSOutlineView delegate methods
//

- (void)outlineView:(NSOutlineView *)aOutlineView
didClickTableColumn:(NSTableColumn *)aTableColumn
{
  if ([self isValidDelegateForSelector:_cmd])
    [[self delegate] performSelector:_cmd withObject:aOutlineView
                          withObject:aTableColumn];
}

- (void)outlineView:(NSOutlineView *)aOutlineView
 didDragTableColumn:(NSTableColumn *)aTableColumn
{
  if ([self isValidDelegateForSelector:_cmd])
    [[self delegate] performSelector:_cmd
                          withObject:aOutlineView
                          withObject:aTableColumn];
}

- (void)outlineView:(NSOutlineView *)aOutlineView
 mouseDownInHeaderOfTableColumn:(NSTableColumn *)aTableColumn
{
  if ([self isValidDelegateForSelector:_cmd])
    [[self delegate] performSelector:_cmd
                          withObject:aOutlineView
                          withObject:aTableColumn];
}

- (BOOL)outlineView:(NSOutlineView *)aOutlineView
 shouldCollapseItem:(id)item
{
  if (![self isValidDelegateForSelector:_cmd])
    return YES;
  
  return [[self delegate] outlineView:aOutlineView
                   shouldCollapseItem:item];
}

- (BOOL)outlineView:(NSOutlineView *)aOutlineView
 shouldEditTableColumn:(NSTableColumn *)aTableColumn
               item:(id)item
{
  if ([self isValidDelegateForSelector:_cmd])
    return [[self delegate] outlineView:aOutlineView
                  shouldEditTableColumn:aTableColumn
                                   item:item];
  
  return YES;
}

- (BOOL)outlineView:(NSOutlineView *)aOutlineView
   shouldExpandItem:(id)item
{
  if (![self isValidDelegateForSelector:_cmd])
    return YES;
  
  return [[self delegate] outlineView:aOutlineView
                     shouldExpandItem:item];
}

- (BOOL)outlineView:(NSOutlineView *)aOutlineView
   shouldSelectItem:(id)item
{
  if ([self isValidDelegateForSelector:_cmd])
    return [[self delegate] outlineView:aOutlineView
                       shouldSelectItem:item];

  return YES;
}

- (BOOL)outlineView:(NSOutlineView *)aOutlineView
 shouldSelectTableColumn:(NSTableColumn *)aTableColumn
{
  if ([self isValidDelegateForSelector:_cmd])
    return [[self delegate] outlineView:aOutlineView
                shouldSelectTableColumn:aTableColumn];

  return YES;
}

- (void)outlineView:(NSOutlineView *)aOutlineView
    willDisplayCell:(id)cell
     forTableColumn:(NSTableColumn *)aTableColumn
               item:(id)item
{
  //NSLog(@"[CustomViewController outlineView:willDisplayCell:forTableColumn:item:]");
  
  if (aTableColumn == valueColumn) {
    if ([self isValidDelegateForSelector:@selector(outlineView:viewForItem:)])
      [(CustomViewCell *) cell addSubview:[[self delegate] outlineView:aOutlineView
                                                           viewForItem:item]];
  }
  else {
    if ([self isValidDelegateForSelector:_cmd])
      [[self delegate] outlineView:aOutlineView
                   willDisplayCell:cell
                    forTableColumn:aTableColumn
                              item:item];
  }
}

- (void)outlineView:(NSOutlineView *)aOutlineView
 willDisplayOutlineCell:(id)cell
     forTableColumn:(NSTableColumn *)aTableColumn
               item:(id)item
{
  if (![self isValidDelegateForSelector:_cmd])
    return;
  
  [[self delegate] outlineView:aOutlineView
        willDisplayOutlineCell:cell
                forTableColumn:aTableColumn
                          item:item];
}

- (void)outlineViewColumnDidMove:(NSNotification *)notification
{
  if ([self isValidDelegateForSelector:_cmd])
    [[self delegate] performSelector:_cmd
                          withObject:notification];
}

- (void)outlineViewColumnDidResize:(NSNotification *)notification
{
  if ([self isValidDelegateForSelector:_cmd])
    [[self delegate] performSelector:_cmd
                          withObject:notification];
}

- (void)outlineViewItemDidCollapse:(NSNotification *)notification
{
  if ([self isValidDelegateForSelector:_cmd])
    [[self delegate] performSelector:_cmd
                          withObject:notification];
}

- (void)outlineViewItemDidExpand:(NSNotification *)notification
{
  if ([self isValidDelegateForSelector:_cmd])
    [[self delegate] performSelector:_cmd
                          withObject:notification];
}

- (void)outlineViewItemWillCollapse:(NSNotification *)notification
{
  if ([self isValidDelegateForSelector:_cmd])
    [[self delegate] performSelector:_cmd
                          withObject:notification];
}

- (void)outlineViewItemWillExpand:(NSNotification *)notification
{
  UimCustomGroup *customGroup = [[notification userInfo] objectForKey:@"NSObject"];
  if (![customGroup loaded]) {
    [customGroup loadCustoms];
    //[outlineView reloadData];
  }

  if ([self isValidDelegateForSelector:_cmd])
    [[self delegate] performSelector:_cmd
                          withObject:notification];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
  if ([self isValidDelegateForSelector:_cmd])
    [[self delegate] performSelector:_cmd
                          withObject:notification];
}

- (void)outlineViewSelectionIsChanging:(NSNotification *)notification
{
  if ([self isValidDelegateForSelector:_cmd])
    [[self delegate] performSelector:_cmd
                          withObject:notification];
}

- (BOOL)selectionShouldChangeInOutlineView:(NSOutlineView *)aOutlineView
{
  if ([self isValidDelegateForSelector:_cmd])
    return [[self delegate] selectionShouldChangeInOutlineView:aOutlineView];
  
  return YES;
}

#pragma mark -

//
// NSOutlineViewDataSource protocol
//

- (BOOL)outlineView:(NSOutlineView *)aOutlineView
         acceptDrop:(id <NSDraggingInfo>)info
               item:(id)item
         childIndex:(NSInteger)index
{
  if ([self isValidDelegateForSelector:_cmd])
    return [[self delegate] outlineView:aOutlineView
                             acceptDrop:info
                                   item:item
                             childIndex:index];

  return NO;
}

- (id)outlineView:(NSOutlineView *)aOutlineView
            child:(NSInteger)index
           ofItem:(id)item
{
  if (![self isValidDelegateForSelector:_cmd])
    return nil;
  
  return [[self delegate] outlineView:aOutlineView
                                child:index
                               ofItem:item];
}

- (BOOL)outlineView:(NSOutlineView *)aOutlineView
   isItemExpandable:(id)item
{
  if (![self isValidDelegateForSelector:_cmd])
    return NO;
  
  return [[self delegate] outlineView:aOutlineView
                     isItemExpandable:item];
}

- (id)outlineView:(NSOutlineView *)aOutlineView
 itemForPersistentObject:(id)object
{
  if (![self isValidDelegateForSelector:_cmd])
    return nil;
  
  return [[self delegate] outlineView:aOutlineView
              itemForPersistentObject:object];
}

- (NSInteger)outlineView:(NSOutlineView *)aOutlineView
 numberOfChildrenOfItem:(id)item
{
  if ([self isValidDelegateForSelector:_cmd])
    return [[self delegate] outlineView:aOutlineView
                 numberOfChildrenOfItem:item];
  
  return 0;
}

- (id)outlineView:(NSOutlineView *)aOutlineView
 objectValueForTableColumn:(NSTableColumn *)aTableColumn
           byItem:(id)item
{
  if ((aTableColumn != valueColumn) &&
      [self isValidDelegateForSelector:_cmd])
    return [[self delegate] outlineView:aOutlineView
              objectValueForTableColumn:aTableColumn
                                 byItem:item];
  
  return nil;
}

- (id)outlineView:(NSOutlineView *)aOutlineView
 persistentObjectForItem:(id)item
{
  if (![self isValidDelegateForSelector:_cmd])
    return nil;
  
  return [[self delegate] outlineView:aOutlineView
              persistentObjectForItem:item];
}

- (void)outlineView:(NSOutlineView *)aOutlineView
     setObjectValue:(id)object
     forTableColumn:(NSTableColumn *)aTableColumn
             byItem:(id)item
{
  if ((aTableColumn != valueColumn) &&
      [self isValidDelegateForSelector:_cmd])
    [[self delegate] outlineView:aOutlineView
                  setObjectValue:object
                  forTableColumn:aTableColumn
                          byItem:item];
}

- (void)outlineView:(NSOutlineView *)aOutlineView
 sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
  if (![self isValidDelegateForSelector:_cmd])
    return;
  
  [[self delegate] outlineView:aOutlineView
      sortDescriptorsDidChange:oldDescriptors];
}

- (NSDragOperation)outlineView:(NSOutlineView *)aOutlineView
                  validateDrop:(id <NSDraggingInfo>)info
                  proposedItem:(id)item
            proposedChildIndex:(NSInteger)index
{
  if ([self isValidDelegateForSelector:_cmd])
    return [[self delegate] outlineView:aOutlineView
                           validateDrop:info
                           proposedItem:item
                     proposedChildIndex:index];
  
  return NO;
}

- (BOOL)outlineView:(NSOutlineView *)aOutlineView
         writeItems:(NSArray *)items
       toPasteboard:(NSPasteboard *)pboard
{
  if ([self isValidDelegateForSelector:_cmd])
    return [[self delegate] outlineView:aOutlineView
                             writeItems:items
                           toPasteboard:pboard];

  return NO;
}

@end
