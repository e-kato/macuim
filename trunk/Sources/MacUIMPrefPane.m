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

#import <unistd.h>
#import <uim.h>

#import "Debug.h"
#import "Preference.h"
#import "MacUIMPrefPane.h"

#define ENABLE_NLS 1
#include "gettext.h"

#define PACKAGE    "uim"
#define LOCALEDIR  "/Library/Frameworks/UIM.framework/Versions/Current/share/locale"

static MacUIMPrefPane *sharedPane;

static void
prefChanged(CFNotificationCenterRef inCenter, void *inObserver, 
            CFStringRef inName, const void *inObject, 
            CFDictionaryRef inUserInfo);

@implementation MacUIMPrefPane
 
+ (id)sharedPane
{
  return sharedPane;
}

/**
 * Deallocate
 */
- (void)dealloc
{
  int i;
  
  if (numModules > 0 && imModules) {
    for (i = 0; i < numModules; i++) {
      free(imModules[i]->name);
      free(imModules[i]->lang);
    }
    free(imModules);
  }

  [imOnArray removeAllObjects];
  [imOnArray release];

  [imNameArray removeAllObjects];
  [imNameArray release];

  [imScriptArray removeAllObjects];
  [imScriptArray release];

  [super dealloc];
}

- (id)initWithBundle:(NSBundle *)bundle
{
  NSUserDefaults *defs;
  NSArray *langs;
  NSString *lang;
  NSString *locale;
  const char *lang_c;
  uim_context uc;
  
  // Initialize the location of our preferences
  if ((self = [super initWithBundle:bundle]) != nil) {
    appID = CFSTR(kAppID);
  }

  sharedPane = self;

  imOnArray = [[NSMutableArray alloc] init];
  imNameArray = [[NSMutableArray alloc] init];
  imScriptArray = [[NSMutableArray alloc] init];

  numModules = 0;
  imModules = NULL;
  
  defs = [NSUserDefaults standardUserDefaults];
  langs = [defs objectForKey:@"AppleLanguages"];
  lang = [langs objectAtIndex:0];
  locale = [defs objectForKey:@"AppleLocale"];

  lang_c = [lang UTF8String];
  setenv("LANG", lang_c, 1);
  setlocale(LC_CTYPE, [locale UTF8String]);
  
  bindtextdomain(PACKAGE, LOCALEDIR);
  textdomain(PACKAGE);
  bind_textdomain_codeset(PACKAGE, "UTF-8");
  
  // load IM modules
  uim_init();
  uc = uim_create_context(NULL, "UTF-8",
                          NULL, NULL, NULL, NULL);
  if (uc) {
    numModules = uim_get_nr_im(uc);
    imModules = (IMModule **) malloc(sizeof(IMModule *) * numModules);
    if (imModules != NULL) {
      int i;
      for (i = 0; i < numModules; i++) {
        imModules[i] = (IMModule *) malloc(sizeof(IMModule));
        if (imModules[i]) {
          imModules[i]->index = i;
          imModules[i]->name = strdup(uim_get_im_name(uc, i));
          imModules[i]->lang = strdup(uim_get_im_language(uc, i));
          imModules[i]->on = FALSE;
        }

        {
          UniCharPtr nameStr;
          UniCharPtr scriptStr;
          int len;

          [imOnArray addObject:[[[NSNumber alloc] initWithInt:NSOffState] autorelease]];
          
          len = [self charArrayToUni:imModules[i]->name
                              uniStr:&nameStr
                              encoding:kTextEncodingMacRoman];
          [imNameArray addObject:[[[NSString alloc] initWithCharacters:nameStr
                                                               length:len] autorelease]];
          
          len = [self charArrayToUni:imModules[i]->lang
                              uniStr:&scriptStr
                              encoding:kTextEncodingMacRoman];
          [imScriptArray addObject:[[[NSString alloc] initWithCharacters:scriptStr
                                                                 length:len] autorelease]];
        }
      }
    }
    uim_release_context(uc);
  }

  return self;
}

