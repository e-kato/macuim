/*
  Copyright (c) 2003-2009 MacUIM contributors, All rights reserved.

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

#import "CocoaWinController.h"
#import "MacUIMController.h"
#import "PreferenceController.h"
#import "AnnotationWinController.h"

static CocoaWinController *sharedController;

@implementation CocoaWinController
 
+ (id)sharedController
{
	if (!sharedController)
		[[self alloc] init];

	return sharedController;
}

/**
 * Initialize Cocoa
 */
- (id)init
{
	if (sharedController)
		return sharedController;

	self = [super init];
	if (![NSBundle loadNibNamed:@"CocoaWindow" owner:self]) {
		NSLog(@"failed to load CocoaWindow nib");
		[self release];
		return nil;
	}
	sharedController = self;

	pref = [PreferenceController sharedController];
	[self setFont:(NSString *)[pref candFont] size:[pref candFontSize]];

	origSize = [panel frame].size;
	candIndex = -1;

	[panel setFrame:NSMakeRect([panel frame].origin.x,
				   [panel frame].origin.y,
	                           origSize.width, 37)
		display:NO];

	return self;
}

- (void)dealloc
{
	sharedController = nil;

	[super dealloc];
}


/**
 * Show a CocoaWinController and make it activate
 */
- (void)showWindow:(NSRect)cursorRect
{
	float falpha = ((float)(100 - [pref candTransparency])) / 100.0;

	[panel setAutodisplay:NO];
	[self replaceWindow:cursorRect];

	if (candIndex >= 0) {
		NSIndexSet *indexSet =
			[[NSIndexSet alloc] initWithIndex:candIndex];
		[table selectRowIndexes:indexSet byExtendingSelection:NO];
		[indexSet release];
	}

	if ([panel isVisible] == NO) {
		CGWindowLevel level;
		MacUIMController *context = [MacUIMController activeContext];
		level = context ? [context clientWindowLevel]
			        : NSFloatingWindowLevel;

		if (level != kCGAssistiveTechHighWindowLevelKey)
			level++;

		[panel makeFirstResponder:table];
		[panel orderFront:nil];
		[panel setLevel:level];
		[panel setAlphaValue:falpha];
	}

	[panel setAutodisplay:YES];
	[panel makeKeyWindow];
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
	[panel setFrame:NSMakeRect(origin.x, origin.y, origSize.width, 37)
		display:NO];

	AnnotationWinController *AWin = [AnnotationWinController sharedController];
	[AWin hideWindow];
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
	annotationArray = [[NSMutableArray alloc] init];
}

/**
 * Get a number of rows in the TableView
 */
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [candArray count];
}

/**
 * Get data
 */
- (id)tableView:(NSTableView *)tableView
  objectValueForTableColumn:(NSTableColumn *)tableColumn
            row:(NSInteger)rowIndex
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
              row:(NSInteger)row
{
  /*
  [cell setDrawsBackground:YES];
  
  if (row % 2)
    [cell setBackgroundColor:[NSColor colorWithCalibratedWhite:0.95
                                                         alpha:1.0]];
  else
    [cell setBackgroundColor:[NSColor whiteColor]];
  */

#if 0
	[cell setFont:font];
#endif
}

- (void)addCandidate:(const char *)head
                    :(const char *)cand
                    :(const char *)annotation
{
	NSAttributedString *headStr;
	NSAttributedString *candStr;
	NSString *annotationStr;

	if (head) {
		// use just the last one character of the string
		int headLen = strlen(head);
		const char *shead;

		if (headLen)
			shead = head + headLen - 1;
		else
			shead = " ";

		headStr = [[[NSAttributedString alloc]
				initWithString:
					[NSString stringWithUTF8String:shead]
				attributes:
					[NSDictionary
						dictionaryWithObjectsAndKeys:
							font_small,
							NSFontAttributeName,
							nil]] autorelease];
	} else {
		headStr = [[[NSAttributedString alloc]
				initWithString:@""
				attributes:
					[NSDictionary
						dictionaryWithObjectsAndKeys:
							font_small,
							NSFontAttributeName,
							nil]] autorelease];
	}

	if (cand)
		candStr = [[[NSAttributedString alloc]
				initWithString:
					[NSString stringWithUTF8String:cand]
				attributes:
					[NSDictionary
						dictionaryWithObjectsAndKeys:
							font,
							NSFontAttributeName,
							nil]] autorelease];
	else
		candStr = [[[NSAttributedString alloc]
				initWithString:@""
				attributes:
					[NSDictionary
						dictionaryWithObjectsAndKeys:
							font,
							NSFontAttributeName,
							nil]] autorelease];
	if (annotation)
		annotationStr = [[[NSString alloc] initWithUTF8String:annotation] autorelease];
	else
		annotationStr = [[[NSString alloc] initWithString:@""] autorelease];

	[headArray addObject:headStr];
	[candArray addObject:candStr];
	[annotationArray addObject:annotationStr];
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
	[annotationArray removeAllObjects];

	AnnotationWinController *AWin =
		[AnnotationWinController sharedController];
	[AWin hideWindow];
}

