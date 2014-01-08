/*

  Copyright (c) 2010-2013 uim Project http://code.google.com/p/uim/

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

//#include <config.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "uim.h"
#include "uim-scm.h"
#include "uim-scm-abbrev.h"
#include "uim-util.h"
#if UIM_VERSION_REQUIRE(1, 6, 0)
# include "dynlib.h"
#else
# include "plugin.h"
#endif

#include "base/base.h"
#include "base/util.h"
#include "base/scoped_ptr.h"
#include "config/config.pb.h"
#include "session/commands.pb.h"
#include "client/client.h"
#include "unix/uim/key_translator.h"

// use server/client session
#include "base/util.h"

#define USE_CASCADING_CANDIDATES	0

#include <map>
#include <ext/hash_map>
using __gnu_cxx::hash_map;
static char **argv;

// for every 5 minutes, call SyncData
const uint64 kSyncDataInterval = 5 * 60;
// An ID for a candidate which is not associated with a text.
const int32 kBadCandidateId = -1;

uint64 GetTime() {
  return static_cast<uint64>(time(NULL));
}

namespace mozc {

namespace client {
class ClientInterface;
}
namespace uim {

static int nr_contexts;
static struct context_slot_ {
  client::ClientInterface *session;
  commands::Output *output; 
  commands::CompositionMode currentMode;
  bool has_preedit_before;
  bool need_cand_reactivate;
  int prev_page;
  int cand_nr_before;
  uint64 last_sync_time;
#if USE_CASCADING_CANDIDATES
  vector<int32> *unique_candidate_ids;
#endif
  config::Config::PreeditMethod preedit_method;
} *context_slot;

static KeyTranslator *keyTranslator;
static bool enable_reconversion;
static void update_all(uim_lisp mc_, int id);

static int
unused_context_id(void)
{
  int i;

  for (i = 0; i < nr_contexts; i++) {
    if (!context_slot[i].session)
      return i;
  }

  nr_contexts++;
  context_slot = (context_slot_ *)uim_realloc(context_slot, sizeof(struct context_slot_) * (nr_contexts));

  return i;
}

static void
SyncData(int id, bool force)
{
  if (context_slot[id].session == NULL)
    return;

  const uint64 current_time = GetTime();
  if (force ||
      (current_time >= context_slot[id].last_sync_time &&
       current_time - context_slot[id].last_sync_time >= kSyncDataInterval)) {
    context_slot[id].session->SyncData();
    context_slot[id].last_sync_time = current_time;
  }
}

static void
update_deletion_range(uim_lisp mc_, int id)
{
  commands::Output *output = context_slot[id].output;
  int offset, length;

  if (!enable_reconversion)
    return;

  if (!output->has_deletion_range())
    return;

  offset = output->deletion_range().offset();
  length = output->deletion_range().length();

  if (offset + length < 0)
    return;

  uim_scm_callf("im-delete-text", "oyyii", mc_, "primary", "cursor", -offset, offset + length);
}

static void
update_result(uim_lisp mc_, int id)
{
  commands::Output *output = context_slot[id].output;

  if (!output->has_result())
    return;

  const char *str = output->result().value().c_str();
  uim_scm_callf("im-commit", "os", mc_, str);
}

static uim_lisp
insert_cursor(uim_lisp segs, const commands::Preedit::Segment &segment, int attr, int pos)
{
  size_t len = segment.value_length();

  string former = Util::SubString(segment.value(), 0, pos);
  string latter = Util::SubString(segment.value(), pos, len);

  uim_lisp seg_f, seg_c, seg_l;
  if (pos == 0) {
    seg_f = uim_scm_null(); /* not used */
    seg_c = CONS(MAKE_INT(UPreeditAttr_Cursor), MAKE_STR(""));
    seg_l = CONS(MAKE_INT(attr), MAKE_STR(latter.c_str()));

    segs = CONS(seg_c, segs);
    segs = CONS(seg_l, segs);
  } else {
    seg_f = CONS(MAKE_INT(attr), MAKE_STR(former.c_str()));
    seg_c = CONS(MAKE_INT(UPreeditAttr_Cursor), MAKE_STR(""));
    seg_l = CONS(MAKE_INT(attr), MAKE_STR(latter.c_str()));

    segs = CONS(seg_f, segs);
    segs = CONS(seg_c, segs);
    segs = CONS(seg_l, segs);
  }

  return segs;
}

