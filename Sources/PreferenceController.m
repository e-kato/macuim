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

#import "Debug.h"
#import "PreferenceController.h"
#import "CocoaWinController.h"
#import "MacUIMController.h"


static CFStringRef gCandFont;
static float gCandFontSize;
static CFIndex gCandTransparency;
static Boolean gEnableModeTips;
static Boolean gCandVertical;
static Boolean gEnableAnnotation;

static PreferenceController *sharedController;

@implementation PreferenceController

+ (id)sharedController
{
	if (!sharedController)
		[[self alloc] init];

	return sharedController;
}

- (id)init
{
	if (sharedController)
		return sharedController;

	self = [super init];
	sharedController = self;

	[self loadSetting];
	
	return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (void)loadSetting
{
	CFPropertyListRef propVal;
	Boolean dummy;

	gCandVertical =
		CFPreferencesGetAppBooleanValue(CFSTR(kPrefCandVertical),
						CFSTR(kAppID), &dummy);
	
	gCandTransparency =
		CFPreferencesGetAppIntegerValue(CFSTR(kPrefCandTransparency),
						CFSTR(kAppID), &dummy);
						
	propVal = CFPreferencesCopyAppValue(CFSTR(kPrefCandFont),
					    CFSTR(kAppID));
	if (propVal && CFGetTypeID(propVal) == CFStringGetTypeID()) {
		gCandFont = (CFStringRef)propVal;
	}
	if (propVal)
		CFRelease(propVal);

	propVal = CFPreferencesCopyAppValue(CFSTR(kPrefCandFontSize),
					    CFSTR(kAppID));
	if (propVal && CFGetTypeID(propVal) == CFNumberGetTypeID()) {
		CFNumberGetValue((CFNumberRef)propVal,
				kCFNumberFloatType, &gCandFontSize);
	}
	if (propVal)
		CFRelease(propVal);

	gEnableModeTips =
		CFPreferencesGetAppBooleanValue(CFSTR(kPrefModeTips),
						CFSTR(kAppID), &dummy);

	gEnableAnnotation =
		CFPreferencesGetAppBooleanValue(CFSTR(kPrefAnnotation),
						CFSTR(kAppID), &dummy);

	propVal = CFPreferencesCopyAppValue(CFSTR(kPrefIM), CFSTR(kAppID));
	if (propVal && CFGetTypeID(propVal) == CFStringGetTypeID()) {
		CFStringGetCString((CFStringRef)propVal, imName, BUFSIZ,
				   kCFStringEncodingMacRoman);
	} else
		[self setIMName:kDefaultIM];
	if (propVal)
		CFRelease(propVal);
}

- (void)setIMName:(const char *)str
{
	strlcpy(imName, str, BUFSIZ);
}

- (const char *)imName
{
	return imName;
}

- (CFStringRef)candFont
{
	return gCandFont;
}

- (int)candTransparency
{
	return gCandTransparency;
}

- (float)candFontSize
{
	return gCandFontSize;
}

- (BOOL)enableModeTips
{
	return gEnableModeTips ? YES : NO;
}

- (BOOL)enableAnnotation
{
	return gEnableAnnotation ? YES : NO;
}
@end

void NotificationCallback(CFNotificationCenterRef inCenter,
				 void *inObserver,
				 CFStringRef inName,
				 const void *inObject,
				 CFDictionaryRef inUserInfo) 
{
  CFStringRef im;
  char imName[BUFSIZ];
  CFBooleanRef on;
  CFStringRef fontName;
  CFNumberRef fontSize;
  CFNumberRef trans;
  
  if (!inUserInfo)
    return;

  imName[0] = '\0';
  im = CFDictionaryGetValue(inUserInfo, CFSTR(kPrefIM));

#if DEBUG_NOTIFY
  NSLog(@"NotificationCallback() im='%@'", (NSString *)im);
#endif
  if (im)
    CFStringGetCString(im, imName, BUFSIZ, kCFStringEncodingMacRoman);
    
  
  if ((on = CFDictionaryGetValue(inUserInfo, CFSTR(kPrefCandVertical))))
    gCandVertical = on == kCFBooleanTrue ? true : false;
  
  // candidate font
  if ((fontName = CFDictionaryGetValue(inUserInfo, CFSTR(kPrefCandFont)))) {
    if (gCandFont)
      CFRelease(gCandFont);
    gCandFont = CFRetain(fontName);
    if ((fontSize = CFDictionaryGetValue(inUserInfo, CFSTR(kPrefCandFontSize))))
      CFNumberGetValue(fontSize, kCFNumberFloatType, &gCandFontSize);

    [[CocoaWinController sharedController] setFont:(NSString *)gCandFont
					   size:gCandFontSize];
  }
    
  if ((trans = CFDictionaryGetValue(inUserInfo, CFSTR(kPrefCandTransparency))))
    CFNumberGetValue(trans, kCFNumberIntType, &gCandTransparency);
  
  if ((on = CFDictionaryGetValue(inUserInfo, CFSTR(kPrefModeTips))))
    gEnableModeTips = on == kCFBooleanTrue ? true : false;
  
  if ((on = CFDictionaryGetValue(inUserInfo, CFSTR(kPrefAnnotation))))
    gEnableAnnotation = on == kCFBooleanTrue ? true : false;

#if DEBUG_NOTIFY
  NSLog(@"NotificationCallback() vertical=%s transparency=%s modetips=%s\n",
              gCandVertical ? "true" : "false",
              gCandTransparency ? "true" : "false",
              gEnableModeTips ? "true" : "false");
#endif

  if (imName[0] != '\0') {
    [MacUIMController switchIM:imName];
    [[PreferenceController sharedController] setIMName:imName];
  }
}
