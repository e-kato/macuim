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

  THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
  SUCH DAMAGE.
*/

#define thng_RezTemplateVersion 1

#include <Carbon/Carbon.r>

#ifdef ppc_YES
  #define TARGET_REZ_MAC_PPC		1
#endif
 
#ifdef i386_YES
  #define TARGET_REZ_MAC_X86		1
#endif
 
#if !defined(TARGET_REZ_MAC_X86)
  #define TARGET_REZ_MAC_X86		0
#endif
 
#if !(TARGET_REZ_MAC_PPC || TARGET_REZ_MAC_X86)
  #if TARGET_CPU_X86
    #undef TARGET_REZ_MAC_X86
    #define TARGET_REZ_MAC_X86		1
  #elif TARGET_CPU_PPC
    #undef TARGET_REZ_MAC_PPC
    #define TARGET_REZ_MAC_PPC		1
  #endif
#endif
 
#if TARGET_REZ_MAC_PPC && TARGET_REZ_MAC_X86
  #define TARGET_REZ_UNIVERSAL_COMPONENTS
  #define Target_PlatformType		platformPowerPCNativeEntryPoint
  #define Target_SecondPlatformType	platformIA32NativeEntryPoint
#elif TARGET_REZ_MAC_X86
  #define Target_PlatformType		platformIA32NativeEntryPoint
#else
  #define Target_PlatformType		platformPowerPCNativeEntryPoint
#endif

#define	kMacUIMBaseResourceID	16384
#define kMacUIMComponentFlags	0x8000 + smJapanese * 0x100 + langJapanese

resource 'thng' (kMacUIMBaseResourceID) {
    'tsvc',			// type
    'inpm',			// subtype
    'muim',			// manufacturer
    0,				// component flags
    0,				// component flags mask
    0,				// code type
    0,				// code ID
    'STR ',			// name type
    kMacUIMBaseResourceID,	// name ID
    'STR ',			// info type
    kMacUIMBaseResourceID + 1,	// info ID
    'kcs8',			// icon type
    kMacUIMBaseResourceID,	// icon ID
    0x00010000,			// version
    componentHasMultiplePlatforms, // registration flags
    0,				// resource ID of icon family
    {				// component platform information
	kMacUIMComponentFlags,
	'dlle',
	kMacUIMBaseResourceID,
	Target_PlatformType,
#ifdef TARGET_REZ_UNIVERSAL_COMPONENTS
	kMacUIMComponentFlags,
	'dlle',
	kMacUIMBaseResourceID,
	Target_SecondPlatformType
#endif
    };
};

resource 'dlle' (kMacUIMBaseResourceID) {
	"MUIMComponentDispatch"
};

/*  Pencil Icon Resources - These resources define the icon that is used as our pencil
    menu title. */

data 'ics#' (kMacUIMBaseResourceID) {
	$"FFFF FFFF FFFF C183 C103 E3C7 F3E7 E3E7"
	$"E3C7 E7C7 E78F E003 E003 F9FF FFFF FFFF"
	$"FFFF FFFF FFFF FFFF FFFF FFFF FFFF FFFF"
	$"FFFF FFFF FFFF FFFF FFFF FFFF FFFF FFFF"
};

data 'ics4' (kMacUIMBaseResourceID) {
	$"AAAA AAAA AAAA AAAA AAAA AAAA AAAA AAAA"
	$"AAAA AAAA AAAA AAAA AADC CCDF ECCC CCAA"
	$"AE00 00DF D000 0DFA AEDD 00EA EDD0 0DAA"
	$"AAFD 00EA AFE0 0EAA AAFC 0CAA AAD0 0AAA"
	$"AAAC 0DFA AFC0 CFAA AAE0 0EAA AAC0 DFAA"
	$"AAE0 0EFA EC00 DAAA AAE0 00CC 0000 0CAA"
	$"AAAC 0000 0000 0CAA AAAA DDDD EEEE EAAA"
	$"AAAA AFFA AAAA AAAA AAAA AAAA AAAA AAAA"
};