static uim_lisp
compose_preedit(const commands::Output *output)
{
  const commands::Preedit &preedit = output->preedit();
  uim_lisp segs = uim_scm_null();
  uim_lisp separator = uim_scm_callf("mozc-separator", "");
  int cursorPos;
  int count = 0;
  int seg_count = preedit.segment_size();
  
  cursorPos = output->preedit().cursor();

  for (int i = 0; i < seg_count; ++i) {
    const commands::Preedit::Segment segment = preedit.segment(i);
    const char *str = segment.value().c_str();
    int attr;
    int prev_count = count;
    uim_lisp seg;
    count += segment.value_length();

    switch (segment.annotation()) {
    case commands::Preedit::Segment::NONE:
      attr = UPreeditAttr_None;
      break;
    case commands::Preedit::Segment::UNDERLINE:
      attr = UPreeditAttr_UnderLine;
      break;
    case commands::Preedit::Segment::HIGHLIGHT:
      attr = UPreeditAttr_Reverse | UPreeditAttr_Cursor;
      break;
    default:
      attr = UPreeditAttr_None;
      break;
    }

    if (((prev_count < cursorPos) && (count > cursorPos)) || cursorPos == 0) {
      uim_lisp new_segs;
      if ((new_segs = insert_cursor(segs, segment, attr, cursorPos - prev_count)) != uim_scm_null()) {
         segs = new_segs;
         continue;
      }
    }

    seg = CONS(MAKE_INT(attr), MAKE_STR(str));

    if (TRUEP(separator) && i > 0)
      segs = CONS(separator, segs);
    segs = CONS(seg, segs);

    if (count == cursorPos && !output->preedit().has_highlighted_position()) {
      seg = CONS(MAKE_INT(UPreeditAttr_Cursor), MAKE_STR(""));
      segs = CONS(seg, segs);
    }
  }

  return uim_scm_callf("reverse", "o", segs);
}

static void
update_preedit(uim_lisp mc_, int id)
{
  uim_lisp preedit;
  commands::Output *output = context_slot[id].output;

  if (!output->has_preedit()) {
    if (context_slot[id].has_preedit_before) {
      uim_scm_callf("context-update-preedit", "oo", mc_, uim_scm_null());
    }
    context_slot[id].has_preedit_before = false;

    return;
  } else {
    preedit = compose_preedit(output);
    context_slot[id].has_preedit_before = true;
  }
  uim_scm_callf("context-update-preedit", "oo", mc_, preedit);
}

static void
update_candidates(uim_lisp mc_, int id)
{
  commands::Output *output = context_slot[id].output;

  if (!output->has_candidates()) {
    uim_scm_callf("im-deactivate-candidate-selector", "o", mc_);
    context_slot[id].cand_nr_before = 0;

    return;
  }

  const commands::Candidates &candidates = output->candidates();
  bool first_time = false;
  bool has_focused_index = candidates.has_focused_index();
  int current_page = has_focused_index ? candidates.focused_index() / 9 : 0;

  if ((context_slot[id].cand_nr_before != candidates.size()) || !has_focused_index)
    first_time = true;

  if (first_time || (context_slot[id].need_cand_reactivate && current_page != context_slot[id].prev_page)) {
    uim_scm_callf("im-activate-candidate-selector", "oii", mc_, candidates.size(), 9);
    // cope with issue #6
    if (current_page != 0)
      context_slot[id].need_cand_reactivate = true;
    else
      context_slot[id].need_cand_reactivate = false;
  }
  context_slot[id].prev_page = current_page;

  if (has_focused_index) {
    int index = candidates.focused_index();
    uim_scm_callf("im-select-candidate", "oi", mc_, index);
  }
  context_slot[id].cand_nr_before = candidates.size();

#if USE_CASCADING_CANDIDATES
  if (first_time || (candidates.has_focused_index() && candidates.focused_index() % 9 == 0)) {
    context_slot[id].unique_candidate_ids->clear();
    for (int i = 0; i < candidates.candidate_size(); ++i) {
      if (candidates.candidate(i).has_id()) {
        const int32 cand_id = candidates.candidate(i).id();
        context_slot[id].unique_candidate_ids->push_back(cand_id);
      } else {
        // The parent node of the cascading window does not have an id since the
        // node does not contain a candidate word.
        context_slot[id].unique_candidate_ids->push_back(kBadCandidateId);
      }
    }
  }
#endif
}

static void
update_composition_mode(uim_lisp mc_, int id)
{
  commands::Output *output = context_slot[id].output;
  
  if (!output->has_mode())
    return;

  const commands::CompositionMode newMode = output->mode();
  if (context_slot[id].currentMode == newMode)
    return;

  context_slot[id].currentMode = newMode;
}

