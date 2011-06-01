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

#import <sys/types.h>
#import <sys/socket.h>
#import "MacUIMHelperExtra.h"
#import "Debug.h"
#import "Preference.h"


static MacUIMHelperExtra *sharedExtra;


static void
uimDisconnect();

static void
prefChanged(CFNotificationCenterRef inCenter, void *inObserver, 
            CFStringRef inName, const void *inObject, 
            CFDictionaryRef inUserInfo);

static NSString *
convertHelperString(char *str);

@implementation MacUIMHelperExtra

+ (id)sharedExtra
{
  return sharedExtra;
}

- initWithBundle:(NSBundle *)bundle
{
  self = [super initWithBundle:bundle];
  if (!self)
    return nil;

  sharedExtra = self;

  menu = [[NSMenu alloc] initWithTitle:@""];

  view = [[MacUIMHelperView alloc] initWithFrame:[[self view] frame]
                                   menuExtra:self];
  [self setView:view];

  uimFD = -1;
  [self helperConnect];

  imName = nil;

  branchPoints = [[NSMutableArray alloc] init];
  modes = [[NSMutableArray alloc] init];
  propNames = [[NSMutableArray alloc] init];
  menuItems = [[NSMutableArray alloc] init];

  labels = [[NSMutableArray alloc] init];

  imNames = [[NSMutableArray alloc] init];
  imItems = [[NSMutableArray alloc] init];

  clicked = NO;

  {
    CFNotificationCenterRef center =
      CFNotificationCenterGetDistributedCenter();

    CFNotificationCenterAddObserver(center, (void *)self, prefChanged,
                                    CFSTR(kPrefChanged), CFSTR(kAppID),
                                    CFNotificationSuspensionBehaviorCoalesce);
  }

  [self loadPrefs];
  [self updateMenu];

  return self;
}

- (void)willUnload
{
  [super willUnload];
}

- (void)dealloc
{
  [view release];
  [menu release];

  [self helperDisconnect];

  [branchPoints release];
  [modes release];
  [propNames release];
  [menuItems release];

  [imNames release];
  [imItems release];

  [labels release];

  CFNotificationCenterRef center =
    CFNotificationCenterGetDistributedCenter();
  CFNotificationCenterRemoveObserver(center, (void *)self,
                                     CFSTR(kPrefChanged), CFSTR(kAppID));

  [super dealloc];
}

- (NSImage *)image
{
  return [self createImage:NO];
}

- (NSImage *)alternateImage
{
  return [self createImage:YES];
}

- (NSImage *)createImage:(BOOL)alter
{
  NSImage *image = nil;

  clicked = alter;

  if ([labels count] <= 1) {
    [view setFrameSize:NSMakeSize(kMenuBarWidth, [view frame].size.height)];
    [self setLength:kMenuBarWidth];
    image = [[[NSImage alloc] initWithSize:NSMakeSize(kMenuBarWidth, kMenuBarHeight)]
              autorelease];
  }
  else if ([labels count] == 2) {
    [view setFrameSize:NSMakeSize(kMenuBarWidth2, [view frame].size.height)];
    [self setLength:kMenuBarWidth2];
    image = [[[NSImage alloc] initWithSize:NSMakeSize(kMenuBarWidth2, kMenuBarHeight)]
              autorelease];
  } else {
    [view setFrameSize:NSMakeSize(kMenuBarWidth3, [view frame].size.height)];
    [self setLength:kMenuBarWidth3];
    image = [[[NSImage alloc] initWithSize:NSMakeSize(kMenuBarWidth3, kMenuBarHeight)]
              autorelease];
  }

  [self renderFrame:image];
  [self renderText:image];

  return image;
}

