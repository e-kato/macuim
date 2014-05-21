// Copyright 2010, Google Inc.
// Copyright (c) 2010-2012 uim Project http://code.google.com/p/uim/
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//     * Neither the name of authors nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#ifndef MOZC_UNIX_UIM_KEY_TRANSLATOR_H_
#define MOZC_UNIX_UIM_KEY_TRANSLATOR_H_

#include <uim.h>

#include <map>
#include <ext/hash_map>
using __gnu_cxx::hash_map;

#include "base/port.h"
#include "session/commands.pb.h"

namespace mozc {
namespace uim {

// This class is responsible for converting key code sent from ibus-daemon
// (defined in /usr/include/ibus-1.0/ibuskeysyms.h) to a KeyEvent object for
// the input of session_interface.
class KeyTranslator {
 public:
  KeyTranslator();
  virtual ~KeyTranslator();

  // Converts ibus keycode to Mozc key code and stores them on |out_event|.
  // Returns true if ibus keycode is successfully converted to Mozc key code.
  bool Translate(unsigned int keyval,
                 unsigned int keycode,
                 unsigned int modifiers,
                 config::Config::PreeditMethod method,
                 bool layout_is_jp,
                 commands::KeyEvent *out_event) const;

 private:
  typedef hash_map<unsigned int, commands::KeyEvent::SpecialKey> SpecialKeyMap;
  typedef map<unsigned int, commands::KeyEvent::ModifierKey> ModifierKeyMap;
  typedef map<unsigned int, pair<string, string> > KanaMap;

  // Returns true iff key is modifier key such as SHIFT, ALT, or CAPSLOCK.
  bool IsModifierKey(unsigned int keyval,
                     unsigned int keycode,
                     unsigned int modifiers) const;

  // Returns true iff key is special key such as ENTER, ESC, or PAGE_UP.
  bool IsSpecialKey(unsigned int keyval,
                    unsigned int keycode,
                    unsigned int modifiers) const;
  // Returns true iff |keyval| is a key with a kana assigned.
  bool IsKanaAvailable(unsigned int keyval,
                       unsigned int keycode,
                       unsigned int modifiers,
                       bool layout_is_jp,
                       string *out) const;


  // Returns true iff key is ASCII such as '0', 'A', or '!'.
  static bool IsAscii(unsigned int keyval,
                      unsigned int keycode,
                      unsigned int modifiers);

  // Initializes private fields.
  void Init();

  // Stores a mapping from ibus keys to Mozc's special keys.
  SpecialKeyMap special_key_map_;
  // Stores a mapping from ibus modifier keys to Mozc's modifier keys.
  ModifierKeyMap modifier_key_map_;
  // Stores a mapping from ibus modifier masks to Mozc's modifier keys.
  ModifierKeyMap modifier_mask_map_;
  // Stores a mapping from ASCII to Kana character. For example, ASCII character
  // '4' is mapped to Japanese 'Hiragana Letter U' (without Shift modifier) and
  // 'Hiragana Letter Small U' (with Shift modifier).
  KanaMap kana_map_jp_;  // mapping for JP keyboard.
  KanaMap kana_map_us_;  // mapping for US keyboard.

  DISALLOW_COPY_AND_ASSIGN(KeyTranslator);
};

}  // namespace uim
}  // namespace mozc

#endif  // MOZC_UNIX_UIM_KEY_TRANSLATOR_H_
