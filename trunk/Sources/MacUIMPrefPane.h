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

#import <Cocoa/Cocoa.h>
#import <PreferencePanes/PreferencePanes.h>
#import <SystemConfiguration/SystemConfiguration.h>


int
CoreMenuExtraGetMenuExtra(CFStringRef identifier, void *menuExtra);

int
CoreMenuExtraAddMenuExtra(CFURLRef path, int position, int whoCares,
                          int whoCares2, int whoCares3, int whoCares4);

int
CoreMenuExtraRemoveMenuExtra(void *menuExtra, int whoCares);


typedef struct _IMModule {
  int index;
  char *name;
  char *lang;
  bool on;

} IMModule;

@interface MacUIMPrefPane : NSPreferencePane
{
  SCDynamicStoreRef scSession;
  SCDynamicStoreContext scContext;

  IBOutlet NSTabView *tab;
  IBOutlet NSPopUpButton *imButton;
  IBOutlet NSMatrix *listDirection;
  IBOutlet NSButton *modeTipsButton;
  IBOutlet NSButton *appletButton;
  IBOutlet NSTableView *imTable;
  IBOutlet NSSlider *opacitySlider;
  IBOutlet NSTextField *fontSample;
  IBOutlet NSButton *annotationButton;

  CFStringRef appID;

  int numModules;
  IMModule **imModules;

  NSMutableArray *imOnArray;
  NSMutableArray *imNameArray;
  NSMutableArray *imScriptArray;
  
  NSFont *font;
}

- (IBAction)imChange:(id)sender;

- (IBAction)appletChange:(id)sender;

- (IBAction)imSwitchChange:(id)sender;

- (IBAction)imSwitchApply:(id)sender;

- (IBAction)listDirectionChange:(id)sender;

- (IBAction)modeTipsChange:(id)sender;

- (IBAction)opacityChange:(id)sender;

- (IBAction)chooseFont:(id)sender;

- (IBAction)annotationChange:(id)sender;

- (void)changeFont:(id)sender;

- (void)setFont:(id)sender;

- (void)prefSync;

- (void)loadExtra;

- (void)removeExtra:(NSString *)extraID;

- (BOOL)isExtraLoaded:(NSString *)extraID;

- (int)charArrayToUni:(char *)charArray
               uniStr:(UniCharPtr *)strUni
             encoding:(CFStringEncoding)enc;

- (void)loadPrefs:(NSString *)im;

- (void)updateFontSample;

+ (id)sharedPane;

@end