- (void)renderFrame:(NSImage *)image
{
  NSBezierPath *framePath;
  NSColor *strokeColor, *fillColor;

  if (clicked == NO) {
    strokeColor = [NSColor blackColor];
    fillColor = [NSColor colorWithCalibratedRed:0.94
					  green:0.94
					   blue:0.94
					  alpha:0.5];
  }
  else {
    strokeColor = [NSColor blackColor];
    fillColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.0];
  }

  [image lockFocus];

  if ([labels count] <= 1) {
    framePath =
      [NSBezierPath bezierPathWithRect:NSMakeRect(0.5, 3.5,
                                                  kMenuBarWidth - 1.0, kMenuBarHeight - 7.0)];
    [fillColor set];
    [framePath fill];
    [strokeColor set];
    [framePath stroke];
  }
  else if ([labels count] == 2) {
    framePath =
      [NSBezierPath bezierPathWithRect:NSMakeRect(0.5, 3.5,
                                                  kMenuBarWidth2 - 1.0, kMenuBarHeight - 7.0)];
    [fillColor set];
    [framePath fill];
    [strokeColor set];
    [framePath stroke];

    [[NSGraphicsContext currentContext] setShouldAntialias:NO];
    framePath = [NSBezierPath bezierPath];
    [framePath moveToPoint:NSMakePoint(kMenuBarWidth2 / 2.0, 3.5)];
    [framePath lineToPoint:NSMakePoint(kMenuBarWidth2 / 2.0, 3.5 + kMenuBarHeight - 7.0)];
    [strokeColor set];
    [framePath stroke];
    [[NSGraphicsContext currentContext] setShouldAntialias:YES];
  }
  else {
    framePath =
      [NSBezierPath bezierPathWithRect:NSMakeRect(0.5, 3.5,
                                                  kMenuBarWidth3 - 1.0, kMenuBarHeight - 7.0)];
    [fillColor set];
    [framePath fill];
    [strokeColor set];
    [framePath stroke];

    [[NSGraphicsContext currentContext] setShouldAntialias:NO];
    framePath = [NSBezierPath bezierPath];
    [framePath moveToPoint:NSMakePoint(kMenuBarWidth3 / 3.0, 3.5)];
    [framePath lineToPoint:NSMakePoint(kMenuBarWidth3 / 3.0, 3.5 + kMenuBarHeight - 7.0)];
    [strokeColor set];
    [framePath stroke];

    framePath = [NSBezierPath bezierPath];
    [framePath moveToPoint:NSMakePoint(kMenuBarWidth3 * 2.0 / 3.0, 3.5)];
    [framePath lineToPoint:NSMakePoint(kMenuBarWidth3 * 2.0 / 3.0, 3.5 + kMenuBarHeight - 7.0)];
    [strokeColor set];
    [framePath stroke];
    [[NSGraphicsContext currentContext] setShouldAntialias:YES];
  }

  [image unlockFocus];
}

- (void)renderText:(NSImage *)image
{
  NSMutableAttributedString *text;
  NSMutableString *label = nil;
  NSColor *color;
  int i;

  if (clicked == NO)
    color = [NSColor blackColor];
  else
    color = [NSColor whiteColor];

  [image lockFocus];

  [[NSGraphicsContext currentContext] setShouldAntialias:YES];

  if ([labels count] < 1)
    label = [[NSMutableString alloc] initWithString:@"?"];

  i = 0;
  do {
    if (!label)
      label = [[NSMutableString alloc] initWithString:[labels objectAtIndex:i]];

    if ([labels count] <= 1) {
      text = [[NSAttributedString alloc] initWithString:label
                                         attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                    [NSFont boldSystemFontOfSize:12],
                                                                  NSFontAttributeName,
                                                                  color,
                                                                  NSForegroundColorAttributeName,
                                                                  nil]];
      [text drawAtPoint:NSMakePoint(0.5 + 0.5 +
                                    (kMenuBarWidth - 1.0 -
                                     ceil([text size].width + 0.5)) / 2.0,
                                    (kMenuBarHeight - ceil([text size].height)) / 2.0)];
    }
    else if ([labels count] == 2) {
      text = [[NSAttributedString alloc] initWithString:label
                                         attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                    [NSFont boldSystemFontOfSize:11],
                                                                  NSFontAttributeName,
                                                                  color,
                                                                  NSForegroundColorAttributeName,
                                                                  nil]];
      [text drawAtPoint:NSMakePoint(0.5 + 0.5 +
                                    (i > 0 ? (kMenuBarWidth2 - 1.0) / 2.0 : 0)
                                    + (kMenuBarWidth2 / 2.0 - 0.5 -
                                     ceil([text size].width + 0.5)) / 2.0,
                                    (kMenuBarHeight - ceil([text size].height)) / 2.0)];
    }
    else {
      text = [[NSAttributedString alloc] initWithString:label
                                         attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                    [NSFont boldSystemFontOfSize:11],
                                                                  NSFontAttributeName,
                                                                  color,
                                                                  NSForegroundColorAttributeName,
                                                                  nil]];
      if (i == 0) {
        [text drawAtPoint:NSMakePoint(0.5 + 0.5 +
                                    0 + (kMenuBarWidth3 / 3.0 - 0.5 -
                                     ceil([text size].width + 0.5)) / 2.0,
                                    (kMenuBarHeight - ceil([text size].height)) / 2.0)];

      }
      else if (i == 1) {
        [text drawAtPoint:NSMakePoint(0.5 + 0.5 +
                                    kMenuBarWidth3 / 3.0
                                    + (kMenuBarWidth3 / 3.0 - 0.5 -
                                     ceil([text size].width + 0.5)) / 2.0,
                                    (kMenuBarHeight - ceil([text size].height)) / 2.0)];

      }
      else if (i == 2) {
        [text drawAtPoint:NSMakePoint(0.5 + 0.5 +
                                    kMenuBarWidth3 * 2.0 / 3.0
                                    + (kMenuBarWidth3 / 3.0 - 0.5 -
                                     ceil([text size].width + 0.5)) / 2.0,
                                    (kMenuBarHeight - ceil([text size].height)) / 2.0)];

      }
    }

    [text release];
    [label release];
    label = nil;

  } while (++i < [labels count]);

  [image unlockFocus];
}

