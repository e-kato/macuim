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
#import "MacUIMController.h"
#include "KeycodeToUKey.h"
#import "PreferenceController.h"
#import "ModeTipsController.h"
#import "MacUIMApplicationDelegate.h"
#include <uim-scm.h>
#include <uim-scm-abbrev.h>


static MacUIMController *activeContext;
static MacUIMController *lastDeactivatedContext;
static NSPointerArray *contextList;
static NSTimeInterval lastDeactivatedTime;

@implementation MacUIMController

- (id)initWithServer:(IMKServer*)server delegate:(id)delegate client:(id)inputClient
{
	//NSLog(@"initWithServer");
	if (self = [super initWithServer:server delegate:delegate client:inputClient]) {
		currentClient = nil;

		pref = [PreferenceController sharedController];

		uc = uim_create_context(self,
					"UTF-8",
					NULL,
					[pref imName],
					NULL,
					UIMCommitString);
		uim_set_preedit_cb(uc,
				   UIMPreeditClear,
				   UIMPreeditPushback,
				   UIMPreeditUpdate);
		uim_set_candidate_selector_cb(uc,
					      UIMCandActivate,
					      UIMCandSelect,
					      UIMCandShiftPage,
					      UIMCandDeactivate);

		fixedBuffer = [NSMutableString new];
		preeditBuffer = [NSMutableAttributedString new];
		previousPreeditLen = 0;
		previousIsCommitString = false;

		caretPos = -1;
		caretSegmentStartPos = -1;
		caretPrevSegLen = 0;

		candWin = [CocoaWinController sharedController];

		helperController = [UimHelperController sharedController];
		[helperController checkHelperConnection];

		contextIsReleasing = NO;
		modeIsChangedBySelf = NO;

		uim_set_mode_cb(uc, UIMUpdateMode);
#if 0
		uim_set_mode_list_update_cb(uc, UIMUpdateModeList);
#endif
		uim_set_prop_list_update_cb(uc, UIMUpdatePropList);

		uim_set_configuration_changed_cb(uc, UIMConfigurationChanged);
		uim_set_im_switch_request_cb(uc, UIMSwitchAppGlobalIM,
						 UIMSwitchSystemGlobalIM);
		uim_set_text_acquisition_cb(uc, UIMAcquireText,
						UIMDeleteText);

		if (!contextList)
			contextList = [[NSPointerArray pointerArrayWithWeakObjects] retain];
		[contextList addPointer:self];
	}

	return self;
}

- (void)activateServer:(id)sender
{
	//NSLog(@"activateServer %p", sender);

	currentClient = sender;
	activeContext = self;

	[currentClient retain];

	if (candidateIsActive == true)
		[candWin showWindow:inputRect];

	[helperController focusIn:uc];

	uim_prop_list_update(uc);
	uim_focus_in_context(uc);
}

- (void)deactivateServer:(id)sender
{
	//NSLog(@"deactivateServer %p", sender);
	uim_focus_out_context(uc);

	if (candidateIsActive == true)
		[candWin hideWindow];

	[currentClient release];
	currentClient = nil;

	[helperController focusOut:uc];

	lastDeactivatedContext = self;
	lastDeactivatedTime = [NSDate timeIntervalSinceReferenceDate];
}

- (void)commitString:(const char *)str
{
	//NSLog(@"commitString");
	[fixedBuffer appendString:[NSString stringWithUTF8String:str]];

	if ([fixedBuffer length] > 0) {
		if (currentClient != nil)
			[currentClient
				insertText:fixedBuffer
			  		replacementRange:
						NSMakeRange(NSNotFound, 0)];
		[fixedBuffer setString:@""];
		previousIsCommitString = true;
	}
}

- (void)clearPreedit
{
	//NSLog(@"clearPreedit");
	[preeditBuffer deleteCharactersInRange:
		NSMakeRange(0, [preeditBuffer length])];
	caretPos = -1;
	caretSegmentStartPos = -1;
	caretPrevSegLen = 0;
}

- (void)pushbackPreedit:(int)attr:(const char *)str
{
	NSInteger style = 0, len;
	NSAttributedString *theString;

	if (attr & UPreeditAttr_None)
		style = NSUnderlineStyleNone;
	if (attr & UPreeditAttr_UnderLine)
		style |= NSUnderlineStyleSingle;
	if (attr & UPreeditAttr_Reverse)
		style |= NSUnderlineStyleThick;

	//NSLog(@"pushbackPreedit: attr %d, style %d", attr, style);

	if (attr & UPreeditAttr_Separator) {
		//NSLog(@"Attr_Separator"); // FIXME
		;
	}

	theString = [[NSAttributedString alloc]
			initWithString:[NSString stringWithUTF8String:str]
			attributes:[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:style],
		      		NSUnderlineStyleAttributeName,
				nil]];

	len = [theString length];

	if (!(attr & UPreeditAttr_Cursor))
		caretPrevSegLen += len;

	[preeditBuffer appendAttributedString:theString];

	if (attr & UPreeditAttr_Cursor) {
		caretPos = [preeditBuffer length];
		if (len > 0)
			caretSegmentStartPos = caretPos - len;
		else
			caretSegmentStartPos = caretPos - caretPrevSegLen;
	}

	[theString release];
}

