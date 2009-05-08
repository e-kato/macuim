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

//Each input method needs a unique connection name. 
//Note that periods and spaces are not allowed in the connection name.
const NSString *kConnectionName = @"MacUIM_1_Connection";

//let this be a global so our application controller delegate can access it easily
IMKServer *server;

int main(int argc, char *argv[])
{
	NSString *identifier;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSArray *langs = [defs objectForKey:@"AppleLanguages"];
	NSString *lang = [langs objectAtIndex:0];
	NSString *locale = [defs objectForKey:@"AppleLocale"];
	const char *lang_c = [lang UTF8String];

	setenv("LANG", lang_c, 1);
	setlocale(LC_CTYPE, [locale UTF8String]);

	if (uim_init() == -1)
		return 0;

	//find the bundle identifier and then initialize the input method server
	identifier = [[NSBundle mainBundle] bundleIdentifier];
	server = [[IMKServer alloc] initWithName:(NSString*)kConnectionName bundleIdentifier:[[NSBundle mainBundle] bundleIdentifier]];
	
	//load the bundle explicitly because in this case the input method is a background only application 
	[NSBundle loadNibNamed:@"MainMenu" owner:[NSApplication sharedApplication]];
	
	//finally run everything
	[[NSApplication sharedApplication] run];
	
	[pool release];

	uim_quit();

	return 0;
}