- (NSMenu *)menu
{
  return menu;
}

- (void)updateMenu
{
  int i, j;

  if ([menu numberOfItems] > 0) {
    while ([menu numberOfItems])
      [menu removeItemAtIndex:0];
  }

  [menuItems removeAllObjects];
  [imItems removeAllObjects];

  for (i = 0; i < [modes count]; i++) {
    NSString *mode;
    NSMenuItem *menuItem;

    for (j = 0; j < [branchPoints count]; j++) {
      if (i == [[branchPoints objectAtIndex:j] intValue]) {
        if (i != 0)
          [menu addItem:[NSMenuItem separatorItem]];
        break;
      }
    }

    mode = [modes objectAtIndex:i];
    menuItem = (NSMenuItem *)
      [menu addItemWithTitle:mode
                      action:@selector(modeSelect:)
                keyEquivalent:@""];
    [menuItem setTarget:self];
    [menuItems addObject:menuItem];
  }

  [menu addItem:[NSMenuItem separatorItem]];

  [[menu addItemWithTitle:@"Input Method:"
         action:nil keyEquivalent:@""] setEnabled:NO];

  for (i = 0; i < [imNames count]; i++) {
    NSMenuItem *menuItem;
    menuItem = (NSMenuItem *)
      [menu addItemWithTitle:[NSString stringWithFormat:@"    %@", [imNames objectAtIndex:i]]
                      action:@selector(imSelect:) keyEquivalent:@""];
    [menuItem setTarget:self];
    if (imName && [imName compare:[imNames objectAtIndex:i]] == NSOrderedSame)
      [menuItem setState:NSOnState];
    [imItems addObject:menuItem];
  }

  [menu addItem:[NSMenuItem separatorItem]];
  
  [[menu addItemWithTitle:@"Preferences..."
         action:@selector(openSystemPrefs:) keyEquivalent:@""]
    setTarget:self];
}

- (void)modeSelect:(id)sender
{
  int i;

  for (i = 0; i < [menuItems count]; i++) {
    if (sender == [menuItems objectAtIndex:i]) {
      NSMutableString *msg = [[NSMutableString alloc] initWithString:@"prop_activate\n"];
      [msg appendString:[NSString stringWithString:[propNames objectAtIndex:i]]];
      [msg appendString:@"\n"];
      uim_helper_send_message(uimFD, [msg UTF8String]);
      [msg release];
      break;
    }
  }
}

- (void)imSelect:(id)sender
{
  int i;

  for (i = 0; i < [imItems count]; i++) {
    if (sender == [imItems objectAtIndex:i]) {
      CFNotificationCenterRef center;
      CFMutableDictionaryRef dict;
      NSString *im;
      int j;
      CFMutableArrayRef array;

      im = [imNames objectAtIndex:i];
      CFPreferencesSetAppValue(CFSTR(kPrefIM), im, CFSTR(kAppID));

      array = CFArrayCreateMutable(kCFAllocatorDefault, 100, NULL);
      for (j = 0; j < [imNames count]; j++)
        CFArrayAppendValue(array, [imNames objectAtIndex:j]);
      CFPreferencesSetAppValue(CFSTR(kPrefHelperIM), array, CFSTR(kAppID));

      CFPreferencesAppSynchronize(CFSTR(kAppID));

      dict = CFDictionaryCreateMutable(kCFAllocatorDefault, 10,
                                       NULL, NULL);

      CFDictionarySetValue(dict, CFSTR(kPrefIM), im);
      CFDictionarySetValue(dict, CFSTR(kPrefHelperIM), array);

      center = CFNotificationCenterGetDistributedCenter();
      CFNotificationCenterPostNotification(center,
                                           CFSTR(kPrefChanged),
                                           CFSTR(kAppID),
                                           dict, TRUE);
      break;
    }
  }
}