- (void)checkValidAttributesForMarkedText:(id)client
{
	NSUInteger nr;
	int i;

	attrArray = [client validAttributesForMarkedText];
	nr = [attrArray count];
	for (i = 0; i < nr; i++)
		NSLog(@"FIXME: Attributes %@", [attrArray objectAtIndex:i]);
}

- (void)updatePreedit
{
	//NSLog(@"update Preedit");
	//[self checkValidAttributesForMarkedText:currentClient];
	[currentClient setMarkedText:preeditBuffer
				selectionRange:
					NSMakeRange(caretPos >= 0 ?
							caretPos :
							[preeditBuffer length],
						    0)
				replacementRange:
					NSMakeRange(NSNotFound, 0)];
	NSUInteger len = [preeditBuffer length];
	if (len == 0 && previousPreeditLen > 0 && !previousIsCommitString) {
		[currentClient insertText:@""
			 replacementRange:NSMakeRange(NSNotFound, 0)];
	}
	previousPreeditLen = len;
	previousIsCommitString = false;
}

- (void)setPageCandidates:(unsigned int)page
{
	int i, pageNR, start;

	start = page * candidateDisplayLimit;
	if (candidateDisplayLimit &&
			((nrCandidates - start) > candidateDisplayLimit))
		pageNR = candidateDisplayLimit;
	else
		pageNR = nrCandidates - start;

	for (i = start; i < (start + pageNR); i++) {
		uim_candidate cand;
		const char *headStr, *candStr, *annotationStr;
		
		cand = uim_get_candidate(uc, i, candidateDisplayLimit ?
				(i % candidateDisplayLimit) : i);
		headStr = uim_candidate_get_heading_label(cand);
		candStr = uim_candidate_get_cand_str(cand);
		annotationStr = uim_candidate_get_annotation_str(cand);

		[candWin addCandidate:headStr:candStr:annotationStr];
		uim_candidate_free(cand);
	}
}

- (int)indexFromIndexInPage:(int)pageIndex
{
	int index;

	index = candidateDisplayLimit * candidatePageIndex + pageIndex;
	if (index >= nrCandidates)
		index = nrCandidates - 1;

	return index;
}

- (void)activateCandidate:(int)nr:(int)displayLimit
{
	NSRect theRect;
	NSDictionary *theDict = nil;

	//NSLog(@"activateCandidate");
	candidateIsActive = true;
	candidateIndex = -1;
	candidatePageIndex = 0;
	nrCandidates = nr;
	candidateDisplayLimit = displayLimit;

	[candWin clearCandidate];
	// set candidates
	[self setPageCandidates:0];
	// deselect 
	[candWin deselectCandidate];
	// set page label
	[candWin setIndex:0:nr];
	// show
	[candWin reloadData];

	if (caretSegmentStartPos >= 0) {
		@try {
			theRect = [currentClient firstRectForCharacterRange:
				NSMakeRange(caretSegmentStartPos, caretPos)];
		}
		@catch (NSException *exception) {
			NSLog(@"firstRectForCharacterRange failed. %@", [exception reason]);
		}
#if 0
		NSLog(@"caretSegmentStartPos %d, caretPos %d, rect origin.x %f, origin.y %f, size.width %f\n",
				caretSegmentStartPos,
				caretPos,
				theRect.origin.x, theRect.origin.y,
				theRect.size.width);
#endif
		@try {
			theDict = [currentClient attributesForCharacterIndex:caretSegmentStartPos lineHeightRectangle:&inputRect];
		}
		@catch (NSException *exception) {
			NSLog(@"attributesForCharacterIndex failed. %@", [exception reason]);
		}
		inputRect = theRect;
	} else {
		theDict = [currentClient attributesForCharacterIndex:0 lineHeightRectangle:&inputRect];
	}

	if (theDict) {
		BOOL isVertical = NO;
		NSFont *font = [theDict objectForKey:@"NSFont"];
		NSNumber *number =
			[theDict objectForKey:@"IMKTextOrientation"];

		if (number != nil && [number intValue] == 0)
			isVertical = YES;

		if (isVertical) {
			number = [theDict objectForKey:@"IMKLineHeight"];
			if (number != nil)
				inputRect.origin.x += [number floatValue];
		}

		if (font != nil) {
			if (!isVertical) {
				inputRect.origin.y +=
					CTFontGetUnderlinePosition((CTFontRef)font);
				inputRect.origin.y -=
					CTFontGetUnderlineThickness((CTFontRef)font);
			} else {
				inputRect.origin.x -=
					CTFontGetUnderlinePosition((CTFontRef)font);
				inputRect.origin.x +=
					CTFontGetUnderlineThickness((CTFontRef)font);
			}
		}
	}

	[candWin showWindow:inputRect];
}

- (void)selectCandidate:(int)index
{
	int newPage, indexInPage;

	newPage = candidateDisplayLimit ? index /
		candidateDisplayLimit : 0;
	indexInPage = candidateDisplayLimit ? index %
		candidateDisplayLimit : index;
	candidateIndex = index;

	if (newPage != candidatePageIndex) {
		candidatePageIndex = newPage;
		[candWin clearCandidate];
		[self setPageCandidates:newPage];
		[candWin reloadData];
		[candWin showWindow:inputRect];
	}

	[candWin selectCandidate:index:indexInPage];
}

