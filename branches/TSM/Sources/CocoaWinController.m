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

#import "CocoaWinController.h"

static CocoaWinController *sharedController;

@implementation CocoaWinController
 
+ (id)sharedController
{
  return sharedController;
}

/**
 * Initialize Cocoa
 */
- (id)init
{
  self = [super init];
  NSApplicationLoad();
  if (![NSBundle loadNibNamed:@"CocoaWindow" owner:self]) {
    NSLog(@"failed to load CocoaWindow nib");
    [self release];
    return nil;
  }
  sharedController = self;

  origSize = [panel frame].size;
  candIndex = -1;

  [panel setFrame:NSMakeRect([panel frame].origin.x,
                              [panel frame].origin.y,
                              origSize.width, 37)
          display:NO];

  return self;
}

/**
 * Set a callback for a CocoaWinController
 */
- (void)setCallBack:(CallBackType)callBack
{
  _callBack = callBack;
}

/**
 * Show a CocoaWinController and make it activate
 */
- (void)showWindow:(int)qdX:(int)qdY:(int)height
             alpha:(int)alpha
{
  lineHeight = height;
  float falpha = ((float) (100 - alpha)) / 100.0;

  [panel setAutodisplay:NO];
  [self replaceWindow:qdX:qdY];

  if (candIndex >= 0) {
    NSIndexSet *indexSet =
      [[NSIndexSet alloc] initWithIndex:candIndex];
    [table selectRowIndexes:indexSet byExtendingSelection:nil];
    [indexSet release];
  }

  if ([panel isVisible] == NO) {
    [panel makeFirstResponder:table];
    [panel orderFront:nil];
    [panel setLevel:NSFloatingWindowLevel];
    [panel setAlphaValue:falpha];
  }

  [panel setAutodisplay:YES];
}

/**
 * Hide a candidates-window
 */
- (void)hideWindow
{
  NSPoint origin = [panel frame].origin;

  if ([panel isVisible] == NO)
    return;

#if DEBUG_CANDIDATE_WINDOW
  NSLog(@"CocoaWinController::hideWindow");
#endif

  [panel orderOut:nil];

  [[table tableColumnWithIdentifier:@"candidate"] setWidth:36];
  [panel setFrame:NSMakeRect(origin.x, origin.y,
                              origSize.width, 37)
          display:NO];
}

/**
 * Returns YES if the candidate window is visible
 */
- (BOOL)isVisible
{
  return [panel isVisible];
}

/**
 * Request the NSTableView to reload candidates
 */
- (void)reloadData
{
  [table reloadData];
}

/**
 * Initialize
 */
- (void)awakeFromNib
{
  headArray = [[NSMutableArray alloc] init];
  candArray = [[NSMutableArray alloc] init];
}

/**
 * Get a number of rows in the TableView
 */
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [candArray count];
}

/**
 * Get data
 */
- (id)tableView:(NSTableView *)tableView
  objectValueForTableColumn:(NSTableColumn *)tableColumn
            row:(int)rowIndex
{
  id colID = [tableColumn identifier];

  if ([colID isEqual:@"head"])
    return [headArray objectAtIndex:rowIndex];
  else if ([colID isEqual:@"candidate"])
    return [candArray objectAtIndex:rowIndex];

  return nil;
}

- (void)tableView:(NSTableView *)tableView
  willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)tableColumn
              row:(int)row
{
  /*
  [cell setDrawsBackground:YES];
  
  if (row % 2)
    [cell setBackgroundColor:[NSColor colorWithCalibratedWhite:0.95
                                                         alpha:1.0]];
  else
    [cell setBackgroundColor:[NSColor whiteColor]];
  */
  
  [cell setFont:font];
}

- (UniCharPtr)getCandidate:(int)index
{
  return nil;
}

- (void)addCandidate:(UniCharPtr)head:(int)headLen
                    :(UniCharPtr)cand:(int)candLen
{
  NSString *headStr;
  NSString *candStr;

  if (head && headLen > 0)
    headStr = [[[NSString alloc] initWithCharacters:head + headLen - 1
                                length:1] autorelease];
  else
    headStr = [[[NSString alloc] initWithString:@""] autorelease];

  if (cand && candLen > 0)
    candStr = [[[NSString alloc] initWithCharacters:cand
                                length:candLen] autorelease];
  else
    candStr = [[[NSString alloc] initWithString:@""] autorelease];

  [headArray addObject:headStr];
  [candArray addObject:candStr];
}

/**
 * Clear candidates
 */
- (void)clearCandidate
{
#if DEBUG_CANDIDATE_WINDOW
  NSLog(@"CocoaWinController::clearCandidate");
#endif

  [headArray removeAllObjects];
  [candArray removeAllObjects];
}

/**
 * Select a candidate
 */
