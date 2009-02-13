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
#import "UimCustomKeyController.h"


@implementation UimCustomKeyController

- (id)init
{
  if (!(self = [super init]))
    return nil;
  
  if (![NSBundle loadNibNamed:@"KeyView" owner:self]) {
    NSLog(@"cannot load nib 'KeyView'");
    [self release];
    return nil;
  }
  
  return self;
}

- (NSTextField *)field
{
  return field;
}

- (NSButton *)button
{
  return button;
}

- (NSPanel *)panel
{
  return panel;
}

- (NSTableView *)table
{
  return table;
}

- (NSButton *)upButton
{
  return upButton;
}

- (NSButton *)downButton
{
  return downButton;
}

- (NSComboBox *)combo
{
  return combo;
}

- (NSButton *)addButton
{
  return addButton;
}

- (NSButton *)deleteButton
{
  return deleteButton;
}

#pragma mark -

//
// Actions
//

- (IBAction)ok:(id)sender
{
  [[NSApplication sharedApplication] endSheet:panel
                                   returnCode:1];
  [panel orderOut:self];
  
}

- (IBAction)cancel:(id)sender
{
  [[NSApplication sharedApplication] endSheet:panel
                                   returnCode:0];
  [panel orderOut:self];
}

- (IBAction)input:(id)sender
{
  NSLog(@"input:");
}

@end


@implementation KeyFieldEditor
{
}

- (id)inputDelegate
{
  return inputDelegate;
}

- (void)setInputDelegate:(id)obj
{
  NSParameterAssert([obj conformsToProtocol:@protocol(KeyFieldEditorInputProtocol)]);
  
  inputDelegate = obj;
}

- (BOOL)isValidDelegateForSelector:(SEL)command
{
  return (([self inputDelegate] != nil) &&
          [[self inputDelegate] respondsToSelector:command]);
}

// handle normal keys
- (void)keyDown:(NSEvent *)theEvent
{
  if ([self isValidDelegateForSelector:@selector(keyFieldEditor:inputEvent:)]) {
    [self setString:[[self inputDelegate] performSelector:@selector(keyFieldEditor:inputEvent:)
                                               withObject:self
                                               withObject:theEvent]];
  }
}

// handle Eisu and Kana
- (void)keyUp:(NSEvent *)theEvent
{
  if (([theEvent keyCode] == 0x66 ||
       [theEvent keyCode] == 0x68) &&
      [self isValidDelegateForSelector:@selector(keyFieldEditor:inputEvent:)])
    [self setString:[[self inputDelegate] performSelector:@selector(keyFieldEditor:inputEvent:)
                                               withObject:self
                                               withObject:theEvent]];
}

// handle command-key
- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
  if (//[theEvent modifierFlags] & NSCommandKeyMask &&
      [self isValidDelegateForSelector:@selector(keyFieldEditor:inputEvent:)])
    [self setString:[[self inputDelegate] performSelector:@selector(keyFieldEditor:inputEvent:)
                                               withObject:self
                                               withObject:theEvent]];
  
  return YES;
}

@end