- (void)shiftPageCandidate:(int)forward
{
	int newPage, newIndex, indexInPage;

	//NSLog(@"shift page: old page %d, index %d", candidatePageIndex,
	//		candidateIndex);
	if (candidateDisplayLimit) {
		int nrPage = (nrCandidates - 1) / candidateDisplayLimit + 1;

		if (forward)
			newPage = candidatePageIndex + 1;
		else
			newPage = candidatePageIndex - 1;

		if (newPage < 0)
			candidatePageIndex = nrPage - 1;
		else if (newPage >= nrPage)
			candidatePageIndex = 0;
		else
			candidatePageIndex = newPage;

		newIndex = (candidatePageIndex *
				candidateDisplayLimit) +
			(candidateIndex % candidateDisplayLimit);
		if (newIndex >= nrCandidates)
			candidateIndex = nrCandidates - 1;
		else
			candidateIndex = newIndex;

		indexInPage = candidateIndex % candidateDisplayLimit;
	} else {
		indexInPage = candidateIndex;
	}

	//NSLog(@"shift page new page %d, index %d", candidatePageIndex, candidateIndex);

	[candWin clearCandidate];
	[self setPageCandidates:candidatePageIndex];
	[candWin reloadData];
	[candWin showWindow:inputRect];
	[candWin selectCandidate:candidateIndex:indexInPage];

	uim_set_candidate_index(uc, candidateIndex);
}

- (void)deactivateCandidate
{
	[candWin hideWindow];
	candidateIsActive = NO;
}

- (void)updateMode:(int)mode
{
	const char *mode_name = uim_get_mode_name(uc, mode);
	const char *offlist[] = {"off", "direct", "直接入力", "영문", NULL};
	BOOL setOff = NO;
	int i;

	for (i = 0; offlist[i]; i++) {
		if (!strcmp(offlist[i], mode_name)) {
			setOff = YES;
			break;
		}
	}

	if (setOff == YES) {
		modeIsChangedBySelf = YES;
		if (currentClient != nil)
			[currentClient selectInputMode:(NSString *)kTextServiceInputModeRoman];
	} else {
		const char *lang;
		char *l;

		lang = get_uim_current_im_lang(uc);
		if (lang) {
			l = strdup(lang);
			if (!strcmp(l, "ja")) {
				modeIsChangedBySelf = YES;
				if (currentClient != nil)
					[currentClient selectInputMode:(NSString *)kTextServiceInputModeJapanese];
			} else if (!strcmp(l, "ko")) {
				modeIsChangedBySelf = YES;
				if (currentClient != nil)
					[currentClient selectInputMode:(NSString *)kTextServiceInputModeKorean];
			} else if (!strcmp(l, "zh") || !strcmp(l, "zh_CN")) {
				modeIsChangedBySelf = YES;
				if (currentClient != nil)
					[currentClient selectInputMode:(NSString *)kTextServiceInputModeSimpChinese];
			} else if (!strcmp(l, "zh_TW") || !strcmp(l, "zh_HK")) {
				modeIsChangedBySelf = YES;
				if (currentClient != nil)
					[currentClient selectInputMode:(NSString *)kTextServiceInputModeTradChinese];
			}
			free(l);
		}

	}
}

#if 0
- (void)updateModeList
{
	int i, n;
	//NSLog(@"updateModeList");
	n = uim_get_nr_modes(uc);
	for (i = 0; i < n; i++) {
		const char *name;
		name = uim_get_mode_name(uc, i);
//		NSLog(@"name: %@", [NSString stringWithUTF8String:name]);
	}
}
#endif

- (void)updatePropList:(const char *)str
{
	char *msg;

	if (self != activeContext)
		return;

	asprintf(&msg, "%s\n%s", kPropListUpdate, str);
	[helperController send:msg];
	free(msg);

	// show mode tips
	if ([pref enableModeTips] && currentClient != nil &&
	    contextIsReleasing == NO) {
#if 1
		// issue #2: hack for Microsoft Word
		NSTimeInterval thisTime = [NSDate timeIntervalSinceReferenceDate];
		NSString *bundleName;
		
		bundleName = [currentClient bundleIdentifier];

		if ([bundleName isEqualToString:@"com.microsoft.Word"] && 
		    (lastDeactivatedTime != 0.0 && 
		     (thisTime - lastDeactivatedTime) < 1.0)) {
			goto dont_show;
		}
#endif
		char *label = get_caret_state_label_from_prop_list(str);
		if (!label)
			goto dont_show;

		CFStringRef allstr =
			CFStringCreateWithCString(kCFAllocatorDefault,
						  label,
						  kCFStringEncodingUTF8);
		free(label);
		if (!allstr)
			return;

		CFArrayRef array =
			CFStringCreateArrayBySeparatingStrings(kCFAllocatorDefault, allstr, CFSTR("\t"));
		CFRelease(allstr);
		if (array) {
			NSRect cursorRect;
			NSDictionary *theDict;
			NSFont *font;
			@try {
				theDict = [currentClient
					attributesForCharacterIndex:0
						lineHeightRectangle:&cursorRect];
			}
			@catch (NSException *exception) {
				CFRelease(array);
				goto dont_show;
			}
			font = [theDict objectForKey:@"NSFont"];
			if (font != nil) {
				cursorRect.origin.y +=
					CTFontGetUnderlinePosition((CTFontRef)font);
				cursorRect.origin.y -=
					CTFontGetUnderlineThickness((CTFontRef)font);
			}

			// workaround for OS X 10.6.1
			if (!isnan(cursorRect.origin.y) &
			    cursorRect.origin.y > -1000000) {
				[[ModeTipsController sharedController]
					showModeTips:cursorRect:(NSArray *)array];
			}
			CFRelease(array);
		}
	}
dont_show:
	return;
}