- (void)mainViewDidLoad
{
  CFPropertyListRef propVal;
  int i;
  CFIndex ind;
  Boolean dummy;
  
  [imButton removeAllItems];

  for (i = 0; i < numModules; i++) {
    //NSLog(@"mainViewDidLoad - imModules[%d]=%p", i, imModules[i]);
    if (!imModules[i]) continue;
    if (imModules[i]->lang && strlen(imModules[i]->lang) > 0)
      [imButton addItemWithTitle:[NSString stringWithFormat:@"%s (%s)",
                                           imModules[i]->name,
                                           imModules[i]->lang]];
    else
      [imButton addItemWithTitle:[NSString stringWithFormat:@"%s",
                                           imModules[i]->name,
                                           imModules[i]->lang]];
  }

  // input method name
  propVal = CFPreferencesCopyAppValue(CFSTR(kPrefIM), appID);
  if (propVal && CFGetTypeID(propVal) == CFStringGetTypeID()) {
    NSString *current = (NSString *) propVal;
    if (!current) goto reset;
    for (i = 0; i < numModules; i++) {
      if ([current isEqualToString:[NSString stringWithCString:imModules[i]->name]]) {
        [imButton selectItemAtIndex:i];
        goto done;
      }
    }
  }

reset:
  for (i = 0; i < numModules; i++) {
    if ([[NSString stringWithCString:kDefaultIM]
          isEqualToString:[NSString stringWithCString:imModules[i]->name]]) {
      [imButton selectItemAtIndex:i];
      break;
    }
  }
  
done:
  if (propVal)
    CFRelease(propVal);

  // display direction of candidate window (disabled)
#if 0
  if (CFPreferencesGetAppBooleanValue(CFSTR(kPrefCandVertical), appID, &dummy))
    [listDirection selectCellAtRow:0 column:0];
  else
    [listDirection selectCellAtRow:0 column:1];
#else
  [listDirection selectCellAtRow:0 column:0];
#endif
  
  [listDirection setEnabled:false];
  
  // candidate font
  {
    NSString *name = nil;
    NSNumber *size = nil;
    
    propVal = CFPreferencesCopyAppValue(CFSTR(kPrefCandFont), appID);
    if (propVal && CFGetTypeID(propVal) == CFStringGetTypeID())
      name = (NSString *) propVal;
    else {
      if (propVal)
	CFRelease(propVal);
    }
    
    propVal = CFPreferencesCopyAppValue(CFSTR(kPrefCandFontSize), appID);
    if (propVal && CFGetTypeID(propVal) == CFNumberGetTypeID())
      size = (NSNumber *) propVal;
    else {
      if (propVal)
	CFRelease(propVal);
    }
    
    if (name && size)
      font = [NSFont fontWithName:name size:[size floatValue]];
    else
      font = [NSFont userFontOfSize:16];
    
    [self updateFontSample];

    if (name)
      [name release];
    if (size)
      [size release];
  }
  
  // transparency of candidate window
  if ((ind = CFPreferencesGetAppIntegerValue(CFSTR(kPrefCandTransparency),
                                             appID, &dummy)))
    [opacitySlider setIntValue:ind];
  else
    [opacitySlider setIntValue:0];
  
  // modetips flag
  if (CFPreferencesGetAppBooleanValue(CFSTR(kPrefModeTips), appID, &dummy))
    [modeTipsButton setState:NSOnState];
  else
    [modeTipsButton setState:NSOffState];

   // annotation flag
  if (CFPreferencesGetAppBooleanValue(CFSTR(kPrefAnnotation), appID, &dummy))
    [annotationButton setState:NSOnState];
  else
    [annotationButton setState:NSOffState];
      
  // switchable input methods
  propVal = CFPreferencesCopyAppValue(CFSTR(kPrefHelperIM), appID);
  if (propVal && CFGetTypeID(propVal) == CFArrayGetTypeID()) {
    NSArray *array = (NSArray *) propVal;
    for (i = 0; i < [array count]; i++) {
      int j;
      NSString *switchIM = [array objectAtIndex:i];
      for (j = 0; j < numModules; j++) {
        if ([switchIM isEqualToString:[NSString stringWithCString:imModules[j]->name]]) {
          imModules[j]->on = TRUE;
          [imOnArray replaceObjectAtIndex:j
                               withObject:[[NSNumber alloc] initWithInt:NSOnState]];
        }
      }
    }
  }
  if (propVal)
    CFRelease(propVal);

  [tab selectFirstTabViewItem:self];
}

- (void)willSelect
{
  // set notification observer
  CFNotificationCenterRef center =
    CFNotificationCenterGetDistributedCenter();
  CFNotificationCenterAddObserver(center, (void *)self, prefChanged,
                                  CFSTR(kPrefChanged), CFSTR(kAppID),
                                  CFNotificationSuspensionBehaviorCoalesce);

  [appletButton setState:([self isExtraLoaded:kHelperID] ? NSOnState : NSOffState)];
}

