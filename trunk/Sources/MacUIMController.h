/*

  Copyright (c) 2009 MacUIM Project http://code.google.com/p/macuim/

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
#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

#import "CocoaWinController.h"
#import "UimHelperController.h"
#import "PreferenceController.h"
#include <uim.h>

#define kPropListUpdate	"prop_list_update\ncharset=UTF-8"

void UIMCommitString(void *ptr, const char *str);
void UIMPreeditClear(void *ptr);
void UIMPreeditPushback(void *ptr, int attr, const char *str);
void UIMPreeditUpdate(void *ptr);

void UIMCandActivate(void *ptr, int nr, int limit);
void UIMCandSelect(void *ptr, int index);
void UIMCandShiftPage(void *ptr, int forward);
void UIMCandDeactivate(void *ptr);

void UIMUpdatePropList(void *ptr, const char *str);

void UIMConfigurationChanged(void *ptr);
void UIMSwitchAppGlobalIM(void *ptr, const char *name);
void UIMSwitchSystemGlobalIM(void *ptr, const char *name);

static int convertKey(unsigned short keyCode,
		      NSUInteger flags,
		      NSString *string);
static unsigned int convertModifier(NSUInteger flags);
static char *get_caret_state_label_from_prop_list(const char *str);


@interface MacUIMController : IMKInputController {
	uim_context uc;

	NSMutableString *fixedBuffer;
	NSMutableAttributedString *preeditBuffer;

	NSInteger caretPos;
	NSInteger caretSegmentStartPos;
	NSInteger caretPrevSegLen;

	NSRect inputRect;	// position for candidate window
	id currentClient;

	BOOL candidateIsActive;
	int candidateIndex;
	int candidatePageIndex;
	int nrCandidates;
	int candidateDisplayLimit;

	CocoaWinController *candWin;
	UimHelperController *helperController;
	PreferenceController *pref;

	NSArray *attrArray;

	BOOL contextIsReleasing;
	NSUInteger previousPreeditLen;
	BOOL previousIsCommitString;
}

- (void)commitString:(const char *)str;
- (void)clearPreedit;
- (void)pushbackPreedit:(int)attr:(const char *)str;
- (void)updatePreedit;

- (void)activateCandidate:(int)nr:(int)limit;
- (void)selectCandidate:(int)index;
- (void)shiftPageCandidate:(int)forward;
- (void)deactivateCandidate;

- (void)updatePropList:(const char *)str;

- (void)configurationChanged;
- (void)switchAppGlobalIM:(const char *)name;
- (void)switchSystemGlobalIM:(const char *)name;

- (void)checkValidAttributesForMarkedText:(id)client;
- (CGWindowLevel)clientWindowLevel;

- (uim_context)uc;
- (void)setPageCandidates:(unsigned int)page;
- (int)indexFromIndexInPage:(int)pageIndex;

- (void)openSystemPrefs:(id)sender;
- (void)openUimHelp:(id)sender;

+ (id)activeContext;
+ (void)updateCustom:(const char *)custom:(const char *)val;
+ (void)switchIM:(const char *)im;

@end