- (void)configurationChanged
{
	;
}

- (void)switchAppGlobalIM:(const char *)name
{
	[MacUIMController switchIM:name];
	uim_prop_update_custom(uc, "custom-preserved-default-im-name", name);
}

- (void)switchSystemGlobalIM:(const char *)name
{
	char *msg;

	[MacUIMController switchIM:name];

	asprintf(&msg, "%s\n%s\n", "im_change_whole_desktop", name);
	[helperController send:msg];
	free(msg);
}

- (int)acquirePrimaryText:(enum UTextOrigin)origin:(int)former_req_len:(int)latter_req_len:(char **)former:(char **)latter
{
	NSRange range;
	NSAttributedString *attrString = nil;
	NSString *theString;
	NSInteger start;
	NSUInteger length, i;
	
	range = [currentClient selectedRange];
	//NSLog(@"selectedRange %d, %d\n", range.location, range.length);

	switch (origin) {
	case UTextOrigin_Cursor:
		if (former_req_len >= 0) {
			start = range.location - former_req_len;
			if (start < 0)
				start = 0;
		} else if (former_req_len == UTextExtent_Full ||
			   former_req_len == UTextExtent_Line) {
			start = 0;
		} else {
			/* not supported */
			return -1;
		}
		length = range.location - start;
		if (length > 0)
			attrString = [currentClient attributedSubstringFromRange:NSMakeRange(start, length)];
		if (attrString != nil) {
			const char *str = [[attrString string] UTF8String];
			char *p;
			if (former_req_len == UTextExtent_Line &&
			    (p = strrchr(str, '\n')))
				*former = strdup(p + 1);
			else
				*former = strdup(str);
		} else
			*former = NULL;

		if (latter_req_len >= 0) {
			start = range.location;
			length = latter_req_len;
		} else {
			/* not supported */
			return -1;
		}
		theString = nil;
		if (![[currentClient bundleIdentifier]
				isEqualToString:@"com.apple.Safari"]) {
			i = length;
			while (i > 0) {
				attrString = [currentClient attributedSubstringFromRange:NSMakeRange(start + (length - i), 1)];
				if (attrString != nil) {
					if (theString == nil) {
						theString = [attrString string];
					} else {
						theString = [theString stringByAppendingString:[attrString string]];
					}
				} else {
					break;
				}
				i--;
			}
		}
		if (theString != nil)
			*latter = strdup([theString UTF8String]);
		else
			*latter = NULL;
		break;

	case UTextOrigin_Beginning:
		start = 0;
		*former = NULL;

		if (latter_req_len >= 0) {
			length = latter_req_len;
		} else {
			/* not supported: UTextExtent_Line and others*/
			return -1;
		}
		theString = nil;
		if (![[currentClient bundleIdentifier]
				isEqualToString:@"com.apple.Safari"]) {
			i = length;
			while (i > 0) {
				attrString = [currentClient attributedSubstringFromRange:NSMakeRange(start + (length - i), 1)];
				if (attrString != nil) {
					if (theString == nil) {
						theString = [attrString string];
					} else {
						theString = [theString stringByAppendingString:[attrString string]];
					}
				} else {
					break;
				}
				i--;
			}
		}
		if (theString != nil)
			*latter = strdup([theString UTF8String]);
		else
			*latter = NULL;
		break;

	case UTextOrigin_End:
		/* we can't determine whether range.location is at the end */
	case UTextOrigin_Unspecified:
	default:
		/* not supported */
		return -1;
	}
	//NSLog(@"former %s, latter %s\n", *former, *latter);

	return 0;
}