static void
execute_callback(uim_lisp mc_, int id)
{
  commands::Output *output = context_slot[id].output;
  
  if (!enable_reconversion)
    return;

  if (!output->has_callback())
    return;

  if (!output->callback().has_session_command())
    return;

  const commands::SessionCommand &command = output->callback().session_command();
  if (!command.has_type())
    return;

  const commands::SessionCommand::CommandType type = command.type();
  commands::SessionCommand session_command;
  session_command.set_type(type);
  int use_primary_text = 0;

  switch (type) {
  case commands::SessionCommand::UNDO:
    // do nothing.
    break;
  case commands::SessionCommand::CONVERT_REVERSE:
    {
      // try selected text first
      uim_lisp ustr = uim_scm_callf("im-acquire-text", "oyyiy", mc_, "selection", "beginning", 0, "full");
      uim_lisp latter;

      if (TRUEP(ustr) &&
	  !NULLP(latter = uim_scm_callf("ustr-latter-seq", "o", ustr))) {
	  uim_lisp str = CAR(latter);

          string text = REFER_C_STR(str);
          session_command.set_text(text);
      } else {
#if 0
	// then primary text
        uim_lisp former;
        ustr = uim_scm_callf("im-acquire-text", "oyyyi", mc_, "primary", "cursor", "line", 0);
	if (TRUEP(ustr) && !NULLP(former = uim_scm_callf("ustr-former-seq", "o", ustr))) {
	  uim_lisp str = CAR(former);
	  string text = REFER_C_STR(str);
	  session_command.set_text(text);
	  use_primary_text = 1;
	} else
	  return;
#else
        // UNDO if no selection
        session_command.set_type(commands::SessionCommand::UNDO);
#endif
      }
    }
    break;
  default:
    return;
  }

  if (!context_slot[id].session->SendCommand(session_command, context_slot[id].output)) {
    // callback command failed
    return;
  }

  if (type == commands::SessionCommand::CONVERT_REVERSE) {
    if (use_primary_text)
      uim_scm_callf("im-delete-text", "oyyyi", mc_, "primary", "cursor", "line", 0);
    else
      uim_scm_callf("im-delete-text", "oyyiy", mc_, "selection", "beginning", 0, "full");
  }
  update_all(mc_, id);
}

static void
update_all(uim_lisp mc_, int id)
{
  update_deletion_range(mc_, id);
  update_result(mc_, id);
  update_preedit(mc_, id);
  update_candidates(mc_, id);
  update_composition_mode(mc_, id);
  execute_callback(mc_, id);
}

static uim_lisp
create_context(uim_lisp mc_)
{
  int id;

  client::ClientInterface *session = new client::Client;
  commands::Output *output = new commands::Output;
  if (!keyTranslator)
    keyTranslator = new KeyTranslator;

  id = unused_context_id();
  context_slot[id].session = session;
  context_slot[id].output = output;
  context_slot[id].currentMode = commands::HIRAGANA;
  context_slot[id].has_preedit_before = false;
  context_slot[id].need_cand_reactivate = false;
  context_slot[id].cand_nr_before = 0;
  context_slot[id].prev_page = 0;
#if USE_CASCADING_CANDIDATES
  context_slot[id].unique_candidate_ids = new vector<int32>;
#endif

  // Launch mozc_server
  // or should I call this with mozc-on-key?
  session->EnsureConnection();
#if !USE_CASCADING_CANDIDATES
  session->EnableCascadingWindow(false);
#endif

  if (!enable_reconversion) {
    if (!FALSEP(uim_scm_callf("symbol-bound?", "y", "mozc-check-uim-version")))
      enable_reconversion = (bool)C_BOOL(uim_scm_callf("mozc-check-uim-version", "iii", 1, 7, 2));
  }

  if (enable_reconversion) {
    commands::Capability capability;
    capability.set_text_deletion(commands::Capability::DELETE_PRECEDING_TEXT);
    session->set_client_capability(capability);
  }


  return MAKE_INT(id);
}

static uim_lisp
release_context(uim_lisp id_)
{
  int id = C_INT(id_);

  if (id < nr_contexts) {
    SyncData(id, true);
    delete context_slot[id].session;
    delete context_slot[id].output;
#if USE_CASCADING_CANDIDATES
    delete context_slot[id].unique_candidate_ids;
#endif
    context_slot[id].session = NULL;
    context_slot[id].output = NULL;
  }

  return uim_scm_f();
}

static uim_lisp
reset_context(uim_lisp id_)
{
  return uim_scm_t();
}

static uim_lisp
press_key(uim_lisp mc_, uim_lisp id_, uim_lisp key_, uim_lisp state_)
{
  client::ClientInterface *session;
  commands::KeyEvent key;
  int id;
  int keyval, keycode, modifiers;
  config::Config::PreeditMethod preedit_method;
  char *keyboard;
  bool layout_is_jp;

  id = C_INT(id_);
  session = context_slot[id].session;
  preedit_method = context_slot[id].preedit_method;
  keyboard = uim_scm_symbol_value_str("mozc-keyboard-type-for-kana-input-method");
  layout_is_jp = keyboard && !strcmp(keyboard, "jp-keyboard") ? true : false;
  free(keyboard);

  keyval = C_INT(key_);
  modifiers = C_INT(state_);
  keycode = 0; /* XXX */

  if (!(*keyTranslator).Translate(keyval, keycode, modifiers, preedit_method, layout_is_jp, &key))
    return uim_scm_f();

  if (uim_scm_symbol_value_bool("mozc-use-context-aware-conversion?")) {
    commands::Context context;
    uim_lisp ustr = uim_scm_callf("im-acquire-text", "oyyyy", mc_, "primary", "cursor", "line", "line");
    uim_lisp former, latter, str;
    if (TRUEP(ustr)) {
      if(!NULLP(former = uim_scm_callf("ustr-former-seq", "o", ustr))) {
        str = CAR(former);
	context.set_preceding_text(REFER_C_STR(str));
      }
      if(!NULLP(latter = uim_scm_callf("ustr-latter-seq", "o", ustr))) {
        str = CAR(latter);
	context.set_following_text(REFER_C_STR(str));
      }
    }
    if (!(*session).SendKeyWithContext(key, context, context_slot[id].output))
      return uim_scm_f();
  } else {
    if (!(*session).SendKey(key, context_slot[id].output))
      return uim_scm_f();
  }

  update_all(mc_, id);

  const bool consumed = context_slot[id].output->consumed();
#if 0
  fprintf(stderr, "debugstring %s\n", output.DebugString().c_str());
  fprintf(stderr, "consumed %d\n", consumed ? 1 : 0);
#endif

  return consumed ? uim_scm_t() : uim_scm_f();
}