- (void)didUnselect
{
  //[self prefSync];

  // clean up notification observer
  CFNotificationCenterRef center =
    CFNotificationCenterGetDistributedCenter();
  CFNotificationCenterRemoveObserver(center, (void *)self,
                                     CFSTR(kPrefChanged), CFSTR(kAppID));
}

/**
 * Imput method changed
 */
- (IBAction)imChange:(id)sender
{
  [self prefSync];
}

- (IBAction)appletChange:(id)sender
{
  // Extra load
  if (([appletButton state] == NSOnState)
      && ![self isExtraLoaded:kHelperID]) {
    [self loadExtra];
    if (![self isExtraLoaded:kHelperID]) {
      [appletButton setState:NSOffState];
    }
    [self prefSync];
  }
  else if (([appletButton state] == NSOffState)
           && [self isExtraLoaded:kHelperID]) {
    [self removeExtra:kHelperID];
    if ([self isExtraLoaded:kHelperID]) {
      [appletButton setState:NSOnState];
    }
  }
}

- (IBAction)imSwitchChange:(id)sender
{
  [self prefSync];
}

- (IBAction)imSwitchApply:(id)sender
{
  [self prefSync];
}

- (IBAction)listDirectionChange:(id)sender
{
  [self prefSync];
}

- (IBAction)modeTipsChange:(id)sender
{
  [self prefSync];
}

- (IBAction)opacityChange:(id)sender
{
  [self prefSync];
}

- (IBAction)chooseFont:(id)sender
{
  [[fontSample window] setDelegate:self];
  [[fontSample window] makeFirstResponder:[fontSample window]];
  [[NSFontManager sharedFontManager] orderFrontFontPanel:self];
  [[NSFontManager sharedFontManager] setSelectedFont:font isMultiple:NO];
}

- (IBAction)annotationChange:(id)sender
{
  [self prefSync];
}

- (void)changeFont:(id)fontManager
{
  [self setFont:(id) self];
}

- (void)setFont:(id)sender
{
  NSFont *newFont;
  
  newFont = [[NSFontManager sharedFontManager] convertFont:font];
  [font release];
  font = [newFont retain];
  
  [self updateFontSample];
    
  [self prefSync];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [imNameArray count];
}

- (id)tableView:(NSTableView *)tableView
  objectValueForTableColumn:(NSTableColumn *)tableColumn
            row:(NSInteger)rowIndex
{
  id colID = [tableColumn identifier];

  if ([colID isEqual:@"on"])
    return [imOnArray objectAtIndex:rowIndex];
  else if ([colID isEqual:@"name"])
    return [imNameArray objectAtIndex:rowIndex];
  else if ([colID isEqual:@"script"])
    return [imScriptArray objectAtIndex:rowIndex];

  return nil;
}

- (void)tableView:(NSTableView *)tableView
   setObjectValue:(id)object 
   forTableColumn:(NSTableColumn *)tableColumn 
              row:(NSInteger)rowIndex;
{
  id identifier;
  
  identifier = [tableColumn identifier];
  if ([identifier isEqualToString:@"on"]) {
    imModules[rowIndex]->on = [object intValue] ? TRUE : FALSE;
    [imOnArray replaceObjectAtIndex:rowIndex
                         withObject:[[NSNumber alloc] initWithInt:[object intValue]]];
  }
}