- (void)selectCandidate:(int)index
{
  NSIndexSet *indexSet;

  indexSet = [[NSIndexSet alloc] initWithIndex:index];

  candIndex = index;
  
  [table selectRowIndexes:indexSet byExtendingSelection:nil];
  [table scrollRowToVisible:index];

  [indexSet release];
}

/**
 * deselect a candidate
 */
- (void)deselectCandidate
{
  [table deselectAll:nil];

  candIndex = -1;
}

/**
 * Set a page label
 */
- (void)setPage:(int)index:(int)max
{
  NSString *str;

  if (index > 0)
    str = [NSString stringWithFormat:@"%d / %d", index, max];
  else
    str = [NSString stringWithFormat:@"- / %d", max];

  [label setStringValue:str];
}

/**
 * Button press action
 */
- (IBAction)candClicked:(id)sender
{
#if DEBUG_CANDIDATE_WINDOW
  NSLog(@"CocoaWinController::candClicked()");
#endif

  [panel orderOut:nil];

  (*_callBack)([sender clickedRow]);
}

- (void)replaceWindow:(int)replyX:(int)replyY
{
  NSTableColumn *col;
  NSRect rect;
  float candWidth = 0.0;
  float headWidth = 0.0;
  int i;
  NSMutableAttributedString *text;  

  for (i = 0; i < [candArray count]; i++) {
    text = [[NSAttributedString alloc]
            initWithString:[candArray objectAtIndex:i]
                attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                         font, NSFontAttributeName, nil]];
    if (candWidth < [text size].width)
      candWidth = [text size].width;
    [text release];
    
    text = [[NSAttributedString alloc]
            initWithString:[headArray objectAtIndex:i]
                attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                  font, NSFontAttributeName, nil]];
    if (headWidth < [text size].width)
      headWidth = [text size].width;
    [text release];
  }
  
  if (candWidth > kMaxWidth)
    candWidth = kMaxWidth;
  
  col = [table tableColumnWithIdentifier:@"head"];
  [col setWidth:headWidth + 7.0];
  
  i = 0;
  while (1) {
    NSString *str;
    if (i == [candArray count])
      break;
    str = [candArray objectAtIndex:i];
    if (!str || [str length] == 0)
      break;
    i++;
  }

  rect = [panel frame];
  rect.size.width = candWidth + headWidth + 20;
  rect.size.height = ([table rowHeight] + 2) * i + 20;
  rect = [panel frameRectForContentRect:rect];
  
  if ([panel frame].size.height > rect.size.height)
    rect.size.height = [panel frame].size.height;
  if ([panel frame].size.width > rect.size.width)
    rect.size.width = [panel frame].size.width;

  [panel setFrame:rect display:NO];

  // Get the height of screen with menubar
  NSArray *screenArray = [NSScreen screens];
  int nScreen = [screenArray count];
  NSPoint point = NSMakePoint((float)replyX, (float)replyY);
  if (nScreen > 0)
    point.y = [[screenArray objectAtIndex:0] frame].size.height - point.y;


  // Search a screen of the candidate window
  NSRect f = [[NSScreen mainScreen] frame];
  BOOL found = NO;
  for (i = 0; i < nScreen; i++) {
    NSRect sf = [[screenArray objectAtIndex:i] frame];
    if (NSPointInRect(point, sf)) {
      f = sf;
      found = YES;
      break;
    }
  }

  if (found) {
    point.y -= rect.size.height;
    if (point.y > f.origin.y + f.size.height - rect.size.height)
      point.y = f.origin.y + f.size.height - rect.size.height;
    if (point.x > f.origin.x + f.size.width - rect.size.width)
      point.x = f.origin.x + f.size.width - rect.size.width;
    if (point.y < f.origin.y)
      point.y =  [[screenArray objectAtIndex:0] frame].size.height - replyY + lineHeight + 3;
    if (point.x < f.origin.x)
      point.x = f.origin.x;
  } else {
    // Set candidate window position at the center of the screen
    point.x = f.origin.x + (f.size.width - rect.size.width) / 2;
    point.y = f.origin.y + (f.size.height - rect.size.height) / 2;
  }

#if DEBUG_CANDIDATE_WINDOW
  NSLog(@"CocoaWinController replaceWindow: x=%d y=%d origin.x=%d origin.y=%d\n",
        point.x, point.y, (int) rect.size.width, (int) rect.size.height);
#endif

  if (point.x != (int) rect.origin.x || point.y != (int) rect.origin.y)
    [panel setFrameOrigin:point];
}