- (int)acquireSelectedText:(enum UTextOrigin)origin:(int)former_req_len:(int)latter_req_len:(char **)former:(char **)latter
{
	NSRange range;
	NSAttributedString *theString = nil;
	NSInteger start;
	NSUInteger length;
	
	range = [currentClient selectedRange];
	//NSLog(@"selectedRange %d, %d\n", range.location, range.length);

	if (range.location == NSNotFound || range.length == 0)
		return -1;

	switch (origin) {
	case UTextOrigin_Beginning:
	/* cusror is always at the beginning of selected text */
	case UTextOrigin_Cursor:
		start = range.location;
		*former = NULL;

		if (latter_req_len >= 0) {
			length = latter_req_len;
			if (length > range.length)
				length = range.length;
		} else {
			if (latter_req_len == UTextExtent_Full ||
			    latter_req_len == UTextExtent_Line)
				length = range.length;
			else {
				return -1;
			}
		}
		theString = [currentClient attributedSubstringFromRange:NSMakeRange(start, length)];
		if (theString != nil) {
			const char *str = [[theString string] UTF8String];
			char *p;
			if (latter_req_len == UTextExtent_Line &&
			    (p = strchr(str, '\n')))
				*p = '\0';
			*latter = strdup(str);
		} else
			*latter = NULL;
		break;

	case UTextOrigin_End:
		if (former_req_len >= 0) {
			start = range.location + range.length - former_req_len;
			length = former_req_len;
			if (start < 0) {
				start = range.location;
				length = range.length;
			}

		} else if (former_req_len == UTextExtent_Full ||
			   former_req_len == UTextExtent_Line) {
			start = range.location;
			length = range.length;
		} else {
			/* not supported */
			return -1;
		}
		if (length > 0)
			theString = [currentClient attributedSubstringFromRange:NSMakeRange(start, length)];
		if (theString != nil) {
			const char *str = [[theString string] UTF8String];
			char *p;
			if (former_req_len == UTextExtent_Line && (p =
						strrchr(str, '\n')))
				*former = strdup(str + 1);
			else
				*former = strdup(str);
		} else
			*former = NULL;

		*latter = NULL;
		break;

	default:
		/* not supported */
		return -1;
	}
	//NSLog(@"selection former %s, latter %s\n", *former, *latter);

	return 0;
}


- (int)acquireClipboardText:(enum UTextOrigin)origin:(int)former_req_len:(int)latter_req_len:(char **)former:(char **)latter
{
	NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
	NSUInteger length;
	NSInteger offset;
	NSString *string;
	const char *str;
	char *p;

	if ([[pasteboard types]
		containsObject:NSStringPboardType] == YES) {
		string = [pasteboard stringForType:NSStringPboardType];
		if (string == nil)
			return -1;
		length = [string length];
	} else {
		return -1;
	}

	/*
	   Treating the cursor position is virtually at the end for
	   UTextArea_Clipboard
	 */
	switch (origin) {
	case UTextOrigin_Cursor:
	case UTextOrigin_End:
		offset = 0;
		if (former_req_len >= 0) {
			if (former_req_len < length)
				offset = length - former_req_len;
		} else if (former_req_len != UTextExtent_Full && 
			   former_req_len != UTextExtent_Line) {
			return -1;
		}
		str = [[string substringFromIndex:offset] UTF8String];
		if (former_req_len == UTextExtent_Line &&
		    (p = strrchr(str, '\n')))
			*former = strdup(p + 1);
		else
			*former = strdup(str);
		*latter = NULL;
		break;
	case UTextOrigin_Beginning:
		if (latter_req_len >= 0) {
			if (latter_req_len < length)
				length = latter_req_len;
		} else if (latter_req_len != UTextExtent_Full && 
			   latter_req_len != UTextExtent_Line) {
			return -1;
		}
		*former = NULL;
		str = [[string substringToIndex:length] UTF8String];
		if (latter_req_len == UTextExtent_Line &&
		    (p = strchr(str, '\n')))
			length = p - str;
		*latter = strdup([[string substringToIndex:length] UTF8String]);
		break;

	default:
		return -1;
	}

	return 0;
}

- (int)acquireText:(enum UTextArea)text_id:(enum UTextOrigin)origin:(int)former_req_len:(int)latter_req_len:(char **)former:(char **)latter
{
	int err;

	switch (text_id) {
	case UTextArea_Primary:
		err = [self acquirePrimaryText:origin:former_req_len:latter_req_len:former:latter];
		break;
	case UTextArea_Selection:
		err = [self acquireSelectedText:origin:former_req_len:latter_req_len:former:latter];
		break;
	case UTextArea_Clipboard:
		err = [self acquireClipboardText:origin:former_req_len:latter_req_len:former:latter];
		break;
	case UTextArea_Unspecified:
        default:
		err = -1;
	}

	return err;
}