data 'ics8' (kMacUIMBaseResourceID) {
	$"FDFD FDFD FDFD FDFD FDFD FDFD FDFD FDFD"
	$"FDFD FDFD FDFD FDFD FDFD FDFD FDFD FDFD"
	$"FDFD FDFD FDFD FDFD FDFD FDFD FDFD FDFD"
	$"FDFD 56F6 F6F6 56FE ACF7 F6F6 F6F7 FDFD"
	$"FDFB 0000 0000 F9FE 5600 0000 0056 FEFD"
	$"FDAC 8156 0000 FBFD FCFA F900 0081 FDFD"
	$"FDFD FE81 0000 ACFD FDFE AC00 00FC FDFD"
	$"FDFD FEF8 00F6 FDFD FDFD 8100 F5FD FDFD"
	$"FDFD FDF6 0056 FEFD FDFE F800 F7FE FDFD"
	$"FDFD AC00 00FB FDFD FDFD F600 56FE FDFD"
	$"FDFD FB00 00FC FEFD FCF7 0000 FAFD FDFD"
	$"FDFD FB00 00F5 2BF6 0000 0000 00F6 FDFD"
	$"FDFD FDF7 0000 0000 00F5 0000 00F7 FDFD"
	$"FDFD FDFD 8156 56FA FCAC FCFB FCFD FDFD"
	$"FDFD FDFD FDFE FEFD FDFD FDFD FDFD FDFD"
	$"FDFD FDFD FDFD FDFD FDFD FDFD FDFD FDFD"
};

data 'ics#' (kMacUIMBaseResourceID + 1) {
	$"FFFF FFFF FFFF C183 C103 E3C7 F3E7 E3E7"
	$"E3C7 E7C7 E78F E003 E003 F9FF FFFF FFFF"
	$"FFFF FFFF FFFF FFFF FFFF FFFF FFFF FFFF"
	$"FFFF FFFF FFFF FFFF FFFF FFFF FFFF FFFF"
};

data 'ics4' (kMacUIMBaseResourceID + 1) {
	$"AAAA AAAA AAAA AAAA AAAA AAAA AAAA AAAA"
	$"AAAA AAAA AAAA AAAA AADC CCDF ECCC CCAA"
	$"AE00 00DF D000 0DFA AEDD 00EA EDD0 0DAA"
	$"AAFD 00EA AFE0 0EAA AAFC 0CAA AAD0 0AAA"
	$"AAAC 0DFA AFC0 CFAA AAE0 0EAA AAC0 DFAA"
	$"AAE0 0EFA EC00 DAAA AAE0 00CC 0000 0CAA"
	$"AAAC 0000 0000 0CAA AAAA DDDD EEEE EAAA"
	$"AAAA AFFA AAAA AAAA AAAA AAAA AAAA AAAA"
};

data 'ics8' (kMacUIMBaseResourceID + 1) {
	$"FDFD FDFD FDFD FDFD FDFD FDFD FDFD FDFD"
	$"FDFD FDFD FDFD FDFD FDFD FDFD FDFD FDFD"
	$"FDFD FDFD FDFD FDFD FDFD FDFD FDFD FDFD"
	$"FDFD 56F6 F6F6 56FE ACF7 F6F6 F6F7 FDFD"
	$"FDFB 0000 0000 F9FE 5600 0000 0056 FEFD"
	$"FDAC 8156 0000 FBFD FCFA F900 0081 FDFD"
	$"FDFD FE81 0000 ACFD FDFE AC00 00FC FDFD"
	$"FDFD FEF8 00F6 FDFD FDFD 8100 F5FD FDFD"
	$"FDFD FDF6 0056 FEFD FDFE F800 F7FE FDFD"
	$"FDFD AC00 00FB FDFD FDFD F600 56FE FDFD"
	$"FDFD FB00 00FC FEFD FCF7 0000 FAFD FDFD"
	$"FDFD FB00 00F5 2BF6 0000 0000 00F6 FDFD"
	$"FDFD FDF7 0000 0000 00F5 0000 00F7 FDFD"
	$"FDFD FDFD 8156 56FA FCAC FCFB FCFD FDFD"
	$"FDFD FDFD FDFE FEFD FDFD FDFD FDFD FDFD"
	$"FDFD FDFD FDFD FDFD FDFD FDFD FDFD FDFD"
};

data 'ics#' (kMacUIMBaseResourceID + 2) {
	$"FFFF FFFF FFFF C183 C103 E3C7 F3E7 E3E7"
	$"E3C7 E7C7 E78F E003 E003 F9FF FFFF FFFF"
	$"FFFF FFFF FFFF FFFF FFFF FFFF FFFF FFFF"
	$"FFFF FFFF FFFF FFFF FFFF FFFF FFFF FFFF"
};

data 'ics4' (kMacUIMBaseResourceID + 2) {
	$"AAAA AAAA AAAA AAAA AAAA AAAA AAAA AAAA"
	$"AAAA AAAA AAAA AAAA AADC CCDF ECCC CCAA"
	$"AE00 00DF D000 0DFA AEDD 00EA EDD0 0DAA"
	$"AAFD 00EA AFE0 0EAA AAFC 0CAA AAD0 0AAA"
	$"AAAC 0DFA AFC0 CFAA AAE0 0EAA AAC0 DFAA"
	$"AAE0 0EFA EC00 DAAA AAE0 00CC 0000 0CAA"
	$"AAAC 0000 0000 0CAA AAAA DDDD EEEE EAAA"
	$"AAAA AFFA AAAA AAAA AAAA AAAA AAAA AAAA"
};

