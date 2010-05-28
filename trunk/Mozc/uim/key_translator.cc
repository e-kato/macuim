// Copyright 2010, Google Inc.
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
//     * Neither the name of Google Inc. nor the names of its
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

#include "unix/uim/key_translator.h"

#include <uim.h>

#include "base/logging.h"

namespace {

const struct SpecialKeyMap {
  unsigned int from;
  mozc::commands::KeyEvent::SpecialKey to;
} special_key_map[] = {
  {0x20, mozc::commands::KeyEvent::SPACE},
  {UKey_Return, mozc::commands::KeyEvent::ENTER},
  {UKey_Left, mozc::commands::KeyEvent::LEFT},
  {UKey_Right, mozc::commands::KeyEvent::RIGHT},
  {UKey_Up, mozc::commands::KeyEvent::UP},
  {UKey_Down, mozc::commands::KeyEvent::DOWN},
  {UKey_Escape, mozc::commands::KeyEvent::ESCAPE},
  {UKey_Delete, mozc::commands::KeyEvent::DEL},
  {UKey_Backspace, mozc::commands::KeyEvent::BACKSPACE},
  {UKey_Insert, mozc::commands::KeyEvent::INSERT},
  {UKey_Henkan, mozc::commands::KeyEvent::HENKAN},
  {UKey_Muhenkan, mozc::commands::KeyEvent::MUHENKAN},
  {UKey_Hiragana, mozc::commands::KeyEvent::KANA},
  {UKey_Katakana, mozc::commands::KeyEvent::KANA},
  {UKey_Eisu_toggle, mozc::commands::KeyEvent::EISU},
  {UKey_Home, mozc::commands::KeyEvent::HOME},
  {UKey_End, mozc::commands::KeyEvent::END},
  {UKey_Tab, mozc::commands::KeyEvent::TAB},
  {UKey_F1, mozc::commands::KeyEvent::F1},
  {UKey_F2, mozc::commands::KeyEvent::F2},
  {UKey_F3, mozc::commands::KeyEvent::F3},
  {UKey_F4, mozc::commands::KeyEvent::F4},
  {UKey_F5, mozc::commands::KeyEvent::F5},
  {UKey_F6, mozc::commands::KeyEvent::F6},
  {UKey_F7, mozc::commands::KeyEvent::F7},
  {UKey_F8, mozc::commands::KeyEvent::F8},
  {UKey_F9, mozc::commands::KeyEvent::F9},
  {UKey_F10, mozc::commands::KeyEvent::F10},
  {UKey_F11, mozc::commands::KeyEvent::F11},
  {UKey_F12, mozc::commands::KeyEvent::F12},
  {UKey_F13, mozc::commands::KeyEvent::F13},
  {UKey_F14, mozc::commands::KeyEvent::F14},
  {UKey_F15, mozc::commands::KeyEvent::F15},
  {UKey_F16, mozc::commands::KeyEvent::F16},
  {UKey_F17, mozc::commands::KeyEvent::F17},
  {UKey_F18, mozc::commands::KeyEvent::F18},
  {UKey_F19, mozc::commands::KeyEvent::F19},
  {UKey_F20, mozc::commands::KeyEvent::F20},
  {UKey_F21, mozc::commands::KeyEvent::F21},
  {UKey_F22, mozc::commands::KeyEvent::F22},
  {UKey_F23, mozc::commands::KeyEvent::F23},
  {UKey_F24, mozc::commands::KeyEvent::F24},
  {UKey_Prior, mozc::commands::KeyEvent::PAGE_UP},
  {UKey_Next, mozc::commands::KeyEvent::PAGE_DOWN},
};

const struct ModifierKeyMap {
  unsigned int from;
  mozc::commands::KeyEvent::ModifierKey to;
} modifier_key_map[] = {
  {UKey_Shift, mozc::commands::KeyEvent::SHIFT},
  {UKey_Control, mozc::commands::KeyEvent::CTRL},
  {UKey_Alt, mozc::commands::KeyEvent::ALT},
};

const struct ModifierMaskMap {
  unsigned int from;
  mozc::commands::KeyEvent::ModifierKey to;
} modifier_mask_map[] = {
  {UMod_Shift, mozc::commands::KeyEvent::SHIFT},
  {UMod_Control, mozc::commands::KeyEvent::CTRL},
  {UMod_Alt, mozc::commands::KeyEvent::ALT},
};

}  // namespace

namespace mozc {
namespace uim {

KeyTranslator::KeyTranslator() {
  Init();
}

KeyTranslator::~KeyTranslator() {
}

// TODO(mazda): Support Kana input
bool KeyTranslator::Translate(unsigned int keyval,
                              unsigned int keycode,
                              unsigned int modifiers,
                              mozc::commands::KeyEvent *out_event) const {
  DCHECK(out_event) << "out_event is NULL";
  out_event->Clear();

  if (IsAscii(keyval, keycode, modifiers)) {
    out_event->set_key_code(keyval);
  } else if (IsModifierKey(keyval, keycode, modifiers)) {
    ModifierKeyMap::const_iterator i = modifier_key_map_.find(keyval);
    DCHECK(i != modifier_key_map_.end());
    out_event->add_modifier_keys((*i).second);
  } else if (IsSpecialKey(keyval, keycode, modifiers)) {
    SpecialKeyMap::const_iterator i = special_key_map_.find(keyval);
    DCHECK(i != special_key_map_.end());
    out_event->set_special_key((*i).second);
  } else {
    VLOG(1) << "Unknown keyval: " << keyval;
    return false;
  }

  for (ModifierKeyMap::const_iterator i = modifier_mask_map_.begin();
       i != modifier_mask_map_.end();
       ++i) {

    // Do not set a SHIFT modifier when |keyval| is a printable key by following
    // the Mozc's rule.
    if (((*i).second == commands::KeyEvent::SHIFT) &&
        IsAscii(keyval, keycode, modifiers)) {
      continue;
    }

    if ((*i).first & modifiers) {
      out_event->add_modifier_keys((*i).second);
    }
  }

  return true;
}

void KeyTranslator::Init() {
  for (int i = 0; i < arraysize(special_key_map); ++i) {
    CHECK(special_key_map_.insert(make_pair(special_key_map[i].from,
                                            special_key_map[i].to)).second);
  }
  for (int i = 0; i < arraysize(modifier_key_map); ++i) {
    CHECK(modifier_key_map_.insert(make_pair(modifier_key_map[i].from,
                                             modifier_key_map[i].to)).second);
  }
  for (int i = 0; i < arraysize(modifier_mask_map); ++i) {
    CHECK(modifier_mask_map_.insert(make_pair(modifier_mask_map[i].from,
                                              modifier_mask_map[i].to)).second);
  }
}

bool KeyTranslator::IsModifierKey(unsigned int keyval,
                                  unsigned int keycode,
                                  unsigned int modifiers) const {
  return modifier_key_map_.find(keyval) != modifier_key_map_.end();
}

bool KeyTranslator::IsSpecialKey(unsigned int keyval,
                                 unsigned int keycode,
                                 unsigned int modifiers) const {
  return special_key_map_.find(keyval) != special_key_map_.end();
}

bool KeyTranslator::IsAscii(unsigned int keyval,
                            unsigned int keycode,
                            unsigned int modifiers) {
  return (keyval > 0x20 &&
          // Note: Space key (0x20) is a special key in Mozc.
          keyval <= 0x7e);  // ~
}

}  // namespace uim
}  // namespace mozc