static uim_lisp
release_key(uim_lisp id_, uim_lisp key_, uim_lisp state_)
{
  return uim_scm_f();
}

static uim_lisp
get_nr_candidates(uim_lisp id_)
{
  int id = C_INT(id_);
  commands::Output *output = context_slot[id].output;

  return MAKE_INT(output->candidates().size());
}

static uim_lisp
get_nth_candidate(uim_lisp id_, uim_lisp nth_)
{
  int id = C_INT(id_);
  commands::Output *output = context_slot[id].output;
  const commands::Candidates &candidates = output->candidates();
  const char *cand, *prefix, *suffix;
  char *s;

  int nth;
  int idx;
  int nr;
  int page_nr;
  
  nth = C_INT(nth_);
  nr = candidates.size();
  page_nr = candidates.candidate_size();

  if (nth < nr) {
    idx = nth % 9;

    if (idx < page_nr) {
      prefix = candidates.candidate(idx).annotation().prefix().c_str();
      cand = candidates.candidate(idx).value().c_str();
      suffix = candidates.candidate(idx).annotation().suffix().c_str();
      if (asprintf(&s, "%s%s%s", prefix, cand, suffix) == -1)
        s = strdup("");
    } else {
      s = strdup("");
    }
  } else
    s = strdup("");

  return MAKE_STR_DIRECTLY(s);
}

static uim_lisp
get_nth_label(uim_lisp id_, uim_lisp nth_)
{
  int id = C_INT(id_);
  commands::Output *output = context_slot[id].output;
  const commands::Candidates &candidates = output->candidates();
  const char *label;

  int nth;
  int idx;
  int nr;
  int page_nr;
  
  nth = C_INT(nth_);
  nr = candidates.size();
  page_nr = candidates.candidate_size();

  if (nth < nr) {
    idx = nth % 9;
    if (idx < page_nr)
      label = candidates.candidate(idx).annotation().shortcut().c_str();
    else
      label = "";
  } else
    label = "";

  return MAKE_STR(label);
}

static uim_lisp
get_nth_annotation(uim_lisp id_, uim_lisp nth_)
{
  int id = C_INT(id_);
  commands::Output *output = context_slot[id].output;
  const commands::Candidates &candidates = output->candidates();
  const char *annotation;

  int nth;
  int idx;
  int nr;
  int page_nr;
  
  nth = C_INT(nth_);
  nr = candidates.size();
  page_nr = candidates.candidate_size();

  if (nth < nr) {
    idx = nth % 9;
    if (idx < page_nr)
      annotation = candidates.candidate(idx).annotation().description().c_str();
    else
      annotation = "";

  } else
    annotation = "";

  return MAKE_STR(annotation);
}

