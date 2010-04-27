//
//  AnthyController.m
//  AnthyDict

/*
  Copyright (c) 2006-2010 Etsushi Kato

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

#import "AnthyController.h"
#import "Word.h"
#include "dict-canna-cclass.h"

@implementation AnthyController
- (id)init
{
	if (self = [super init])
		[self dict_init];

	return self;
}

- (void)dict_init
{
	anthy_dic_util_init();
	anthy_dic_util_set_encoding(ANTHY_UTF8_ENCODING);
}

- (void)dict_quit
{
	anthy_dic_util_quit();
}

- (void)dict_read:(NSMutableArray *)anArray
{
	char phon[100], desc[100], cclass_native[100];
	int ret;
	
	if (anthy_priv_dic_select_first_entry() == -1)
		return;
	
	do {
		if (anthy_priv_dic_get_index(phon, sizeof(phon))
		    && anthy_priv_dic_get_wtype(cclass_native,
										sizeof(cclass_native))
			&& anthy_priv_dic_get_word(desc, sizeof(desc))) {
			int pos;
			const char *cclass_code = NULL;
			
			for (pos = 0; pos < NR_POS; pos++) {
				cclass_code = [self findCclassCode:cclass_native:pos];
				if (cclass_code)
					break;
			}
			
			Word *newWord = [[Word alloc] init];
			[newWord setPhon:[[NSString alloc] initWithData:[NSData dataWithBytes:phon length:strlen(phon)] encoding:NSUTF8StringEncoding]];
			[newWord setDesc:[[NSString alloc] initWithData:[NSData dataWithBytes:desc length:strlen(desc)] encoding:NSUTF8StringEncoding]];
			if (cclass_code) {
				[newWord setCclass_code:[NSString stringWithUTF8String:cclass_code]];
			} else {
				[newWord setCclass_code:@"#NONE"];
				[newWord setCclass_native:[NSString stringWithCString:cclass_native]];
			}
			[newWord setFreq:anthy_priv_dic_get_freq()];
			
			[anArray addObject:newWord];
			
			[newWord release];
		}
	} while (anthy_priv_dic_select_next_entry() == 0);
}

- (void)dict_save:(NSMutableArray *)anArray
{
	unsigned n = [anArray count];
	unsigned i;
	Word *word;
	
	anthy_priv_dic_delete(); // delete all entries
	
	for (i = 0; i < n; i++) {
		const char *c_phon;
		const char *c_desc;
		const char *c_cclass_native;
		int freq;
		NSMutableData *data;
		
		word = [anArray objectAtIndex:i];

		freq = [word freq];
		
		data = [[[[word phon] dataUsingEncoding:NSUTF8StringEncoding] mutableCopy] autorelease];
		[data appendBytes:"\0" length:1];
		c_phon = [data bytes];
		
		data = [[[[word desc] dataUsingEncoding:NSUTF8StringEncoding] mutableCopy] autorelease];
		[data appendBytes:"\0" length:1];
		c_desc = [data bytes];

		data = [[[[word cclass_native] dataUsingEncoding:NSASCIIStringEncoding] mutableCopy] autorelease];
		[data appendBytes:"\0" length:1];
		c_cclass_native = [data bytes];
				
		if (freq && [word phon] && [word desc] && [word cclass_native] && !strchr(c_phon, ' '))
			anthy_priv_dic_add_entry(c_phon, c_desc, c_cclass_native, freq);
	}
}

- (const char *)findCclassCode:(const char *)cclass_native:(int)pos
{
	return find_desc_from_code_with_type(cclass_native, pos);
}

- (void)dealloc
{
	[self dict_quit];
	[super dealloc];
}
@end