- (void)setFont:(NSString *)name size:(float)size
{
  NSFont *tmpFont;
  NSAttributedString *text;
  float rowHeight;
  NSRect rect;
  
  if ((tmpFont = [NSFont fontWithName:name size:size])) {
    if (font)
      [font release];
    font = tmpFont;
    [font retain];
  }

#if DEBUG_CANDIDATE_WINDOW
  NSLog(@"CocoaWinController setFont: name=%@ size=%f font=%@",
        name, size, font);
#endif
  
  text = [[[NSAttributedString alloc]
            initWithString:[font description]
                attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                            font, NSFontAttributeName, nil]] autorelease];

  rowHeight = [text size].height;
  
  if (rowHeight > kMaxHeight)
    rowHeight = kMaxHeight;
  [table setRowHeight:rowHeight];
  
  //origSize.height = (rowHeight + 2) * 10 + 20;
  
  rect = [panel frame];
  rect.size.height = ([table rowHeight] + 2) * 10 + 20;
  rect = [panel frameRectForContentRect:rect];
  origSize.height = rect.size.height;
}

@end

/**
 * Carbon entry point and C-callable wrapper functions
 */
OSStatus
initializeBundle(OSStatus (*callBack)(int))
{
  CocoaWinController *candWin;
  NSAutoreleasePool *localPool;

  localPool = [[NSAutoreleasePool alloc] init];        

  candWin = [[CocoaWinController alloc] init];
  [candWin setCallBack:callBack];

  [localPool release];

  return noErr;
}

/**
 * move candidates-window to front
 */
OSStatus
orderWindowFront(SInt16 inQDX, SInt16 inQDY, SInt16 inLineHeight, SInt16 inAlpha)
{
  NSAutoreleasePool *localPool;
        
  localPool = [[NSAutoreleasePool alloc] init];        
  [[CocoaWinController sharedController] reloadData];
  [[CocoaWinController sharedController] showWindow:inQDX:inQDY:inLineHeight
                                              alpha:inAlpha];
  [localPool release];

  return noErr;
}

/**
 * move candidates-window to back
 */
OSStatus
orderWindowBack()
{
  NSAutoreleasePool *localPool;

  localPool = [[NSAutoreleasePool alloc] init];        
  [[CocoaWinController sharedController] hideWindow];
  [localPool release];

  return noErr;
}

/**
 * returns YES if the candidate window is visible
 */
Boolean
windowIsVisible()
{
  NSAutoreleasePool *localPool;
  Boolean visible = false;
  
  localPool = [[NSAutoreleasePool alloc] init];
  visible = [[CocoaWinController sharedController] isVisible];
  [localPool release];
  
  return visible;
}

/**
 * get the candidate string
 */
UniCharPtr
getCandidate(UInt32 inIndex)
{
  NSAutoreleasePool *localPool;
  UniCharPtr str = nil;

  localPool = [[NSAutoreleasePool alloc] init];        
  str = [[CocoaWinController sharedController] getCandidate:inIndex];
  [localPool release];

  return str;
}

/**
 * add a candidate
 */
OSStatus
addCandidate(UniCharPtr inHead, int inHeadLen,
             UniCharPtr inCand, int inCandLen)
{
  NSAutoreleasePool *localPool;

  localPool = [[NSAutoreleasePool alloc] init];        
  [[CocoaWinController sharedController]
    addCandidate:inHead:inHeadLen:inCand:inCandLen];
  [localPool release];

  return noErr;
}

/**
 * clear candidates
 */
OSStatus
clearCandidate()
{
  NSAutoreleasePool *localPool;

  localPool = [[NSAutoreleasePool alloc] init];        
  [[CocoaWinController sharedController] clearCandidate];
  [localPool release];

  return noErr;
}

/**
 * select a candidate
 */
OSStatus
selectCandidate(int inIndex)
{
  NSAutoreleasePool *localPool;

  localPool = [[NSAutoreleasePool alloc] init];        
  [[CocoaWinController sharedController] selectCandidate:inIndex];
  [localPool release];

  return noErr;
}

/**
 * deselect a candidate
 */
OSStatus
deselectCandidate(int inIndex)
{
  NSAutoreleasePool *localPool;

  localPool = [[NSAutoreleasePool alloc] init];        
  [[CocoaWinController sharedController] deselectCandidate];
  [localPool release];

  return noErr;
}

/**
 * set the page label
 */
OSStatus
setPage(int inIndex, int inMax)
{
  NSAutoreleasePool *localPool;

  localPool = [[NSAutoreleasePool alloc] init];        
  [[CocoaWinController sharedController] setPage:inIndex:inMax];
  [localPool release];

  return noErr;
}

/**
 * set the candidate font
 */
OSStatus
setFont(CFStringRef name, float size)
{
  NSAutoreleasePool *localPool;
  NSString *fontName;

  localPool = [[NSAutoreleasePool alloc] init];        
  fontName = (NSString *) name;
  [[CocoaWinController sharedController] setFont:fontName
                                            size:size];
  [localPool release];
  
  return noErr;
}