/* from uim-key.c */
static struct key_entry {
  int key;
  const char *str;
} key_tab[] = {
  {UKey_Yen, "yen"},
  {UKey_Backspace, "backspace"},
  {UKey_Delete, "delete"},
  {UKey_Escape, "escape"},
  {UKey_Return, "return"},
  {UKey_Tab, "tab"},
  {UKey_Left, "left"},
  {UKey_Up, "up"},
  {UKey_Right, "right"},
  {UKey_Down, "down"},
  {UKey_Prior, "prior"},
  {UKey_Next, "next"},
  {UKey_Home, "home"},
  {UKey_End, "end"},
  {UKey_Insert, "insert"},
  {UKey_Multi_key, "Multi_key"},
  {UKey_Codeinput, "codeinput"},
  {UKey_SingleCandidate, "single-candidate"},
  {UKey_MultipleCandidate, "multiple-candidate"},
  {UKey_PreviousCandidate, "previous-candidate"},
  {UKey_Mode_switch, "Mode_switch"},
  {UKey_Kanji, "Kanji"},
  {UKey_Muhenkan, "Muhenkan"},
  {UKey_Henkan_Mode, "Henkan_Mode"},
  {UKey_Romaji, "romaji"},
  {UKey_Hiragana, "hiragana"},
  {UKey_Katakana, "katakana"},
  {UKey_Hiragana_Katakana, "hiragana-katakana"},
  {UKey_Zenkaku, "zenkaku"},
  {UKey_Hankaku, "hankaku"},
  {UKey_Zenkaku_Hankaku, "zenkaku-hankaku"},
  {UKey_Touroku, "touroku"},
  {UKey_Massyo, "massyo"},
  {UKey_Kana_Lock, "kana-lock"},
  {UKey_Kana_Shift, "kana-shift"},
  {UKey_Eisu_Shift, "eisu-shift"},
  {UKey_Eisu_toggle, "eisu-toggle"},

  {UKey_Hangul, "hangul"},
  {UKey_Hangul_Start, "hangul-start"},
  {UKey_Hangul_End, "hangul-end"},
  {UKey_Hangul_Hanja, "hangul-hanja"},
  {UKey_Hangul_Jamo, "hangul-jamo"},
  {UKey_Hangul_Romaja, "hangul-romaja"},
  {UKey_Hangul_Codeinput, "hangul-codeinput"},
  {UKey_Hangul_Jeonja, "hangul-jeonja"},
  {UKey_Hangul_Banja, "hangul-banja"},
  {UKey_Hangul_PreHanja, "hangul-prehanja"},
  {UKey_Hangul_PostHanja, "hangul-posthanja"},
  {UKey_Hangul_SingleCandidate, "hangul-single-candidate"},
  {UKey_Hangul_MultipleCandidate, "hangul-multiple-candidate"},
  {UKey_Hangul_PreviousCandidate, "hangul-previous-candidate"},
  {UKey_Hangul_Special, "hangul-special"},

  {UKey_F1, "F1"},
  {UKey_F2, "F2"},
  {UKey_F3, "F3"},
  {UKey_F4, "F4"},
  {UKey_F5, "F5"},
  {UKey_F6, "F6"},
  {UKey_F7, "F7"},
  {UKey_F8, "F8"},
  {UKey_F9, "F9"},
  {UKey_F10, "F10"},
  {UKey_F11, "F11"},
  {UKey_F12, "F12"},
  {UKey_F13, "F13"},
  {UKey_F14, "F14"},
  {UKey_F15, "F15"},
  {UKey_F16, "F16"},
  {UKey_F17, "F17"},
  {UKey_F18, "F18"},
  {UKey_F19, "F19"},
  {UKey_F20, "F20"},
  {UKey_F21, "F21"},
  {UKey_F22, "F22"},
  {UKey_F23, "F23"},
  {UKey_F24, "F24"},
  {UKey_F25, "F25"},
  {UKey_F26, "F26"},
  {UKey_F27, "F27"},
  {UKey_F28, "F28"},
  {UKey_F29, "F29"},
  {UKey_F30, "F30"},
  {UKey_F31, "F31"},
  {UKey_F32, "F32"},
  {UKey_F33, "F33"},
  {UKey_F34, "F34"},
  {UKey_F35, "F35"},

  {UKey_Dead_Grave, "dead-grave"},
  {UKey_Dead_Acute, "dead-acute"},
  {UKey_Dead_Circumflex, "dead-circumflex"},
  {UKey_Dead_Tilde, "dead-tilde"},
  {UKey_Dead_Macron, "dead-macron"},
  {UKey_Dead_Breve, "dead-breve"},
  {UKey_Dead_Abovedot, "dead-abovedot"},
  {UKey_Dead_Diaeresis, "dead-diaeresis"},
  {UKey_Dead_Abovering, "dead-abovering"},
  {UKey_Dead_Doubleacute, "dead-doubleacute"},
  {UKey_Dead_Caron, "dead-caron"},
  {UKey_Dead_Cedilla, "dead-cedilla"},
  {UKey_Dead_Ogonek, "dead-ogonek"},
  {UKey_Dead_Iota, "dead-iota"},
  {UKey_Dead_VoicedSound, "dead-voiced-sound"},
  {UKey_Dead_SemivoicedSound, "dead-semivoiced-sound"},
  {UKey_Dead_Belowdot, "dead-belowdot"},
  {UKey_Dead_Hook, "dead-hook"},
  {UKey_Dead_Horn, "dead-horn"},

  {UKey_Kana_Fullstop, "kana-fullstop"},
  {UKey_Kana_OpeningBracket, "kana-opening-bracket"},
  {UKey_Kana_ClosingBracket, "kana-closing-bracket"},
  {UKey_Kana_Comma, "kana-comma"},
  {UKey_Kana_Conjunctive, "kana-conjunctive"},
  {UKey_Kana_WO, "kana-WO"},
  {UKey_Kana_a, "kana-a"},
  {UKey_Kana_i, "kana-i"},
  {UKey_Kana_u, "kana-u"},
  {UKey_Kana_e, "kana-e"},
  {UKey_Kana_o, "kana-o"},
  {UKey_Kana_ya, "kana-ya"},
  {UKey_Kana_yu, "kana-yu"},
  {UKey_Kana_yo, "kana-yo"},
  {UKey_Kana_tsu, "kana-tsu"},
  {UKey_Kana_ProlongedSound, "kana-prolonged-sound"},
  {UKey_Kana_A, "kana-A"},
  {UKey_Kana_I, "kana-I"},
  {UKey_Kana_U, "kana-U"},
  {UKey_Kana_E, "kana-E"},
  {UKey_Kana_O, "kana-O"},
  {UKey_Kana_KA, "kana-KA"},
  {UKey_Kana_KI, "kana-KI"},
  {UKey_Kana_KU, "kana-KU"},
  {UKey_Kana_KE, "kana-KE"},
  {UKey_Kana_KO, "kana-KO"},
  {UKey_Kana_SA, "kana-SA"},
  {UKey_Kana_SHI, "kana-SHI"},
  {UKey_Kana_SU, "kana-SU"},
  {UKey_Kana_SE, "kana-SE"},
  {UKey_Kana_SO, "kana-SO"},
  {UKey_Kana_TA, "kana-TA"},
  {UKey_Kana_CHI, "kana-CHI"},
  {UKey_Kana_TSU, "kana-TSU"},
  {UKey_Kana_TE, "kana-TE"},
  {UKey_Kana_TO, "kana-TO"},
  {UKey_Kana_NA, "kana-NA"},
  {UKey_Kana_NI, "kana-NI"},
  {UKey_Kana_NU, "kana-NU"},
  {UKey_Kana_NE, "kana-NE"},
  {UKey_Kana_NO, "kana-NO"},
  {UKey_Kana_HA, "kana-HA"},
  {UKey_Kana_HI, "kana-HI"},
  {UKey_Kana_FU, "kana-FU"},
  {UKey_Kana_HE, "kana-HE"},
  {UKey_Kana_HO, "kana-HO"},
  {UKey_Kana_MA, "kana-MA"},
  {UKey_Kana_MI, "kana-MI"},
  {UKey_Kana_MU, "kana-MU"},
  {UKey_Kana_ME, "kana-ME"},
  {UKey_Kana_MO, "kana-MO"},
  {UKey_Kana_YA, "kana-YA"},
  {UKey_Kana_YU, "kana-YU"},
  {UKey_Kana_YO, "kana-YO"},
  {UKey_Kana_RA, "kana-RA"},
  {UKey_Kana_RI, "kana-RI"},
  {UKey_Kana_RU, "kana-RU"},
  {UKey_Kana_RE, "kana-RE"},
  {UKey_Kana_RO, "kana-RO"},
  {UKey_Kana_WA, "kana-WA"},
  {UKey_Kana_N, "kana-N"},
  {UKey_Kana_VoicedSound, "kana-voiced-sound"},
  {UKey_Kana_SemivoicedSound, "kana-semivoiced-sound"},

  {UKey_Private1, "Private1"},
  {UKey_Private2, "Private2"},
  {UKey_Private3, "Private3"},
  {UKey_Private4, "Private4"},
  {UKey_Private5, "Private5"},
  {UKey_Private6, "Private6"},
  {UKey_Private7, "Private7"},
  {UKey_Private8, "Private8"},
  {UKey_Private9, "Private9"},
  {UKey_Private10, "Private10"},
  {UKey_Private11, "Private11"},
  {UKey_Private12, "Private12"},
  {UKey_Private13, "Private13"},
  {UKey_Private14, "Private14"},
  {UKey_Private15, "Private15"},
  {UKey_Private16, "Private16"},
  {UKey_Private17, "Private17"},
  {UKey_Private18, "Private18"},
  {UKey_Private19, "Private19"},
  {UKey_Private20, "Private20"},
  {UKey_Private21, "Private21"},
  {UKey_Private22, "Private22"},
  {UKey_Private23, "Private23"},
  {UKey_Private24, "Private24"},
  {UKey_Private25, "Private25"},
  {UKey_Private26, "Private26"},
  {UKey_Private27, "Private27"},
  {UKey_Private28, "Private28"},
  {UKey_Private29, "Private29"},
  {UKey_Private30, "Private30"},
  {UKey_Shift_key, "Shift_key"},
  {UKey_Alt_key, "Alt_key"},
  {UKey_Control_key, "Control_key"},
  {UKey_Meta_key, "Meta_key"},
  {UKey_Super_key, "Super_key"},
  {UKey_Hyper_key, "Hyper_key"},

  {UKey_Caps_Lock, "caps-lock"},
  {UKey_Num_Lock, "num-lock"},
  {UKey_Scroll_Lock, "scroll-lock"},
  /*  {UKey_Other, "other"},*/
  {0, 0}
};