- (int)deletePrimaryText:(enum UTextOrigin)origin:(int)former_req_len:(int)latter_req_len
{
	NSRange range;
	NSInteger start;
	NSUInteger length, i, removed_length = 0;
	
	range = [currentClient selectedRange];
	//NSLog(@"selectedRange %d, %d\n", range.location, range.length);

	if (range.length > 0)
		/* selection existed */
		return -1;

	switch (origin) {
	case UTextOrigin_Cursor:
		if (former_req_len >= 0) {
			start = range.location - former_req_len;
			if (start < 0)
				start = 0;
			length = range.location - start;
		} else if (former_req_len == UTextExtent_Full) {
			start = 0;
			length = range.location;
		} else if (former_req_len == UTextExtent_Line) {
			start = 0;
			length = range.location;
			NSAttributedString *attrString =
				[currentClient attributedSubstringFromRange:NSMakeRange(start, length)];
			if (attrString != nil) {
				NSString *str = [attrString string];
				NSRange newRange =
					[str rangeOfString:@"\n"
						   options:NSBackwardsSearch];
				if (newRange.location != NSNotFound) {
					start = newRange.location + 1;
					length = range.location - start;
				}
			}
		} else {
			/* not supported */
			return -1;
		}
		if (length > 0) {
			[currentClient setMarkedText:@""
				      selectionRange:NSMakeRange(0, 0)
				    replacementRange:NSMakeRange(start,
						    length)];
			//NSLog(@"start %d, length %d\n", start, length);
			[currentClient insertText:@""
				 replacementRange:NSMakeRange(start, length)];
			removed_length = length;
		}

		if (latter_req_len >= 0) {
			start = range.location - removed_length;
			if (start < 0)
				start = 0;
			length = latter_req_len;
		} else {
			/* not supported */
			return -1;
		}
		if (![[currentClient bundleIdentifier]
				isEqualToString:@"com.apple.Safari"]) {
			i = length;
			while (i > 0) {
				[currentClient setMarkedText:@""
					      selectionRange:NSMakeRange(0, 0)
					    replacementRange:NSMakeRange(start, 1)];
				//NSLog(@"start %d, length %d\n", start, length);
				[currentClient insertText:@""
					 replacementRange:NSMakeRange(start, 1)];
				i--;
			}
		}
		break;

	case UTextOrigin_Beginning:
		start = 0;

		if (latter_req_len >= 0) {
			length = latter_req_len;
		} else {
			/* not supported: UTextExtent_Line and others */
			return -1;
		}
		if (![[currentClient bundleIdentifier]
				isEqualToString:@"com.apple.Safari"]) {
			i = length;
			while (i > 0) {
				[currentClient setMarkedText:@""
					      selectionRange:NSMakeRange(0, 0)
					    replacementRange:NSMakeRange(start, 1)];
				[currentClient insertText:@""
					 replacementRange:NSMakeRange(start, 1)];
				i--;
			}
		}
		break;

	case UTextOrigin_End:
		/* we can't determine whether range.location is at the end */
	case UTextOrigin_Unspecified:
	default:
		/* not supported */
		return -1;
	}

	return 0;

}

- (int)deleteSelectedText:(enum UTextOrigin)origin:(int)former_req_len:(int)latter_req_len
{
	NSRange range;
	NSInteger start;
	NSUInteger length;
	
	range = [currentClient selectedRange];
	//NSLog(@"selectedRange %d, %d\n", range.location, range.length);

	if (range.location == NSNotFound || range.length == 0)
		return -1;

	switch (origin) {
	case UTextOrigin_Beginning:
	/* cusror is always at the beginning of selected text */
	case UTextOrigin_Cursor:
		start = range.location;

		if (latter_req_len >= 0) {
			length = latter_req_len;
			if (length > range.length)
				length = range.length;
		} else {
			if (latter_req_len == UTextExtent_Full) {
				length = range.length;
			} else if (latter_req_len == UTextExtent_Line) {
				length = range.length;
				NSAttributedString *attrString =
					[currentClient attributedSubstringFromRange:range];
				if (attrString != nil) {
					NSString *str = [attrString string];
					NSRange newRange =
						[str rangeOfString:@"\n"];
					if (newRange.location != NSNotFound) {
						length = newRange.location - start;
					}
				}
			} else {
				return -1;
			}
		}
		if (length > 0) {
			[currentClient setMarkedText:@""
				      selectionRange:NSMakeRange(0, 0)
				    replacementRange:NSMakeRange(start, length)];
			[currentClient insertText:@"" replacementRange:NSMakeRange(start, length)];
		}
		break;

	case UTextOrigin_End:
		if (former_req_len >= 0) {
			start = range.location + range.length - former_req_len;
			length = former_req_len;
			if (start < 0) {
				start = range.location;
				length = range.length;
			}

		} else if (former_req_len == UTextExtent_Full) {
			start = range.location;
			length = range.length;
		} else {
			/* not supported: UTextExtent_Line and others */
			return -1;
		}
		if (length > 0) {
			[currentClient setMarkedText:@""
				      selectionRange:NSMakeRange(0, 0)
				    replacementRange:NSMakeRange(start, length)];
			[currentClient insertText:@"" replacementRange:NSMakeRange(start, length)];
		}
		break;

	default:
		/* not supported */
		return -1;
	}

	return 0;
}

- (int)deleteText:(enum UTextArea)text_id:(enum UTextOrigin)origin:(int)former_req_len:(int)latter_req_len
{
	int err;

	switch (text_id) {
	case UTextArea_Primary:
		err = [self deletePrimaryText:origin:former_req_len:latter_req_len];
		break;
	case UTextArea_Selection:
		err = [self deleteSelectedText:origin:former_req_len:latter_req_len];
		break;
	case UTextArea_Clipboard:
	case UTextArea_Unspecified:
        default:
		err = -1;
		break;
	}

	return err;
}


- (void)dealloc
{
	//NSLog(@"dealloc");
	contextIsReleasing = YES;
	uim_release_context(uc);
	contextIsReleasing = NO;
	[fixedBuffer release];
	[preeditBuffer release];
	int i, count;
	count = [contextList count];
	for (i = 0; i < count; i++) {
		if ([contextList pointerAtIndex:i] == self)
			break;
	}
	if (i < count)
		[contextList removePointerAtIndex:i];

	[super dealloc];
}