data 'ics8' (kMacUIMBaseResourceID+ 2) {
	$"FDFD FDFD FDFD FDFD FDFD FDFD FDFD FDFD"
	$"FDFD FDFD FDFD FDFD FDFD FDFD FDFD FDFD"
	$"FDFD FDFD FDFD FDFD FDFD FDFD FDFD FDFD"
	$"FDFD 56F6 F6F6 56FE ACF7 F6F6 F6F7 FDFD"
	$"FDFB 0000 0000 F9FE 5600 0000 0056 FEFD"
	$"FDAC 8156 0000 FBFD FCFA F900 0081 FDFD"
	$"FDFD FE81 0000 ACFD FDFE AC00 00FC FDFD"
	$"FDFD FEF8 00F6 FDFD FDFD 8100 F5FD FDFD"
	$"FDFD FDF6 0056 FEFD FDFE F800 F7FE FDFD"
	$"FDFD AC00 00FB FDFD FDFD F600 56FE FDFD"
	$"FDFD FB00 00FC FEFD FCF7 0000 FAFD FDFD"
	$"FDFD FB00 00F5 2BF6 0000 0000 00F6 FDFD"
	$"FDFD FDF7 0000 0000 00F5 0000 00F7 FDFD"
	$"FDFD FDFD 8156 56FA FCAC FCFB FCFD FDFD"
	$"FDFD FDFD FDFE FEFD FDFD FDFD FDFD FDFD"
	$"FDFD FDFD FDFD FDFD FDFD FDFD FDFD FDFD"
};

data 'ics#' (kMacUIMBaseResourceID + 3) {
	$"FFFF FFFF FFFF C183 C103 E3C7 F3E7 E3E7"
	$"E3C7 E7C7 E78F E003 E003 F9FF FFFF FFFF"
	$"FFFF FFFF FFFF FFFF FFFF FFFF FFFF FFFF"
	$"FFFF FFFF FFFF FFFF FFFF FFFF FFFF FFFF"
};

data 'ics4' (kMacUIMBaseResourceID + 3) {
	$"AAAA AAAA AAAA AAAA AAAA AAAA AAAA AAAA"
	$"AAAA AAAA AAAA AAAA AADC CCDF ECCC CCAA"
	$"AE00 00DF D000 0DFA AEDD 00EA EDD0 0DAA"
	$"AAFD 00EA AFE0 0EAA AAFC 0CAA AAD0 0AAA"
	$"AAAC 0DFA AFC0 CFAA AAE0 0EAA AAC0 DFAA"
	$"AAE0 0EFA EC00 DAAA AAE0 00CC 0000 0CAA"
	$"AAAC 0000 0000 0CAA AAAA DDDD EEEE EAAA"
	$"AAAA AFFA AAAA AAAA AAAA AAAA AAAA AAAA"
};

data 'ics8' (kMacUIMBaseResourceID + 3) {
	$"FDFD FDFD FDFD FDFD FDFD FDFD FDFD FDFD"
	$"FDFD FDFD FDFD FDFD FDFD FDFD FDFD FDFD"
	$"FDFD FDFD FDFD FDFD FDFD FDFD FDFD FDFD"
	$"FDFD 56F6 F6F6 56FE ACF7 F6F6 F6F7 FDFD"
	$"FDFB 0000 0000 F9FE 5600 0000 0056 FEFD"
	$"FDAC 8156 0000 FBFD FCFA F900 0081 FDFD"
	$"FDFD FE81 0000 ACFD FDFE AC00 00FC FDFD"
	$"FDFD FEF8 00F6 FDFD FDFD 8100 F5FD FDFD"
	$"FDFD FDF6 0056 FEFD FDFE F800 F7FE FDFD"
	$"FDFD AC00 00FB FDFD FDFD F600 56FE FDFD"
	$"FDFD FB00 00FC FEFD FCF7 0000 FAFD FDFD"
	$"FDFD FB00 00F5 2BF6 0000 0000 00F6 FDFD"
	$"FDFD FDF7 0000 0000 00F5 0000 00F7 FDFD"
	$"FDFD FDFD 8156 56FA FCAC FCFB FCFD FDFD"
	$"FDFD FDFD FDFE FEFD FDFD FDFD FDFD FDFD"
	$"FDFD FDFD FDFD FDFD FDFD FDFD FDFD FDFD"
};