struct eqstr
{
  bool operator()(const char* s1, const char* s2) const
  {
    return strcmp(s1, s2) == 0;
  }
};

typedef hash_map<const char *, int, __gnu_cxx::hash<const char *>, eqstr> KeyMap;
static KeyMap key_map;

static void install_keymap(void)
{
  int i;

  for (i = 0; key_tab[i].key; i++)
    key_map.insert(make_pair(key_tab[i].str, key_tab[i].key));
}

static uim_lisp
keysym_to_int(uim_lisp sym_)
{
  const char *sym = uim_scm_refer_c_str(sym_);
  int key = 0;

  KeyMap::iterator it = key_map.find(sym);
  if (it != key_map.end())
    key = it->second;

  return uim_scm_make_int(key);
}

static uim_lisp
get_composition_mode(uim_lisp id_)
{
  int id = C_INT(id_);
  const commands::CompositionMode mode = context_slot[id].currentMode;
  int type = 0;

  switch (mode) {
  case commands::DIRECT:
    type = -1;
    break;
  case commands::HIRAGANA:
    type = 0;
    break;
  case commands::FULL_KATAKANA:
    type = 1;
    break;
  case commands::HALF_KATAKANA:
    type = 2;
    break;
  case commands::HALF_ASCII:
    type = 3;
    break;
  case commands::FULL_ASCII:
    type = 4;
    break;
  default:
    type = -1;
    break;
  }

  return MAKE_INT(type);
}