- (void)openSystemPrefs:(id)sender
{
  [NSTask launchedTaskWithLaunchPath:@"/usr/bin/open"
          arguments:[NSArray arrayWithObject:@"/Library/PreferencePanes/MacUIM.prefPane"]];
}

- (int)helperConnect
{
  if (uimFD >= 0)
    return uimFD;

  NSNotificationCenter *noc = [NSNotificationCenter defaultCenter];

  uimFD = uim_helper_init_client_fd(uimDisconnect);
  if (uimFD >= 0)
  {
    uimHandle = [[NSFileHandle alloc]
                  initWithFileDescriptor:uimFD
                 ];

    [uimHandle waitForDataInBackgroundAndNotify];

    [noc addObserver:self
         selector:@selector(helperRead:)
         name:@"NSFileHandleDataAvailableNotification"
         object:uimHandle];
  }

  return uimFD;
}

- (void)helperRead:(NSNotification *)notification
{
  char *tmp;

  uim_helper_read_proc(uimFD);
  while ((tmp = uim_helper_get_message())) {
#if DEBUG_HELPER_EXTRA
    fprintf(stderr, "MacUIMHelperExtra::helperRead() tmp='%s'\n", tmp);
#endif
    [self helperParse:tmp];
    free(tmp);
  }

  if (uimFD >= 0)
    [uimHandle waitForDataInBackgroundAndNotify];
  else {
    // disconnected
#if DEBUG_HELPER_EXTRA
    fprintf(stderr, "MacUIMHelperExtra::helperRead() disconnected\n");
#endif
    [self helperDisconnect];
    [self helperConnect];
  }
}

- (void)helperParse:(char *)str
{
  NSString *nsstr;
  NSArray *array;

  if (!str || strlen(str) == 0)
    return;

  nsstr = convertHelperString(str);

  if (nsstr) {
    array = [nsstr componentsSeparatedByString:@"\n"];
    if (array && [array count] > 0) {
      NSString *first = [array objectAtIndex:0];
      if (first) {
        if ([first compare:@"prop_list_update"
                   options:NSCaseInsensitiveSearch
                   range:NSMakeRange(0, strlen("prop_list_update"))]
            == NSOrderedSame) {
          [self propListUpdate:array];
        }
        else if ([first compare:@"prop_label_update"
                        options:NSCaseInsensitiveSearch
                        range:NSMakeRange(0, strlen("prop_label_update"))]
                 == NSOrderedSame) {
          [self propLabelUpdate:array];
        }
        else if ([first compare:@"focus_in"
                        options:NSCaseInsensitiveSearch
                        range:NSMakeRange(0, strlen("focus_in"))]
                 == NSOrderedSame) {
        }
        else if ([first compare:@"focus_out"
                        options:NSCaseInsensitiveSearch
                        range:NSMakeRange(0, strlen("focus_out"))]
                 == NSOrderedSame) {
        }
#if DEBUG_HELPER_EXTRA
        else {
          fprintf(stderr, "MacUIMHelperExtra::helperParse() unknown string '%s'\n",
                 [first cString]);
        }
#endif
      }
    }
    [nsstr release];
  }
}

- (void)helperClose
{
  if (uimFD >= 0)
    uim_helper_close_client_fd(uimFD);
}

- (void)helperDisconnect
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [uimHandle release];
  uimHandle = nil;

  uimFD = -1;
}

- (void)propListUpdate:(NSArray *)lines
{
  int i;
  NSString *line;
  NSArray *cols;
  NSString *col;
  BOOL new = NO;
  int pos = 0;

  if (!lines || [lines count] < 2)
    return;

  [labels removeAllObjects];
  [branchPoints removeAllObjects];
  [modes removeAllObjects];
  [propNames removeAllObjects];

  for (i = 2; i < [lines count]; i++) {
    line = [lines objectAtIndex:i];
    if (!line || [line compare:@""] == NSOrderedSame)
      break;

    cols = [line componentsSeparatedByString:@"\t"];

    if (cols && [cols count] >= 3) {
      col = [cols objectAtIndex:0];
      if ([col compare:@"branch"] == NSOrderedSame) {
        NSMutableString *branch =
          [[NSMutableString alloc] initWithString:[cols objectAtIndex:2]];
        [labels addObject:branch];
        new = YES;
      }
      else if ([col compare:@"leaf"] == NSOrderedSame) {
        NSMutableString *mode = 
          [[NSMutableString alloc] initWithString:[cols objectAtIndex:3]];
        NSMutableString *prop =
          [[NSMutableString alloc] initWithString:[cols objectAtIndex:5]];
        
        // disable uim's IM-switch
        if ([prop compare:@"action_imsw_"
                   options:NSLiteralSearch
                     range:NSMakeRange(0, strlen("action_imsw_"))]
            == NSOrderedSame) {
          [mode release];
          [prop release];
          new = NO;
        }
        else {
          [modes addObject:mode];
          [propNames addObject:prop];
          if (new == YES)
            [branchPoints addObject:[NSNumber numberWithInt:pos]];
          new = NO;
          pos++;
        }
      }
    }
  }

  [self updateMenu];
  [view setNeedsDisplay:YES];
}

