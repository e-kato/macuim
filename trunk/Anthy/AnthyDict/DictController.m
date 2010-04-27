//
//  DictController.m
//  AnthyDict

/*
  Copyright (c) 2006-2010 Etsushi Kato

  All rights reserved.

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

#import "DictController.h"


@implementation DictController
- (id)init
{
	self = [super init];
	if (self) {
		didChange = NO;
		words = [[NSMutableArray alloc] init];
		anthydic = [[AnthyController alloc] init];
		[self readPersonalDict];
		[self setWindowFrameAutosaveName:@"AnthyDict"];
	}
	return self;
}

- (void)popupMenuClicked:(id)sender
{
	int row;
	NSString *newCode;

	row = [tableView selectedRow];
	newCode = [sender title];
	[[words objectAtIndex:row] takeValue:newCode forKey:@"cclass_code"];

	didChange = YES;

	[self updateUI];
}

- (void)setSubMenus:(int)type
{
	NSMenu *subMenu;
	NSMenuItem *newItem, *target;
	int i;

	subMenu = [[[NSMenu alloc] init] autorelease];
	for (i = 0; i < [Word ClassTypeCount:type]; i++) {
		newItem = [[NSMenuItem alloc]
			initWithTitle:[Word ClassCode:type:i]
			action:@selector(popupMenuClicked:)
			keyEquivalent:@""];
		[subMenu addItem:newItem];
		[newItem release];
	}

	switch (type) {
	case substantiveClassType:
		target = substantiveMenu;
		break;
	case verbClassType:
		target = verbMenu;
		break;
	case adjectiveClassType:
		target = adjectiveMenu;
		break;
	case adverbClassType:
		target = adverbMenu;
		break;
	case etcClassType:
		target = etcMenu;
		break;
	default:
		target = nil;
		break;
	}
	[target setSubmenu:subMenu];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
	[self setSubMenus:substantiveClassType];
	[self setSubMenus:verbClassType];
	[self setSubMenus:adjectiveClassType];
	[self setSubMenus:adverbClassType];
	[self setSubMenus:etcClassType];

	//NSTableColumn *column = [tableView tableColumnWithIdentifier:@"cclass_code"];
	//NSPopUpButtonCell *cell = [column dataCell];
	//[cell setUsesItemFromMenu:NO];
}

- (IBAction)deleteWord:(id)sender
{
	Word *currentWord;
	NSNumber *index;
	int choice;
	NSMutableArray *wordToRemove = [NSMutableArray array];
	
	NSEnumerator *e = [tableView selectedRowEnumerator];
	
	while (index = [e nextObject]) {
		currentWord = [words objectAtIndex:[index intValue]];
		[wordToRemove addObject:currentWord];
	}
	
	choice = NSRunAlertPanel(NSLocalizedString(@"Delete", nil),
		NSLocalizedString(@"SureDelete", nil),
		NSLocalizedString(@"Yes", nil),
		NSLocalizedString(@"No", nil),
		nil,
		[wordToRemove count]);
	
	if (choice == NSAlertDefaultReturn) {
		[words removeObjectsInArray:wordToRemove];
		
		didChange = YES;
		[self updateUI];
	}
}

- (IBAction)newWord:(id)sender
{
	[self createNewWord];
	[self updateUI];

	int col = [tableView columnWithIdentifier:@"phon"];
	// A new entry has been just created at the head of words.
	[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
		byExtendingSelection:NO];
	[tableView editColumn:col row:0 withEvent:nil select:YES];
}

- (IBAction)saveDict:(id)sender
{
	[self savePersonalDict];
	[self reloadPersonalDict];
	[self updateUI];
}

- (void)createNewWord
{
	Word *newWord = [[Word alloc] init];
	[words insertObject:newWord atIndex:0];
	[newWord release];
	didChange = YES;
}

- (void)readPersonalDict
{
	[anthydic dict_read:words];
}

- (void)savePersonalDict
{
	[anthydic dict_save:words];
	didChange = NO;
}

- (void)reloadPersonalDict
{
	[words removeAllObjects];
	[self readPersonalDict];
}

- (void)updateUI
{
	[tableView reloadData];
	[deleteButton setEnabled:([tableView selectedRow] != -1)];
	[saveButton setEnabled:(didChange == YES)];
	[[self window] setDocumentEdited:(didChange == YES)];
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [words count];
}

- (id)tableView:(NSTableView *)aTableView
	objectValueForTableColumn:(NSTableColumn *)aTableColumn
	row:(int)rowIndex
{
	NSString *identifier = [aTableColumn identifier];
	Word *word = [words objectAtIndex:rowIndex];

	if ([identifier isEqualToString:@"cclass_code"]) {
		unsigned int type;
		type = [Word TypeOfClass:[word valueForKey:identifier]];
		return [NSNumber numberWithInt:type];
	}
	return [word valueForKey:identifier];
}

- (void)tableView:(NSTableView *)aTableView
	setObjectValue:(id)anObject
	forTableColumn:(NSTableColumn *)aTableColumn
	row:(int)rowIndex
{
	NSString *identifier = [aTableColumn identifier];
	Word *word = [words objectAtIndex:rowIndex];
#if 0
	if ([identifier isEqualToString:@"cclass_code"])
		return;
#endif
	[word takeValue:anObject forKey:identifier];
}

- (void)tableViewSelectionDidChange:(NSNotification *)n
{
	if ([tableView selectedRow] != -1) {
		[deleteButton setEnabled:YES];
	} else {
		[deleteButton setEnabled:NO];
	}
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	didChange = YES;
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
	[self updateUI];
}

- (void)menuNeedsUpdate:(NSMenu *)menu
{
	int row, type;
	NSString *code;

	row = [tableView selectedRow];
	if (row == -1)
		return;

	code = [[words objectAtIndex:row] cclass_code];
	type = [Word TypeOfClass:code];

	if (type != -1) {
		NSMenuItem *item = [menu itemAtIndex:type];

		if ([item hasSubmenu]) {
			NSMenu *submenu = [item submenu];
			NSMenuItem *targetItem = [submenu itemAtIndex:
					[Word ClassIndexOfType:code:type]];
			[targetItem setState:NSOnState];
		}
	}
}

- (void)tableView:(NSTableView *)tableView 
	willDisplayCell:(id)cell 
	forTableColumn:(NSTableColumn *)tableColumn 
	row:(int)row 
{
	if ([cell isKindOfClass:[NSPopUpButtonCell class]])
		[[cell menu] setDelegate:self];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
	return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	return [self quitConfirm];
}

- (BOOL)windowShouldClose:(id)sender
{
	return [self quitConfirm];
}

- (BOOL)quitConfirm
{
	if (didChange == YES) {
		int choice;
		
		choice = NSRunAlertPanel(NSLocalizedString(@"Quit", nil),
			NSLocalizedString(@"SureSave", nil),
			NSLocalizedString(@"Save", nil),
			NSLocalizedString(@"DontSave", nil),
			NSLocalizedString(@"Cancel", nil));
	
		if (choice == NSAlertDefaultReturn) {
			[self savePersonalDict];
			return YES;
		} else if (choice == NSAlertAlternateReturn) {
			didChange = NO; // discard changes
			return YES;
		} else
			return NO;
	}
	return YES;
}

- (void)dealloc
{
	[words release];
	[anthydic release];
	[super dealloc];
}
@end
