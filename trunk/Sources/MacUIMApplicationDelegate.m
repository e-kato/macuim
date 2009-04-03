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

#import "MacUIMApplicationDelegate.h"
#import "PreferenceController.h"


@implementation MacUIMApplicationDelegate

- (NSMenu *)menu
{
	return _menu;
}

- (void)awakeFromNib
{
	NSMenuItem *preferences = [_menu itemWithTag:0];
	NSMenuItem *help = [_menu itemWithTag:1];

	if (preferences) {
		[preferences setAction:@selector(openSystemPrefs:)];
	}
	if (help) {
		[help setAction:@selector(openUimHelp:)];
	}

	CFNotificationCenterRef center =
		CFNotificationCenterGetDistributedCenter();

	if (center) {
		CFNotificationCenterAddObserver(center, NULL,
				NotificationCallback, NULL,
				CFSTR(kAppID),
				CFNotificationSuspensionBehaviorCoalesce);
	}

	[GrowlApplicationBridge setGrowlDelegate:self];
}

- (NSDictionary *)registrationDictionaryForGrowl
{
	NSMutableArray *defArray = [NSMutableArray array];
	NSMutableArray *allArray = [NSMutableArray array];

	[allArray addObject:@"uim notify info"];
	[allArray addObject:@"uim notify fatal"];

	[defArray addObject:@"uim notify info"];
	[defArray addObject:@"uim notify fatal"];

	NSDictionary *regDict = [NSDictionary
		dictionaryWithObjectsAndKeys:
			[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"], GROWL_APP_NAME,
			allArray, GROWL_NOTIFICATIONS_ALL,
			defArray, GROWL_NOTIFICATIONS_DEFAULT,
			nil];
	growlAvailable = YES;

	return regDict;
}

- (NSData *)applicationIconDataForGrowl
{

	NSString *iconPath = [[[NSBundle mainBundle] bundlePath]
				stringByAppendingPathComponent:
				@"Contents/Resources/MacUIMPref.tiff"];
	NSImage *image = [[[NSImage alloc]
				initByReferencingFile:iconPath] autorelease];
	NSData *imageData = [image TIFFRepresentation];

	return imageData;
}

- (void)growlIsReady
{
	if (!growlAvailable) {
		[GrowlApplicationBridge setGrowlDelegate:self];
		growlAvailable = YES;
	}
}
@end