- (void)propLabelUpdate:(NSArray *)lines
{
  int i;
  NSString *line;
  NSArray *cols;
  NSString *charset = nil;

  if (!lines || [lines count] < 2)
    return;

  line = [lines objectAtIndex:1];

  cols = [line componentsSeparatedByString:@"="];
  if (!cols || [cols count] < 2)
    return;

  charset = [cols objectAtIndex:1];

  [labels removeAllObjects];

  for (i = 2; i < [lines count]; i++) {
    line = [lines objectAtIndex:i];
    if (!line || [line compare:@""] == NSOrderedSame)
      break;

    cols = [line componentsSeparatedByString:@"\t"];
    if (cols && [cols count] >= 2) {
      NSMutableString *label = [[NSMutableString alloc]
                                 initWithString:[cols objectAtIndex:0]];
#if DEBUG_HELPER_EXTRA
      fprintf(stderr, "propLabelUpdate: label='%s'\n", [label UTF8String]);
#endif
      [labels addObject:label];
    }
  }

  [view setNeedsDisplay:YES];
}

- (void)loadPrefs
{
  CFPropertyListRef propVal;
  NSArray *array;
  NSString *im;
  int i;
  
  CFPreferencesAppSynchronize(CFSTR(kAppID));

  propVal = CFPreferencesCopyAppValue(CFSTR(kPrefIM), CFSTR(kAppID));
  if (!propVal)
    return;
  if (CFGetTypeID(propVal) != CFStringGetTypeID()) {
    CFRelease(propVal);
    return;
  }

  if (imName) [imName release];

  imName = (NSString *) propVal;

  propVal = CFPreferencesCopyAppValue(CFSTR(kPrefHelperIM), CFSTR(kAppID));
  if (!propVal)
    return;
  if (CFGetTypeID(propVal) != CFArrayGetTypeID()) {
    CFRelease(propVal);
    return;
  }
  
  array = (NSArray *) propVal;
  
  [imNames removeAllObjects];
  for (i = 0; i < [array count]; i++) {
    im = [array objectAtIndex:i];
    [imNames addObject:im];
  }
  CFRelease(propVal);
  
  [self updateMenu]; 
  [view setNeedsDisplay:YES];
}

@end

static void
uimDisconnect()
{
  NSAutoreleasePool *localPool;

  localPool = [[NSAutoreleasePool alloc] init];        
  [[MacUIMHelperExtra sharedExtra] helperDisconnect];
  [localPool release];
}

static void
prefChanged(CFNotificationCenterRef inCenter, void *inObserver, 
            CFStringRef inName, const void *inObject, 
            CFDictionaryRef inUserInfo)
{
  NSAutoreleasePool *localPool;
  
  localPool = [[NSAutoreleasePool alloc] init];        
  [[MacUIMHelperExtra sharedExtra] loadPrefs];
  [localPool release];
}

static NSString *
convertHelperString(char *str)
{
  char *line, *tmp;
  char *charset = NULL;
  NSString *convstr;

  line = strdup(str);
  if (tmp = strstr(line, "charset=")) {
    tmp += 8;
    charset = strtok(tmp, "\n");
  }
  
  if (charset && (strncmp(charset, "UTF-8", 5) != 0)) {
    CFStringRef name;
    CFStringEncoding cfencoding;
    UInt32 nsencoding;
    NSData *data;

    name = CFStringCreateWithCString(NULL, charset, kCFStringEncodingMacRoman);
    cfencoding = CFStringConvertIANACharSetNameToEncoding(name);
    CFRelease(name);
    nsencoding = CFStringConvertEncodingToNSStringEncoding(cfencoding);

    data = [NSData dataWithBytes:str length:strlen(str)];
    convstr = [[NSString alloc] initWithData:data encoding:nsencoding];
  } else {
    convstr = [[NSString alloc] initWithUTF8String:str];
  }
  free(line);

  return convstr;
}
