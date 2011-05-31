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

#import <Cocoa/Cocoa.h>
#import "PreferenceController.h"

#define kMaxWidth   700
#define kMaxHeight  50


@interface CocoaWinController : NSObject
{
	PreferenceController *pref;

	// vertical candidate panel
	IBOutlet NSPanel *panel;

	// vertical candidate table
	IBOutlet NSTableView *table;
  
	// vertical index label
	IBOutlet NSTextField *label;

	// header string array
	NSMutableArray *headArray;

	// candidate string array
	NSMutableArray *candArray;

	// annotation string array
	NSMutableArray *annotationArray;

	// widnow size when number of candidate is 10
	NSSize origSize;
  
	// candidate index
	int candIndex;

	// nr candidates
	int nrCandidates;
  
	// candidate font
	NSFont *font;
	NSFont *font_small;
}

- (void)showWindow:(NSRect)cursorRect;

- (void)hideWindow;

- (BOOL)isVisible;

- (void)reloadData;

- (void)addCandidate:(const char *)head:(const char *)cand:(const char *)annotation;
- (void)clearCandidate;

- (void)selectCandidate:(int)index:(int)indexInPage;

- (void)deselectCandidate;

- (void)setIndex:(int)index:(int)nr;

- (void)setLabel;

- (void)replaceWindow:(NSRect)cursorRect;

- (void)setFont:(NSString *)name size:(float)size;

- (void)showAnnotation:(int)indexInPage;

+ (id)sharedController;

@end