- (void)prefSync
{
  CFNotificationCenterRef center;
  CFStringRef im;
  int transVal;
  CFNumberRef trans;
  float fontSizeVal;
  CFNumberRef fontSize;
  CFMutableArrayRef array;
  CFMutableDictionaryRef dict;
  int i;

  dict = CFDictionaryCreateMutable(kCFAllocatorDefault, 10,
                                   NULL, NULL);
    
  // set default input method name
  im = CFStringCreateWithCString(NULL, kDefaultIM,
                                 kCFStringEncodingMacRoman);
  CFPreferencesSetAppValue(CFSTR(kPrefIM), CFSTR(kDefaultIM), appID);

  // set input method name if input method has been selected
  i = [[imButton objectValue] intValue];
  if ([[imButton objectValue] intValue] < numModules) {
    if (imModules && imModules[i]) {
      CFRelease(im);
      im = CFStringCreateWithCString(NULL, imModules[i]->name,
                                     kCFStringEncodingMacRoman);
      CFPreferencesSetAppValue(CFSTR(kPrefIM), im, appID);
    }
  }

  // set the display direction of candidate window (disabled)
#if 0
  if ([listDirection selectedColumn] == 0)
    CFPreferencesSetAppValue(CFSTR(kPrefCandVertical), kCFBooleanTrue, appID);
  else
    CFPreferencesSetAppValue(CFSTR(kPrefCandVertical), kCFBooleanFalse, appID);
#else
  CFPreferencesSetAppValue(CFSTR(kPrefCandVertical), kCFBooleanTrue, appID);
#endif
  
  // set the transparency
  transVal = [opacitySlider intValue];
  trans = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &transVal);
  CFPreferencesSetAppValue(CFSTR(kPrefCandTransparency), trans, appID);
  
  // candidate font
  CFPreferencesSetAppValue(CFSTR(kPrefCandFont), [font fontName], appID);
  fontSizeVal = [font pointSize];
  fontSize = CFNumberCreate(kCFAllocatorDefault, kCFNumberFloatType, &fontSizeVal);
  CFPreferencesSetAppValue(CFSTR(kPrefCandFontSize), fontSize, appID);
  
  // set the modetips flag
  if ([modeTipsButton state] == NSOffState)
    CFPreferencesSetAppValue(CFSTR(kPrefModeTips), kCFBooleanFalse, appID);
  else
    CFPreferencesSetAppValue(CFSTR(kPrefModeTips), kCFBooleanTrue, appID);
  
  // set annotation flag
  if ([annotationButton state] == NSOffState)
    CFPreferencesSetAppValue(CFSTR(kPrefAnnotation), kCFBooleanFalse, appID);
  else
    CFPreferencesSetAppValue(CFSTR(kPrefAnnotation), kCFBooleanTrue, appID);
  
  // set helper-switchable input method list
  array = CFArrayCreateMutable(kCFAllocatorDefault, 100, NULL);
  for (i = 0; i < numModules; i++) {
    if (imModules[i]->on) {
      CFArrayAppendValue(array,
                         CFStringCreateWithCString(NULL, imModules[i]->name,
                                                   kCFStringEncodingMacRoman));
    }
  }
  CFPreferencesSetAppValue(CFSTR(kPrefHelperIM), array, appID);
  
  // write out all the changes
  CFPreferencesAppSynchronize(appID);

  CFDictionarySetValue(dict, CFSTR(kPrefIM), im);
  
#if 0
  if ([listDirection selectedColumn] == 0)
    CFDictionarySetValue(dict, CFSTR(kPrefCandVertical), kCFBooleanTrue);
  else
    CFDictionarySetValue(dict, CFSTR(kPrefCandVertical), kCFBooleanFalse);
#else
  CFDictionarySetValue(dict, CFSTR(kPrefCandVertical), kCFBooleanTrue);
#endif

  CFDictionarySetValue(dict, CFSTR(kPrefCandTransparency), trans);
  
  CFDictionarySetValue(dict, CFSTR(kPrefCandFont), [font fontName]);
  CFDictionarySetValue(dict, CFSTR(kPrefCandFontSize), fontSize);
  
  if ([modeTipsButton state] == NSOnState)
    CFDictionarySetValue(dict, CFSTR(kPrefModeTips), kCFBooleanTrue);
  else
    CFDictionarySetValue(dict, CFSTR(kPrefModeTips), kCFBooleanFalse);
  
  if ([annotationButton state] == NSOnState)
    CFDictionarySetValue(dict, CFSTR(kPrefAnnotation), kCFBooleanTrue);
  else
    CFDictionarySetValue(dict, CFSTR(kPrefAnnotation), kCFBooleanFalse);

  CFDictionarySetValue(dict, CFSTR(kPrefHelperIM), array);
  
  // post a notification that the preferences have changed
  center = CFNotificationCenterGetDistributedCenter();
  CFNotificationCenterPostNotification(center,
                                       CFSTR(kPrefChanged),
                                       appID, dict, TRUE);

  CFRelease(dict);
}