/*  Keyboard Icon Resources - These resources define the icon that is used to represent our
    text service in the keyboard menu, menu bar, and System Preferences. */

data 'kcs#' (kMacUIMBaseResourceID) {
	$"FFFF FFFF FFFF C183 C103 E3C7 F3E7 E3E7"
	$"E3C7 E7C7 E78F E003 E003 F9FF FFFF FFFF"
	$"FFFF FFFF FFFF FFFF FFFF FFFF FFFF FFFF"
	$"FFFF FFFF FFFF FFFF FFFF FFFF FFFF FFFF"
};

data 'kcs4' (kMacUIMBaseResourceID) {
	$"AAAA AAAA AAAA AAAA AAAA AAAA AAAA AAAA"
	$"AAAA AAAA AAAA AAAA AADC CCDF ECCC CCAA"
	$"AE00 00DF D000 0DFA AEDD 00EA EDD0 0DAA"
	$"AAFD 00EA AFE0 0EAA AAFC 0CAA AAD0 0AAA"
	$"AAAC 0DFA AFC0 CFAA AAE0 0EAA AAC0 DFAA"
	$"AAE0 0EFA EC00 DAAA AAE0 00CC 0000 0CAA"
	$"AAAC 0000 0000 0CAA AAAA DDDD EEEE EAAA"
	$"AAAA AFFA AAAA AAAA AAAA AAAA AAAA AAAA"
};

data 'kcs8' (kMacUIMBaseResourceID) {
	$"FDFD FDFD FDFD FDFD FDFD FDFD FDFD FDFD"
	$"FDFD FDFD FDFD FDFD FDFD FDFD FDFD FDFD"
	$"FDFD FDFD FDFD FDFD FDFD FDFD FDFD FDFD"
	$"FDFD 56F6 F6F6 56FE ACF7 F6F6 F6F7 FDFD"
	$"FDFB 0000 0000 F9FE 5600 0000 0056 FEFD"
	$"FDAC 8156 0000 FBFD FCFA F900 0081 FDFD"
	$"FDFD FE81 0000 ACFD FDFE AC00 00FC FDFD"
	$"FDFD FEF8 00F6 FDFD FDFD 8100 F5FD FDFD"
	$"FDFD FDF6 0056 FEFD FDFE F800 F7FE FDFD"
	$"FDFD AC00 00FB FDFD FDFD F600 56FE FDFD"
	$"FDFD FB00 00FC FEFD FCF7 0000 FAFD FDFD"
	$"FDFD FB00 00F5 2BF6 0000 0000 00F6 FDFD"
	$"FDFD FDF7 0000 0000 00F5 0000 00F7 FDFD"
	$"FDFD FDFD 8156 56FA FCAC FCFB FCFD FDFD"
	$"FDFD FDFD FDFE FEFD FDFD FDFD FDFD FDFD"
	$"FDFD FDFD FDFD FDFD FDFD FDFD FDFD FDFD"
};

resource 'MENU' (kMacUIMBaseResourceID + 1)
{
    kMacUIMBaseResourceID,
    textMenuProc,
    allEnabled,
    enabled,
    "00000",
    {
/*
        "Show Keyboard Palette", noIcon, "K", noMark, plain,
        "Show Send Event Palette", noIcon, "D", noMark, plain,
        "-", noIcon, noKey, noMark, plain,
        "Convert To Lowercase", noIcon, "L", noMark, plain,
        "Convert To Uppercase", noIcon, "U", noMark, plain
*/
    }
};

resource 'xmnu' (kMacUIMBaseResourceID + 1)
{
    versionZero
    {
        {
            dataItem {'SHKP', kMenuShiftModifier + kMenuControlModifier + kMenuNoCommandModifier,
                      currScript, 0, 0, noHierID, sysFont, naturalGlyph},
            dataItem {'SHDP', kMenuShiftModifier + kMenuControlModifier + kMenuNoCommandModifier,
                      currScript, 0, 0, noHierID, sysFont, naturalGlyph},
            skipItem {},
            dataItem {'CLOW', kMenuShiftModifier + kMenuControlModifier + kMenuNoCommandModifier,
                      currScript, 0, 0, noHierID, sysFont, naturalGlyph},
            dataItem {'CUPP', kMenuShiftModifier + kMenuControlModifier + kMenuNoCommandModifier,
                      currScript, 0, 0, noHierID, sysFont, naturalGlyph}
        }
    }
};

resource 'STR ' (kMacUIMBaseResourceID)
{
    "MacUIM"
};

resource 'STR#' (kMacUIMBaseResourceID + 1)
{
    {
	"Show Keyboard Palette",
        "Hide Keyboard Palette",
	"Show Send Event Palette",
        "Hide Send Event Palette"
    }
};
