/*
  Copyright (c) 2009 MacUIM contributors, All rights reserved.

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

#import "AnnotationWinController.h"
#import "PreferenceController.h"
#import "MacUIMController.h"

static AnnotationWinController *sharedController;

@implementation AnnotationWinController
 
+ (id)sharedController
{
	return sharedController;
}

/**
 * Initialize
 */
- (void)awakeFromNib
{
	sharedController = self;

	pref = [PreferenceController sharedController];
	//[self setFont:(NSString *)[pref annotationFont] size:[pref annotationFontSize]];
}

- (void)showWindow:(NSRect)rect
{
	[panel setFrameOrigin:rect.origin];
	if ([panel isVisible] == NO) {
		CGWindowLevel level;
		level = [[MacUIMController activeContext] clientWindowLevel];
		if (level != kCGAssistiveTechHighWindowLevelKey)
			level++;
		[panel orderFront:nil];
		[panel setLevel:level];
	}
}

- (void)hideWindow
{
	[panel orderOut:nil];
}

- (void)setAnnotation:(NSString *)annotation
{
	[self clearAnnotation];
	[view insertText:annotation];
	[view setSelectedRange:NSMakeRange(0,0)];
	[view scrollRangeToVisible:NSMakeRange(0,0)];
}

- (void)clearAnnotation
{
	[view setString:@""];
}

- (void)setFont:(NSString *)name size:(float)size
{
}

- (NSSize)size
{
	return [panel frame].size;
}
@end