/**
 * Select a candidate
 */
- (void)selectCandidate:(int)index:(int)indexInPage
{
	NSIndexSet *indexSet;

	indexSet = [[NSIndexSet alloc] initWithIndex:indexInPage];

	candIndex = index;
	
	[table selectRowIndexes:indexSet byExtendingSelection:NO];
	[table scrollRowToVisible:indexInPage];

	[indexSet release];

	[self setLabel];
	[self showAnnotation:indexInPage];
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
- (void)setIndex:(int)index:(int)nr
{
	nrCandidates = nr;

	[self setLabel];
}

- (void)setLabel
{
	NSString *str;

	if (candIndex >= 0)
		str = [NSString stringWithFormat:@"%d / %d", candIndex + 1,
							     nrCandidates];
	else
		str = [NSString stringWithFormat:@"- / %d", nrCandidates];

	[label setStringValue:str];
}

/**
 * Button press action
 */
- (IBAction)candClicked:(id)sender
{
	int index, indexInPage;

	indexInPage = [sender clickedRow];

	if (indexInPage < 0)
		return;

	index = [[MacUIMController activeContext]
			indexFromIndexInPage:indexInPage];

#if DEBUG_CANDIDATE_WINDOW
	NSLog(@"CocoaWinController::candClicked() %d, %d", [sender clickedRow], index);
#endif
	uim_set_candidate_index([[MacUIMController activeContext] uc], index);
	if ([panel isVisible])
		[self showAnnotation:indexInPage];
}

- (void)replaceWindow:(NSRect)cursorRect
{
	NSTableColumn *col;
	NSRect rect;
	float candWidth = 0.0;
	float headWidth = 0.0;
	int i;
	NSMutableAttributedString *text;  

	for (i = 0; i < [candArray count]; i++) {
		text = [candArray objectAtIndex:i];
		if (candWidth < [text size].width)
			candWidth = [text size].width;
	  
		text = [headArray objectAtIndex:i];
		if (headWidth < [text size].width)
			headWidth = [text size].width;
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

	NSPoint point = cursorRect.origin;

	point.y -= rect.size.height;

	// Search a screen of the cursor
	NSArray *screenArray = [NSScreen screens];
	int nScreen = [screenArray count];
	NSRect f;
	BOOL found = NO;
	for (i = 0; i < nScreen; i++) {
		f = [[screenArray objectAtIndex:i] frame];
		if (NSPointInRect(cursorRect.origin, f)) {
			found = YES;
			break;
		}
	}

	if (found) {
		if (point.x > f.origin.x + f.size.width - rect.size.width)
			point.x = f.origin.x + f.size.width - rect.size.width;
		if (point.y < f.origin.y)
			point.y = cursorRect.origin.y +
				  cursorRect.size.height * 1.4 + 5;
	}
#if DEBUG_CANDIDATE_WINDOW
	NSLog(@"CocoaWinController replaceWindow: x=%f y=%f width=%f, height %f\n",
	      point.x, point.y, rect.size.width, rect.size.height);
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
	if ((tmpFont = [NSFont fontWithName:name size:size*0.8])) {
		if (font_small)
			[font_small release];
		font_small = tmpFont;
		[font_small retain];
	}

#if DEBUG_CANDIDATE_WINDOW
	NSLog(@"CocoaWinController setFont: name=%@ size=%f font=%@",
	      name, size, font);
#endif
	text = [[[NSAttributedString alloc]
			initWithString:[font description]
			    attributes:
			    	[NSDictionary dictionaryWithObjectsAndKeys:
					font,
					NSFontAttributeName,
					nil]] autorelease];

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

- (void)showAnnotation:(int)indexInPage
{
	NSString *annotation;
	AnnotationWinController *AWin;

	if (![pref enableAnnotation])
		return;

	if (indexInPage < 0)
		return;

	AWin = [AnnotationWinController sharedController];
	annotation = [annotationArray objectAtIndex:indexInPage];

	if ([annotation compare:@""] != NSOrderedSame) {
		NSRect rect = [panel frame];
		rect.origin.x += rect.size.width;
		rect.origin.y -= ([AWin size].height - rect.size.height);

		/* check place */
		NSArray *screenArray = [NSScreen screens];
		int nScreen = [screenArray count];
		int i;
		NSRect f;
		BOOL found = NO;
		for (i = 0; i < nScreen; i++) {
			f = [[screenArray objectAtIndex:i] frame];
			if (NSPointInRect(rect.origin, f)) {
				found = YES;
				break;
			}
		}
		if (found) {
			NSPoint point = rect.origin;
			if (point.x > f.origin.x + f.size.width - [AWin size].width) {
				point.x = rect.origin.x - rect.size.width - [AWin size].width;
				rect.origin.x = point.x;
			}
		}

        	[AWin setAnnotation:annotation];
		[AWin showWindow:rect];
	} else {
        	[AWin clearAnnotation];
	        [AWin hideWindow];
	}
}

@end