- (void)finalize
{
	NSLog(@"finalize");
	[candWin release];
	[helperController release];
	[super finalize];
}


- (BOOL)handleEvent:(NSEvent*)event client:(id)sender
{
	unsigned short keyCode;
	NSUInteger flags;
	NSString *string;
	int rv = 1, key, mod;

	switch([event type]) {
	case NSKeyDown:
		keyCode = [event keyCode];
		flags = [event modifierFlags];
		string = [event characters];

		key = convertKey(keyCode, flags, string);
		mod = convertModifier(flags);

		//NSLog(@"key 0x%x, mod 0x%x", key, mod);

		rv = uim_press_key(uc, key, mod);
		uim_release_key(uc, key, mod);

		if (key == UKey_Private1 || key == UKey_Private2)
			rv = 0;

		break;
	case NSKeyUp:
		NSLog(@"keyUp");
		break;
	default:
		break;
	}

	return !rv ? YES : NO;
}

- (void)commitComposition:(id)sender
{
	//NSLog(@"commitComposition");
	if ([fixedBuffer length] > 0) {
		[sender insertText:fixedBuffer
		 	 	replacementRange:
					NSMakeRange(NSNotFound, 0)];
		[fixedBuffer setString:@""];
	}
	if (self == activeContext) {
		uim_displace_context(uc);
		uim_place_context(uc);
	} else {
		uim_reset_context(uc);
	}
}

- (void)setValue:(id)value forTag:(long)tag client:(id)sender
{
	NSString *newModeString = (NSString*)[value copy];
	//NSLog(@"setValue: %@", (NSString *)newModeString);

	if ([newModeString isEqual:(NSString *)kTextServiceInputModeRoman] ||
	    [newModeString isEqual:(NSString *)kTextServiceInputModePassword]) {
		if (!modeIsChangedBySelf) {
			uim_press_key(uc, UKey_Private1, 0);
			uim_release_key(uc, UKey_Private1, 0);
		}
		modeIsChangedBySelf = NO;
	} else if ([newModeString isEqual:(NSString *)kTextServiceInputModeJapanese] ||
		   [newModeString isEqual:(NSString *)kTextServiceInputModeJapaneseHiragana] ||
		   [newModeString isEqual:(NSString *)kTextServiceInputModeJapaneseKatakana] ||
		   [newModeString isEqual:(NSString *)kTextServiceInputModeJapaneseHalfWidthKana] ||
		   [newModeString isEqual:(NSString *)kTextServiceInputModeJapaneseFullWidthRoman] ||
		   [newModeString isEqual:(NSString *)kTextServiceInputModeJapaneseFirstName] ||
		   [newModeString isEqual:(NSString *)kTextServiceInputModeJapaneseLastName] ||
		   [newModeString isEqual:(NSString *)kTextServiceInputModeJapanesePlaceName] ||
		   [newModeString isEqual:(NSString *)kTextServiceInputModeTradChinese] ||
		   [newModeString isEqual:(NSString *)kTextServiceInputModeSimpChinese] ||
		   [newModeString isEqual:(NSString *)kTextServiceInputModeKorean]) {
		if (!modeIsChangedBySelf) {
			uim_press_key(uc, UKey_Private2, 0);
			uim_release_key(uc, UKey_Private2, 0);
		}
		modeIsChangedBySelf = NO;
	}
	[newModeString release];
}

- (CGWindowLevel)clientWindowLevel
{
	if (currentClient != nil)
		return [currentClient windowLevel];
	else
		return NSFloatingWindowLevel;
}
- (uim_context)uc
{
	return uc;
}

- (NSMenu *)menu
{
	return [[NSApp delegate] menu];
}

+ (id)activeContext
{
	return activeContext;
}

+ (void)updateCustom:(const char *)custom:(const char *)val
{
	int i, n;
	
	n = [contextList count];
	for (i = 0; i < n; i++) {
		uim_prop_update_custom([(MacUIMController *)[contextList pointerAtIndex:i] uc],
				       custom, val);
		break; /* all custom variables are global */
	}
}

+ (void)switchIM:(const char *)im
{
	int i, n;
	
	n = [contextList count];
	for (i = 0; i < n; i++)
		uim_switch_im([(MacUIMController *)[contextList pointerAtIndex:i] uc], im);
}

- (void)openSystemPrefs:(id)sender
{
	[NSTask launchedTaskWithLaunchPath:@"/usr/bin/open"
				 arguments:[NSArray arrayWithObject:@"/Library/PreferencePanes/MacUIM.prefPane"]];
}

- (void)openUimHelp:(id)sender
{
	[NSTask launchedTaskWithLaunchPath:@"/Library/Frameworks/UIM.framework/Versions/Current/bin/uim-help"
				 arguments:[NSArray arrayWithObject:@""]];
}
@end