- (void)loadExtra
{
  int sleepCount = 0;
  NSURL *crackerUrl;
  NSURL *helperUrl = [NSURL fileURLWithPath:[[self bundle]
                              pathForResource:@"MacUIMHelper"
                                       ofType:@"menu"
                                  inDirectory:@""]];

  crackerUrl = [NSURL fileURLWithPath:[[self bundle] pathForResource:@"MenuCracker"
			       				      ofType:@"menu"
							 inDirectory:@""]];
  CoreMenuExtraAddMenuExtra((CFURLRef)crackerUrl, 0, 0, 0, 0, 0);

  // Try default MenuCracker installed by user
  CoreMenuExtraAddMenuExtra((CFURLRef)helperUrl, 0, 0, 0, 0, 0);

  while (![self isExtraLoaded:kHelperID]
         && (sleepCount < 2000000)) {
    sleepCount += 250000;
    usleep(250000);
  }

  if (![self isExtraLoaded:kHelperID]) {
    // No load
    CoreMenuExtraAddMenuExtra((CFURLRef)crackerUrl, 0, 0, 0, 0, 0);
    CoreMenuExtraAddMenuExtra((CFURLRef)helperUrl, 0, 0, 0, 0, 0);
    sleepCount = 0;
    while (![self isExtraLoaded:kHelperID]
           && (sleepCount < 2000000)) {
      sleepCount += 250000;
      usleep(250000);
    }
  }

  if (![self isExtraLoaded:kHelperID]) {
    NSLog(@"helperExtra load failed");
  }
}

- (void)removeExtra:(NSString *)extraID
{
  void *extra;

  if ((CoreMenuExtraGetMenuExtra((CFStringRef)extraID, &extra) == 0)
      && extra)
    CoreMenuExtraRemoveMenuExtra(extra, 0);
}

- (BOOL)isExtraLoaded:(NSString *)extraID
{
  void *extra = NULL;

  if (CoreMenuExtraGetMenuExtra((CFStringRef) extraID, &extra) == 0
      && extra)
    return YES;

  return NO;
}

- (int)charArrayToUni:(char *)charArray
               uniStr:(UniCharPtr *)strUni
             encoding:(CFStringEncoding)enc
{
  CFMutableStringRef cfStr;
  int len;

  cfStr = CFStringCreateMutable(NULL, 0);
  if (!cfStr) goto err;

  CFStringAppendCString(cfStr, charArray, enc);
  len = CFStringGetLength(cfStr);

  *strUni = (UniCharPtr) malloc(sizeof(UniChar) * (len + 1));
  if (!(*strUni)) goto err;

  CFStringGetCharacters(cfStr, CFRangeMake(0, len), *strUni);
  CFRelease(cfStr);

  return len;

 err:
  if (cfStr) CFRelease(cfStr);
  return -1;
}

- (void)loadPrefs:(NSString *)im
{
  int i;

  for (i = 0; i < numModules; i++) {
    if ([im isEqualToString:[NSString stringWithCString:imModules[i]->name]]) {
      [imButton selectItemAtIndex:i];
      break;
    }
  }
}

- (void)updateFontSample
{
  NSRect fontFrame, boxFrame;
  NSAttributedString *text;
  NSString *fontName;
  
  fontName = [NSString stringWithFormat:@"%@ %d",
              [font displayName], (int) [font pointSize]];

  [fontSample setFont:font];
  [fontSample setStringValue:fontName];

  fontFrame = [fontSample frame];
  boxFrame = [[fontSample superview] frame];
    
  text = [[[NSAttributedString alloc]
           initWithString:fontName
               attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                 font, NSFontAttributeName, nil]] autorelease];
    
  fontFrame.size.height = [text size].height + 4.0;
  fontFrame.origin.y = (boxFrame.size.height - fontFrame.size.height) / 2.0;
  [fontSample setFrameSize:fontFrame.size];
  [fontSample setFrameOrigin:fontFrame.origin];
  
  [[fontSample superview] setNeedsDisplay:YES];
}

@end

static void
prefChanged(CFNotificationCenterRef inCenter, void *inObserver, 
            CFStringRef inName, const void *inObject, 
            CFDictionaryRef inUserInfo)
{
  NSAutoreleasePool *localPool;
  NSString *im;
  
  im = (NSString *) CFDictionaryGetValue(inUserInfo, CFSTR(kPrefIM));

  localPool = [[NSAutoreleasePool alloc] init];        
  [[MacUIMPrefPane sharedPane] loadPrefs:im];
  [localPool release];
}
