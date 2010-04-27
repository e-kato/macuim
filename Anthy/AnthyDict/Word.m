//
//  Word.m
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

#import "Word.h"
#include "dict-canna-cclass.h"


@implementation Word
- (id)init
{
	if (self = [super init]) {
		[self setPhon:NSLocalizedString(@"NewPhonetic", nil)];
		[self setDesc:NSLocalizedString(@"NewLiteral", nil)];
#if 0
		[self setCclass_code:@""];
		[self setCclass_native:@""];
#else
		[self setCclass_code:@"名詞(語幹,格助接続)"];
#endif
		[self setFreq: 100];
	}
	return self;
}

- (NSString *)phon
{
	return phon;
}
- (void)setPhon:(NSString *)s
{
	[s retain];
	[phon release];
	phon = s;
}

- (NSString *)desc
{
	return desc;
}
- (void)setDesc:(NSString *)s
{
	[s retain];
	[desc release];
	desc = s;
}

- (NSString *)cclass_code
{
	return cclass_code;
}
- (void)setCclass_code:(NSString *)s
{
	const char *code = [s UTF8String];
	const char *native;
	int type;
	
	[s retain];
	[cclass_code release];
	cclass_code = s;
	
	// Anthy specific...
	type = find_cclass_type_from_desc(code);
	native = find_code_from_desc(code, type);

	if (!native)
		native = "#NONE";

	//fprintf(stderr, "code %s native %s\n", code, native);
	[self setCclass_native:[NSString stringWithCString:native]];
}

- (NSString *)cclass_native
{
	return cclass_native;
}
- (void)setCclass_native:(NSString *)s
{
	[s retain];
	[cclass_native release];
	cclass_native = s;
}

- (int)freq
{
	return freq;
}
- (void)setFreq:(int)i
{
	freq = i;
}

- (void)dealloc
{
	[phon release];
	[desc release];
	[cclass_code release];
	[super dealloc];
}

- (void)unableToSetNilForKey:(NSString *)key
{
	if ([key isEqual:@"freq"]) {
		[self setFreq:0];
	} else {
		[super unableToSetNilForKey:key];
	}
}

+ (int)ClassTypeCount:(int)type
{
	int nr;

	switch (type) {
	case substantiveClassType:
		nr = nr_substantive_code;
		break;
	case verbClassType:
		nr = nr_verb_code;
		break;
	case adjectiveClassType:
		nr = nr_adjective_code;
		break;
	case adverbClassType:
		nr = nr_adverb_code;
		break;
	case etcClassType:
		nr = nr_etc_code;
		break;
	default:
		nr = 0;
		break;
	}
	return nr;
}

+ (id)ClassCode:(int)type:(int)atIndex
{
	const char *code;
	int nr = [self ClassTypeCount:type];
	category_code *category;

	switch (type) {
	case substantiveClassType:
		category = substantive_code;
		break;
	case verbClassType:
		category = verb_code;
		break;
	case adjectiveClassType:
		category = adjective_code;
		break;
	case adverbClassType:
		category = adverb_code;
		break;
	case etcClassType:
		category = etc_code;
		break;
	default:
		return @"";
	}
	
	if (atIndex < nr)
		code = category[atIndex].desc;
	else
		code = "";
	
	return [NSString stringWithUTF8String:code];
}

+ (int)TypeOfClass:(NSString *)s
{
	const char *code = [s UTF8String];

	return find_cclass_type_from_desc(code);
}

+ (int)ClassIndexOfType:(NSString *)s:(int)type
{
	int nr = [self ClassTypeCount:type];
	category_code *category;
	const char *code = [s UTF8String];
	int i;

	switch (type) {
	case substantiveClassType:
		category = substantive_code;
		break;
	case verbClassType:
		category = verb_code;
		break;
	case adjectiveClassType:
		category = adjective_code;
		break;
	case adverbClassType:
		category = adverb_code;
		break;
	case etcClassType:
		category = etc_code;
		break;
	default:
		return -1;
	}

	for (i = 0; i < nr; i++) {
		if (!strcmp(code, category[i].desc))
			return i;
	}

	return -1;
}

@end