static uim_lisp
set_composition_mode(uim_lisp mc_, uim_lisp id_, uim_lisp new_mode_)
{
  int id = C_INT(id_);
  commands::CompositionMode mode;
  commands::SessionCommand command;

  switch (C_INT(new_mode_)) {
  case -1:
    mode = commands::DIRECT;
    break;
  case 0:
    mode = commands::HIRAGANA;
    break;
  case 1:
    mode = commands::FULL_KATAKANA;
    break;
  case 2:
    mode = commands::HALF_KATAKANA;
    break;
  case 3:
    mode = commands::HALF_ASCII;
    break;
  case 4:
    mode = commands::FULL_ASCII;
    break;
  default:
    mode = commands::HIRAGANA;
    break;
  }

  if (mode == commands::DIRECT) {
    command.set_type(commands::SessionCommand::SUBMIT);
    context_slot[id].session->SendCommand(command, context_slot[id].output);
    update_all(mc_, id);
    uim_scm_callf("mozc-context-set-on!", "oo", mc_, uim_scm_f());
  } else {
    command.set_type(commands::SessionCommand::SWITCH_INPUT_MODE);
    command.set_composition_mode(mode);
    context_slot[id].session->SendCommand(command, context_slot[id].output);
    context_slot[id].currentMode = mode; /* don't set this with DIRECT mode */
    uim_scm_callf("mozc-context-set-on!", "oo", mc_, uim_scm_t());
  }

  return uim_scm_t();
}
 
static uim_lisp
set_composition_on(uim_lisp id_)
{
  int id = C_INT(id_);
  commands::SessionCommand command;

  command.set_type(commands::SessionCommand::SWITCH_INPUT_MODE);
  command.set_composition_mode(context_slot[id].currentMode);
  context_slot[id].session->SendCommand(command, context_slot[id].output);

  return uim_scm_t();
}

static uim_lisp
has_preedit(uim_lisp id_)
{
  int id = C_INT(id_);
  
  return context_slot[id].has_preedit_before ? uim_scm_t() : uim_scm_f();
}

static uim_lisp
select_candidate(uim_lisp mc_, uim_lisp id_, uim_lisp idx_)
{
  int id = C_INT(id_);
  int idx = C_INT(idx_) % 9;
  
#if USE_CASCADING_CANDIDATES
  if (idx >= context_slot[id].unique_candidate_ids->size())
#else
  if (idx >= context_slot[id].output->candidates().candidate_size())
#endif
    return uim_scm_f();

#if USE_CASCADING_CANDIDATES
  const int32 cand_id = (*context_slot[id].unique_candidate_ids)[idx];
  if (cand_id == kBadCandidateId)
    return uim_scm_f();
#else
  const int32 cand_id = context_slot[id].output->candidates().candidate(idx).id();
#endif

  commands::SessionCommand command;
  command.set_type(commands::SessionCommand::SELECT_CANDIDATE);
  command.set_id(cand_id);
  context_slot[id].session->SendCommand(command, context_slot[id].output);
  update_all(mc_, id);
  
  return uim_scm_t();
}

static uim_lisp
get_input_rule(uim_lisp id_)
{
  int id = C_INT(id_);
  const config::Config::PreeditMethod method = context_slot[id].preedit_method;
  int rule = 0;

  switch (method) {
  case config::Config::ROMAN:
    rule = 0;
    break;
  case config::Config::KANA:
    rule = 1;
    break;
  default:
    rule = 0;
    break;
  }

  return MAKE_INT(rule);
}

static uim_lisp
set_input_rule(uim_lisp mc_, uim_lisp id_, uim_lisp new_rule_)
{
  int id = C_INT(id_);
  config::Config config;
  config::Config::PreeditMethod method;

  switch (C_INT(new_rule_)) {
  case 0:
    method = config::Config::ROMAN;
    break;
  case 1:
    method = config::Config::KANA;
    break;
  default:
    method = config::Config::ROMAN;
    break;
  }

  if (!context_slot[id].session->GetConfig(&config))
    return uim_scm_f();

  config.set_preedit_method(method);

  if (!context_slot[id].session->SetConfig(config))
    return uim_scm_f();

  context_slot[id].preedit_method = method;

  return uim_scm_t();
}

