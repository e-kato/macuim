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
#import "UimHelperController.h"

static UimHelperController *sharedController;

static void helperRead(CFSocketRef sock, CFSocketCallBackType callbackType,
		       CFDataRef address, const void *data, void *info)
{
	[sharedController helperRead:(CFSocketRef)sock];
}

static void helperDisconnect()
{
	[sharedController helperDisconnect];
}

@implementation UimHelperController

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

	uimRun = NULL;
	uimSock = NULL;
	uimFD = -1;
	isMacUIMfocused = YES;

	return self;
}

- (void)dealloc
{
	sharedController = nil;
	[super dealloc];
}

- (void)checkHelperConnection
{
	if (uimFD != -1)
		return; /* already connected */

	uimFD = uim_helper_init_client_fd(helperDisconnect);
	if (uimFD == -1)
		return;

	if (!uimSock) {
		CFSocketContext sockContext;

		sockContext.version = 0;
		sockContext.info = NULL;
		sockContext.retain = NULL;
		sockContext.release = NULL;
		sockContext.copyDescription = NULL;

		uimSock = CFSocketCreateWithNative(kCFAllocatorDefault,
			  uimFD,
			  kCFSocketReadCallBack,
			  helperRead,
			  &sockContext);

		if (!uimSock)
			return;

	}

	if (!uimRun) {
		uimRun = CFSocketCreateRunLoopSource(kCFAllocatorDefault,
						     uimSock, 0);
		if (!uimRun) {
			CFRelease(uimSock);
			uimSock = NULL;
			return;
		}
		CFRunLoopAddSource(CFRunLoopGetCurrent(), uimRun,
				   kCFRunLoopDefaultMode);
	}
}

- (void)helperRead:(CFSocketRef)sock;
{
	char *msg;
	
	uim_helper_read_proc(CFSocketGetNative(sock));
	while ((msg = uim_helper_get_message())) {
		[self parseHelperString:msg];
		free(msg);
	}
}

- (void)parseHelperString:(const char *)str
{
	MacUIMController *activeContext;
  
	activeContext = [MacUIMController activeContext];

	if (strncmp("im_change", str, 9) == 0) {
		[self parseIMChangeString:str];
  	} else if (strncmp("prop_update_custom", str, 18) == 0) {
		CFMutableStringRef cfstr;
		CFArrayRef array;
		CFIndex count;
		
		cfstr = CFStringCreateMutable(NULL, 0);
		CFStringAppendCString(cfstr, str, kCFStringEncodingUTF8);
		
		array = CFStringCreateArrayBySeparatingStrings(kCFAllocatorDefault, cfstr, CFSTR("\n"));

		if (array && (count = CFArrayGetCount(array)) >= 3) {
			CFStringRef second = CFArrayGetValueAtIndex(array, 1);
			CFStringRef third = CFArrayGetValueAtIndex(array, 2);
			if (second && third) {
				int custom_len_max = CFStringGetMaximumSizeForEncoding(CFStringGetLength(second), kCFStringEncodingUTF8);
				int val_len_max = CFStringGetMaximumSizeForEncoding(CFStringGetLength(third), kCFStringEncodingUTF8);
				char custom[custom_len_max];
				char val[val_len_max];

				CFStringGetCString(second, custom,
						   custom_len_max,
						   kCFStringEncodingUTF8);
				CFStringGetCString(third, val,
						   val_len_max,
						   kCFStringEncodingUTF8);
				[MacUIMController updateCustom:custom:val];
			}
		}
		CFRelease(array);
		CFRelease(cfstr);
	} else if (strncmp("custom_reload_notify", str, 20) == 0) {
		uim_prop_reload_configs();
	} else if (isMacUIMfocused) {
		if (strncmp("prop_list_get", str, 13) == 0) {
			uim_prop_list_update([activeContext uc]);
		} else if (strncmp("prop_activate", str, 13) == 0) {
			CFMutableStringRef cfstr;
			CFArrayRef array;
		
			cfstr = CFStringCreateMutable(NULL, 0);
			CFStringAppendCString(cfstr, str, kCFStringEncodingUTF8);
			//NSLog(@"prop_activate: %@", (NSString *)cfstr);

			array = CFStringCreateArrayBySeparatingStrings(kCFAllocatorDefault, cfstr, CFSTR("\n"));
		
			if (array && (CFArrayGetCount(array) >= 2)) {
				CFStringRef second;
				second = CFArrayGetValueAtIndex(array, 1);     
				if (second) {
					int max = CFStringGetMaximumSizeForEncoding(CFStringGetLength(second), kCFStringEncodingUTF8);
					char how[max];
					CFStringGetCString(second, how, max,
							   kCFStringEncodingUTF8);
				        //BlockUpdatePreedit();
					//NSLog(@"call uim_prop_activate %@", (NSString *)second);
					uim_prop_activate([activeContext uc], how);
					//UnblockUpdatePreedit();
				}
			}
			CFRelease(array);
			CFRelease(cfstr);
  		} else if (strncmp("focus_in", str, 8) == 0) {
			isMacUIMfocused = NO;
		}
	}
}

// just do whole IM switch in MacUIM
- (void)parseIMChangeString:(const char *)str
{
	char *eol, *im;

	eol = strchr(str, '\n');
	if (eol == NULL)
		return;
	im = eol + 1;
	eol = strchr(im, '\n');
	if (eol == NULL)
		return;
	*eol = '\0';
	
	[MacUIMController switchIM:im];
}

- (void)helperDisconnect
{
	NSLog(@"helperDisconnect");
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), uimRun,
			kCFRunLoopDefaultMode);
	CFRelease(uimRun);
	CFRelease(uimSock);

	uimRun = NULL;
	uimSock = NULL;
	uimFD = -1;
}

- (void)focusIn:(uim_context)uc
{
	uim_helper_client_focus_in(uc);
	isMacUIMfocused = YES;
}

- (void)focusOut:(uim_context)uc
{
	uim_helper_client_focus_out(uc);
}

- (void)send:(const char *)string
{
	uim_helper_send_message(uimFD, string);
}

@end