static int convertKey(unsigned short keyCode,
		      NSUInteger flags,
		      NSString *string)
{
	int key = 0;
	int i;
	UniChar charCode = 0;

	/* Check for special keys first */
	for (i = 0; KeycodeToUKey[i].ukey; i++) {
		if (KeycodeToUKey[i].keycode == keyCode) {
			key = KeycodeToUKey[i].ukey;
			break;
		}
	}

	if (key == 0) {
		if ([string length] > 0) {
			key = charCode = [string characterAtIndex:0];
		}
		// convert control sequence to normal
		// charactor
		if (flags & NSControlKeyMask) {
			// (when <control> + [A-Za-z])
			if (charCode >= 0x01 && charCode <= 0x1a) {
				if (flags & NSShiftKeyMask)
					key += 0x40;
				else
					key += 0x60;
			} else { // (when <control> + <special charactor>)
				for (i = 0; CharToKey[i].ckey; i++) {
					if (CharToKey[i].charcode == charCode) {
						key = CharToKey[i].ckey;
						break;
					}
				}
			}
		}
	}
	//NSLog(@"keyCode 0x%x, flags %u, charCode 0x%x, key 0x%x, string %@", keyCode, flags, charCode, key, string);

	return key;
}

static unsigned int convertModifier(NSUInteger flags)
{
	unsigned int mod = 0;

	if (flags & NSShiftKeyMask)
		mod |= UMod_Shift;
	if (flags & NSControlKeyMask)
		mod |= UMod_Control;
	if (flags & NSAlternateKeyMask)
		mod |= UMod_Alt;
	if (flags & NSCommandKeyMask)
		mod |= UMod_Meta;

	return mod;
}

static const char *get_uim_current_im_lang_internal(uim_context uc)
{
	uim_lisp im, str_;
	const char *str;

	im = uim_scm_callf("uim-context-im", "p", uc);
	str_ = uim_scm_callf("im-lang", "o", im);
	str = REFER_C_STR(str_);
	
	return str;
}

static const char *get_uim_current_im_lang(uim_context uc)
{
	return uim_scm_call_with_gc_ready_stack((uim_gc_gate_func_ptr)get_uim_current_im_lang_internal, uc);
}

void UIMCommitString(void *ptr, const char *str)
{
	[(MacUIMController *)ptr commitString:str];
}

void UIMPreeditClear(void *ptr)
{
	[(MacUIMController *)ptr clearPreedit];
}

void UIMPreeditPushback(void *ptr, int attr, const char *str)
{
	[(MacUIMController *)ptr pushbackPreedit:attr:str];
}

void UIMPreeditUpdate(void *ptr)
{
	[(MacUIMController *)ptr updatePreedit];
}

void UIMCandActivate(void *ptr, int nr, int limit)
{
	[(MacUIMController *)ptr activateCandidate:nr:limit];
}

void UIMCandSelect(void *ptr, int index)
{
	[(MacUIMController *)ptr selectCandidate:index];
}

void UIMCandShiftPage(void *ptr, int forward)
{
	[(MacUIMController *)ptr shiftPageCandidate:forward];
}

void UIMCandDeactivate(void *ptr)
{
	[(MacUIMController *)ptr deactivateCandidate];
}

void UIMUpdateMode(void *ptr, int mode)
{
	[(MacUIMController *)ptr updateMode:mode];
}

#if 0
void UIMUpdateModeList(void *ptr)
{
	[(MacUIMController *)ptr updateModeList];
}
#endif

void UIMUpdatePropList(void *ptr, const char *str)
{
	[(MacUIMController *)ptr updatePropList:str];
}

void UIMConfigurationChanged(void *ptr)
{
	[(MacUIMController *)ptr configurationChanged];
}

void UIMSwitchAppGlobalIM(void *ptr, const char *name)
{
	[(MacUIMController *)ptr switchAppGlobalIM:name];
}

void UIMSwitchSystemGlobalIM(void *ptr, const char *name)
{
	[(MacUIMController *)ptr switchSystemGlobalIM:name];
}

int UIMAcquireText(void *ptr, enum UTextArea text_id, enum UTextOrigin origin,
		    int former_req_len, int latter_req_len,
		    char **former, char **latter)
{
	return [(MacUIMController *)ptr
		acquireText:text_id:origin:former_req_len:latter_req_len:former:latter];
}

int UIMDeleteText(void *ptr, enum UTextArea text_id, enum UTextOrigin origin,
		  int former_req_len, int latter_req_len)
{
	return [(MacUIMController *)ptr
		deleteText:text_id:origin:former_req_len:latter_req_len];
}

char *get_caret_state_label_from_prop_list(const char *str)
{
	const char *p, *q;
	char *state_label = NULL;
	char label[10];
	int len, state_label_len = 0;

	p = str;
	while ((p = strstr(p, "branch\t"))) {
		if ((p = strchr(p + 7, '\t'))) {
			p++;
			q = strchr(p, '\t');
			len = q - p;
			if (q && len < 10) {
				strncpy(label, p, len);
				label[len] = '\0';
				if (!state_label) {
					state_label_len = len;
					state_label = strdup(label);
				} else {
					state_label_len += (len + 1);
					state_label =
						(char *)realloc(state_label,
								state_label_len
								+ 1);
					if (state_label) {
						strcat(state_label, "\t");
						strcat(state_label, label);
						state_label[state_label_len] =
							'\0';
					}
				}
			}
		}
	}

	return state_label;
}