static uim_lisp
reconvert(uim_lisp mc_, uim_lisp id_)
{
  if (!enable_reconversion)
    return uim_scm_f();

  int id = C_INT(id_);
  commands::SessionCommand session_command;
  session_command.set_type(commands::SessionCommand::CONVERT_REVERSE);

  // try selected text first, then primary text
  uim_lisp ustr = uim_scm_callf("im-acquire-text", "oyyiy", mc_, "selection" , "beginning", 0, "full");
  uim_lisp former, latter;
  int use_primary_text = 0;

  if (TRUEP(ustr) &&
      !NULLP(latter = uim_scm_callf("ustr-latter-seq", "o", ustr))) {
    uim_lisp str = CAR(latter);

    string text = REFER_C_STR(str);
    session_command.set_text(text);
  } else {
    ustr = uim_scm_callf("im-acquire-text", "oyyyi", mc_, "primary", "cursor", "line", 0);
    if (TRUEP(ustr) &&
	!NULLP(former = uim_scm_callf("ustr-former-seq", "o", ustr))) {
      uim_lisp str = CAR(former);
      string text = REFER_C_STR(str);
      session_command.set_text(text);
      use_primary_text = 1;
    } else
      return uim_scm_f();
  }

  if (!context_slot[id].session->SendCommand(session_command, context_slot[id].output))
    return uim_scm_f();

  if (use_primary_text)
    uim_scm_callf("im-delete-text", "oyyyi", mc_, "primary", "cursor", "line", 0);
  else
    uim_scm_callf("im-delete-text", "oyyiy", mc_, "selection", "beginning", 0, "full");
  update_all(mc_, id);

  return uim_scm_t();
}

static uim_lisp
submit(uim_lisp mc_, uim_lisp id_)
{
  int id = C_INT(id_);
  commands::SessionCommand command;

  command.set_type(commands::SessionCommand::SUBMIT);
  context_slot[id].session->SendCommand(command, context_slot[id].output);
  update_all(mc_, id);

  return uim_scm_t();
}

} // namespace
} // namespace



void
uim_plugin_instance_init(void)
{
  uim_scm_init_proc1("mozc-lib-alloc-context", mozc::uim::create_context);
  uim_scm_init_proc1("mozc-lib-free-context", mozc::uim::release_context);
  uim_scm_init_proc1("mozc-lib-reset", mozc::uim::reset_context);
  uim_scm_init_proc4("mozc-lib-press-key", mozc::uim::press_key);
  uim_scm_init_proc3("mozc-lib-release-key", mozc::uim::release_key);
  uim_scm_init_proc1("mozc-lib-get-nr-candidates", mozc::uim::get_nr_candidates);
  uim_scm_init_proc2("mozc-lib-get-nth-candidate", mozc::uim::get_nth_candidate);
  uim_scm_init_proc2("mozc-lib-get-nth-label", mozc::uim::get_nth_label);
  uim_scm_init_proc2("mozc-lib-get-nth-annotation", mozc::uim::get_nth_annotation);
  uim_scm_init_proc1("keysym-to-int", mozc::uim::keysym_to_int);
  uim_scm_init_proc1("mozc-lib-input-mode", mozc::uim::get_composition_mode);
  uim_scm_init_proc3("mozc-lib-set-input-mode", mozc::uim::set_composition_mode);
  uim_scm_init_proc1("mozc-lib-set-on", mozc::uim::set_composition_on);
  uim_scm_init_proc1("mozc-lib-has-preedit?", mozc::uim::has_preedit);
  uim_scm_init_proc3("mozc-lib-set-candidate-index", mozc::uim::select_candidate);
  uim_scm_init_proc1("mozc-lib-input-rule", mozc::uim::get_input_rule);
  uim_scm_init_proc3("mozc-lib-set-input-rule", mozc::uim::set_input_rule);
  uim_scm_init_proc2("mozc-lib-reconvert", mozc::uim::reconvert);
  uim_scm_init_proc2("mozc-lib-submit-composition", mozc::uim::submit);

  int argc = 1;
  static const char name[] = "uim-mozc";
  argv = (char **)malloc(sizeof(char *) * 2);
  argv[0] = (char *)name;
  argv[1] =  NULL;

  InitGoogle((const char *)argv[0], &argc, (char ***)&argv, true);
  mozc::uim::install_keymap();
}

void
uim_plugin_instance_quit(void)
{
  mozc::uim::key_map.clear();
  for (int i = 0; i < mozc::uim::nr_contexts; i++) {
    if (mozc::uim::context_slot[i].session) {
      delete mozc::uim::context_slot[i].session;
      delete mozc::uim::context_slot[i].output;
    }
  }
  delete mozc::uim::keyTranslator;
  mozc::uim::keyTranslator = NULL;
  free(argv);
}
