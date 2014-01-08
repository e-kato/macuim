;;;
;;; Copyright (c) 2010-2012 uim Project http://code.google.com/p/uim/
;;;
;;; All rights reserved.
;;;
;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions
;;; are met:
;;; 1. Redistributions of source code must retain the above copyright
;;;    notice, this list of conditions and the following disclaimer.
;;; 2. Redistributions in binary form must reproduce the above copyright
;;;    notice, this list of conditions and the following disclaimer in the
;;;    documentation and/or other materials provided with the distribution.
;;; 3. Neither the name of authors nor the names of its contributors
;;;    may be used to endorse or promote products derived from this software
;;;    without specific prior written permission.
;;;
;;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS IS'' AND
;;; ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;; ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE
;;; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;;; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
;;; OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
;;; HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
;;; LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
;;; OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
;;; SUCH DAMAGE.
;;;;

(require "util.scm")
(require "process.scm")
(require "japanese.scm")
(require "ustr.scm")
(require-custom "generic-key-custom.scm")
(require-custom "mozc-custom.scm")
(require-custom "mozc-key-custom.scm")

;;; implementations

(define mozc-type-direct          ja-type-direct)
(define mozc-type-hiragana        ja-type-hiragana)
(define mozc-type-katakana        ja-type-katakana)
(define mozc-type-halfkana        ja-type-halfkana)
(define mozc-type-halfwidth-alnum ja-type-halfwidth-alnum)
(define mozc-type-fullwidth-alnum ja-type-fullwidth-alnum)

(define mozc-input-rule-roma 0)
(define mozc-input-rule-kana 1)

(define mozc-prepare-input-mode-activation
  (lambda (mc new-mode)
    (let ((mid (mozc-context-mc-id mc)))
      (if mid
        (mozc-lib-set-input-mode mc mid new-mode)
        #f))))

(define mozc-prepare-input-rule-activation
  (lambda (mc new-rule)
    (let ((mid (mozc-context-mc-id mc)))
      (if mid
        (mozc-lib-set-input-rule mc mid new-rule)
        #f))))

(define (mozc-run-process file . args)
  (let-optionals* args ((argv (list file)))
    (let ((pid (process-fork)))
      (cond ((< pid 0)
             (begin
               (uim-notify-fatal (N_ "cannot fork"))
               #f))
            ((= 0 pid) ;; child
             (let ((pid2 (process-fork)))
               (cond ((< pid2 0)
                      (begin
                        (uim-notify-fatal (N_ "cannot fork"))
                        #f))
                     ((= 0 pid2)
                      (setenv "MALLOC_CHECK_" "0" 0)
                      (setenv "GTK_IM_MODULE" "gtk-im-context-simple" 0)
                      (if (= (process-execute file argv) -1)
                        (uim-notify-fatal (format (N_ "cannot execute ~a") file)))
                      (_exit 0))
                     (else
                       (_exit 0)))))
            (else
              (process-waitpid pid 0)
              pid)))))

(define mozc-tool-activate
  (lambda (mc option)
    (case option
      ((mozc-tool-about-dialog)
       (mozc-run-process mozc-tool-about-dialog-cmd (list mozc-tool-about-dialog-cmd mozc-tool-about-dialog-cmd-option)))
      ((mozc-tool-config-dialog)
       (mozc-run-process mozc-tool-config-dialog-cmd (list mozc-tool-config-dialog-cmd mozc-tool-config-dialog-cmd-option)))
      ((mozc-tool-dictionary-tool)
       (mozc-run-process mozc-tool-dictionary-tool-cmd (list mozc-tool-dictionary-tool-cmd mozc-tool-dictionary-tool-cmd-option)))
      ((mozc-tool-word-register-dialog)
       (mozc-run-process mozc-tool-word-register-dialog-cmd (list mozc-tool-word-register-dialog-cmd mozc-tool-word-register-dialog-cmd-option)))
      ((mozc-tool-character-palette)
       (mozc-run-process mozc-tool-character-palette-cmd (list mozc-tool-character-palette-cmd mozc-tool-character-palette-cmd-option)))
      ((mozc-tool-hand-writing)
       (mozc-run-process mozc-tool-hand-writing-cmd (list mozc-tool-hand-writing-cmd mozc-tool-hand-writing-cmd-option)))
      (else
        #f))))

(define mozc-reconvert
  (lambda (mc)
    (let ((mid (mozc-context-mc-id mc)))
      (if mid
        (begin
          (if (not (mozc-context-on mc))
            (begin
              (mozc-lib-set-on mid)
              (mozc-context-set-on! mc #t)))
          (mozc-lib-reconvert mc mid))
        #f))))

(register-action 'action_mozc_hiragana
		 (lambda (mc) ;; indication handler
                   '(ja_hiragana
                      "あ"
                      "ひらがな"
                      "ひらがな入力モード"))
		 (lambda (mc) ;; activity predicate
                   (and
                     (mozc-context-mc-id mc)
                     (mozc-context-on mc)
		     (= (mozc-lib-input-mode (mozc-context-mc-id mc)) mozc-type-hiragana)))
		 (lambda (mc) ;; action handler
                   (mozc-prepare-input-mode-activation mc mozc-type-hiragana)))

(register-action 'action_mozc_katakana
		 (lambda (mc)
                   '(ja_katakana
                      "ア"
                      "カタカナ"
                      "カタカナ入力モード"))
		 (lambda (mc)
                   (and
                     (mozc-context-mc-id mc)
                     (mozc-context-on mc)
		     (= (mozc-lib-input-mode (mozc-context-mc-id mc)) mozc-type-katakana)))
		 (lambda (mc)
                   (mozc-prepare-input-mode-activation mc mozc-type-katakana)))

(register-action 'action_mozc_halfkana
		 (lambda (mc)
                   '(ja_halfkana
                      "ｱ"
                      "半角カタカナ"
                      "半角カタカナ入力モード"))
		 (lambda (mc)
                   (and
                     (mozc-context-mc-id mc)
                     (mozc-context-on mc)
		     (= (mozc-lib-input-mode (mozc-context-mc-id mc)) mozc-type-halfkana)))
		 (lambda (mc)
                   (mozc-prepare-input-mode-activation mc mozc-type-halfkana)))

(register-action 'action_mozc_halfwidth_alnum
		 (lambda (mc)
                   '(ja_halfwidth_alnum
                      "a"
                      "半角英数"
                      "半角英数入力モード"))
		 (lambda (mc)
                   (and
                     (mozc-context-mc-id mc)
                     (mozc-context-on mc)
		     (= (mozc-lib-input-mode (mozc-context-mc-id mc)) mozc-type-halfwidth-alnum)))
		 (lambda (mc)
                   (mozc-prepare-input-mode-activation mc mozc-type-halfwidth-alnum)))

(register-action 'action_mozc_direct
		 (lambda (mc)
                   '(ja_direct
                      "-"
                      "直接入力"
                      "直接(無変換)入力モード"))
		 (lambda (mc)
		   (not (mozc-context-on mc)))
		 (lambda (mc)
                   (mozc-prepare-input-mode-activation mc mozc-type-direct)))

(register-action 'action_mozc_fullwidth_alnum
		 (lambda (mc)
                   '(ja_fullwidth_alnum
                      "Ａ"
                      "全角英数"
                      "全角英数入力モード"))
		 (lambda (mc)
                   (and
                     (mozc-context-mc-id mc)
                     (mozc-context-on mc)
                     (= (mozc-lib-input-mode (mozc-context-mc-id mc)) mozc-type-fullwidth-alnum)))
		 (lambda (mc)
                   (mozc-prepare-input-mode-activation mc mozc-type-fullwidth-alnum)))

(register-action 'action_mozc_roma
;;               (indication-alist-indicator 'action_mozc_roma
;;                                           mozc-kana-input-method-indication-alist)
                 (lambda (mc)
                   '(ja_romaji
                     "Ｒ"
                     "ローマ字"
                     "ローマ字入力モード"))
                 (lambda (mc)
                   (and (mozc-context-mc-id mc)
                        (= (mozc-lib-input-rule (mozc-context-mc-id mc))
                           mozc-input-rule-roma)))
                 (lambda (mc)
                   (mozc-prepare-input-rule-activation mc mozc-input-rule-roma)
))

(register-action 'action_mozc_kana
;;               (indication-alist-indicator 'action_mozc_kana
;;                                           mozc-kana-input-method-indication-alist)
                 (lambda (mc)
                   '(ja_kana
                     "か"
                     "かな"
                     "かな入力モード"))
                 (lambda (mc)
                   (and (mozc-context-mc-id mc)
                        (= (mozc-lib-input-rule (mozc-context-mc-id mc))
                           mozc-input-rule-kana)))
                 (lambda (mc)
                   (mozc-prepare-input-rule-activation mc mozc-input-rule-kana)
                   ))

(register-action 'action_mozc_tool_selector
;;               (indication-alist-indicator 'action_mozc_tool_selector
;;                                           mozc-tool-indication-alist)
                 (lambda (mc)
                   '(mozc_tool_selector
                     "M"
                     "MozcTool selector"
                     "MozcTool selector"))
                 (lambda (mc)
                   #t)
                 (lambda (mc)
                   #f))

(register-action 'action_mozc_tool_about_dialog
;;               (indication-alist-indicator 'action_mozc_tool_about_dialog
;;                                           mozc-tool-indication-alist)
                 (lambda (mc)
                   '(mozc_tool_about_dialog
                     "A"
                     "About"
                     "About Mozc"))
                 (lambda (mc)
                   #f)
                 (lambda (mc)
                   (mozc-tool-activate mc 'mozc-tool-about-dialog)))

(register-action 'action_mozc_tool_config_dialog
;;               (indication-alist-indicator 'action_mozc_tool_config_dialog
;;                                           mozc-tool-indication-alist)
                 (lambda (mc)
                   '(mozc_tool_config_dialog
                     "C"
                     "Config dialog"
                     "Config dialog"))
                 (lambda (mc)
                   #f)
                 (lambda (mc)
                   (mozc-tool-activate mc 'mozc-tool-config-dialog)))

(register-action 'action_mozc_tool_dictionary_tool
;;               (indication-alist-indicator 'action_mozc_tool_dictionary_tool
;;                                           mozc-tool-indication-alist)
                 (lambda (mc)
                   '(mozc_tool_dictionary_tool
                     "D"
                     "Dictionary tool"
                     "Dictionary tool"))
                 (lambda (mc)
                   #f)
                 (lambda (mc)
                   (mozc-tool-activate mc 'mozc-tool-dictionary-tool)))

(register-action 'action_mozc_tool_word_register_dialog
;;               (indication-alist-indicator 'action_mozc_tool_word_register_dialog
;;                                           mozc-tool-indication-alist)
                 (lambda (mc)
                   '(mozc_tool_word_register_dialog
                     "W"
                     "Word register dialog"
                     "Word register dialog"))
                 (lambda (mc)
                   #f)
                 (lambda (mc)
                   (mozc-tool-activate mc 'mozc-tool-word-register-dialog)))

(register-action 'action_mozc_tool_character_palette
;;               (indication-alist-indicator 'action_mozc_tool_character_palette
;;                                           mozc-tool-indication-alist)
                 (lambda (mc)
                   '(mozc_tool_character_palette
                     "W"
                     "Character palette"
                     "Character palette"))
                 (lambda (mc)
                   #f)
                 (lambda (mc)
                   (mozc-tool-activate mc 'mozc-tool-character-palette)))

(register-action 'action_mozc_tool_hand_writing
;;               (indication-alist-indicator 'action_mozc_tool_hand_writing
;;                                           mozc-tool-indication-alist)
                 (lambda (mc)
                   '(mozc_tool_hand_writing
                     "W"
                     "Hand writing"
                     "Hand writing"))
                 (lambda (mc)
                   #f)
                 (lambda (mc)
                   (mozc-tool-activate mc 'mozc-tool-hand-writing)))

(register-action 'action_mozc_reconvert
;;               (indication-alist-indicator 'action_mozc_reconvert
;;                                           mozc-tool-indication-alist)
                 (lambda (mc)
                   '(mozc_reconvert
                     "R"
                     "Reconvert"
                     "Reconvert"))
                 (lambda (mc)
                   #f)
                 (lambda (mc)
                   (mozc-reconvert mc)))

;; Update widget definitions based on action configurations. The
;; procedure is needed for on-the-fly reconfiguration involving the
;; custom API
(define mozc-configure-widgets
  (lambda ()
    (register-widget 'widget_mozc_input_mode
		     (activity-indicator-new mozc-input-mode-actions)
		     (actions-new mozc-input-mode-actions))
    (register-widget 'widget_mozc_kana_input_method
		     (activity-indicator-new mozc-kana-input-method-actions)
		     (actions-new mozc-kana-input-method-actions))
    (register-widget 'widget_mozc_tool
		     (activity-indicator-new mozc-tool-actions)
		     (actions-new (remove (lambda (x) (eq? x 'action_mozc_tool_selector)) mozc-tool-actions)))
    (context-list-replace-widgets! 'mozc mozc-widgets)))

(define mozc-context-rec-spec
  (append
   context-rec-spec
   ;; renamed from 'id' to avoid conflict with context-id
   (list
     (list 'mc-id             #f)
     (list 'on                #f))))
(define-record 'mozc-context mozc-context-rec-spec)
(define mozc-context-new-internal mozc-context-new)

(define mozc-context-new
  (lambda (id im name)
    (let* ((mc (mozc-context-new-internal id im))
           (mid (if (symbol-bound? 'mozc-lib-alloc-context)
                    (if (= (getuid) 0)
                        #f
                        (mozc-lib-alloc-context mc))
                    (begin
                      (uim-notify-info
                       (N_ "libuim-mozc.so couldn't be loaded"))
                      #f))))
      (mozc-context-set-widgets! mc mozc-widgets)
      (mozc-context-set-mc-id! mc mid)
      mc)))

(define mozc-separator
  (lambda ()
    (let ((attr (bitwise-ior preedit-separator
                             preedit-underline)))
      (if mozc-show-segment-separator?
        (cons attr mozc-segment-separator)
        #f))))

(define mozc-proc-direct-state
  (lambda (mc key key-state)
   (if (mozc-on-key? key key-state)
     (let ((mid (mozc-context-mc-id mc)))
       (if mid
         (mozc-lib-set-on mid))
       (mozc-context-set-on! mc #t))
     (im-commit-raw mc))))

(define mozc-init-handler
  (lambda (id im arg)
    (mozc-context-new id im arg)))

(define mozc-release-handler
  (lambda (mc)
    (let ((mid (mozc-context-mc-id mc)))
      (if mid
        (mozc-lib-free-context mid)
        #f)
    #f)))

(define mozc-transpose-keys
  (lambda (mid key key-state)
    (let ((new (cons key key-state)))
      ;; Since mozc_tool is now available, these key transposings
      ;; are not needed usually.
      ;;(if (mozc-lib-has-preedit? mid)
      ;;  (cond
      ;;    ((mozc-cancel-key? key key-state)
      ;;     (set-car! new 'escape)
      ;;     (set-cdr! new 0))
      ;;    ((mozc-prev-segment-key? key key-state)
      ;;     (set-car! new 'left)
      ;;     (set-cdr! new 0))))
      new)))

(define mozc-kana-toggle
  (lambda (mc mid)
    (if mid
      (let ((mode (mozc-lib-input-mode mid)))
        (cond
          ((= mode mozc-type-hiragana)
           (mozc-lib-set-input-mode mc mid mozc-type-katakana))
          ((= mode mozc-type-katakana)
           (mozc-lib-set-input-mode mc mid mozc-type-hiragana))
          (else
            #f)))
      #f)))

(define mozc-proc-input-state
  (lambda (mc key key-state)
    (if (ichar-control? key)
      (im-commit-raw mc)
      (let ((mid (mozc-context-mc-id mc)))
        (cond
          ((and
             mid
             (mozc-off-key? key key-state)
             (not (mozc-lib-has-preedit? mid)))
           (mozc-lib-set-input-mode mc mid mozc-type-direct))
          ;; non available modifiers on Mozc
          ((or
             (meta-key-mask key-state)
             (super-key-mask key-state)
             (hyper-key-mask key-state))
           (if (and mid
                    (mozc-lib-has-preedit? mid))
             #f ;; ignore
             (im-commit-raw mc))) ;; pass through
          (else
            (or
              (and
                (mozc-kana-toggle-key? key key-state)
                (mozc-kana-toggle mc mid))
              (let* ((new (mozc-transpose-keys mid key key-state))
                     (nkey (car new))
                     (nkey-state (cdr new)))
                (if (and mid
                         (mozc-lib-press-key mc mid (if (symbol? nkey)
                                                      (keysym-to-int nkey) nkey)
                                             nkey-state))
                  #f ; Key event is consumed
                  (begin
                    (and mid
                         mozc-use-with-vi?
                         (mozc-vi-escape-key? key key-state)
                         (mozc-lib-set-input-mode mc mid mozc-type-direct))
                    (im-commit-raw mc)))))))))))

(define mozc-press-key-handler
  (lambda (mc key key-state)
    (if (mozc-context-on mc)
      (mozc-proc-input-state mc key key-state)
      (mozc-proc-direct-state mc key key-state))))

(define mozc-release-key-handler
  (lambda (mc key key-state)
    (if (or (ichar-control? key)
            (not (mozc-context-on mc)))
      (im-commit-raw mc))))

(define mozc-reset-handler
  (lambda (mc)
    (let ((mid (mozc-context-mc-id mc)))
      (and mid
           (mozc-lib-reset mid)))))

(define mozc-focus-in-handler
  (lambda (mc)
    (let ((mid (mozc-context-mc-id mc)))
      ;(mozc-lib-focus-in mid)
      )))

(define mozc-focus-out-handler
  (lambda (mc)
    (let ((mid (mozc-context-mc-id mc)))
      ;(mozc-lib-focus-out mid)
      )))

(define mozc-displace-handler
  (lambda (mc)
    (let ((mid (mozc-context-mc-id mc)))
      (and mid
           (mozc-lib-submit-composition mc mid)))))

(define mozc-get-candidate-handler
  (lambda (mc idx accel-enum-hint)
    (let* ((mid (mozc-context-mc-id mc))
	   (cand
             (mozc-lib-get-nth-candidate mid idx))
           (label
             (mozc-lib-get-nth-label mid idx))
           (annotation
             (mozc-lib-get-nth-annotation mid idx)))
      (list cand label annotation))))

(define mozc-set-candidate-index-handler
  (lambda (mc idx)
    (let ((mid (mozc-context-mc-id mc)))
      (mozc-lib-set-candidate-index mc mid idx))))

(define mozc-check-uim-version
  (lambda (request-major request-minor request-patch)
    (let* ((version (string-split (uim-version) "."))
           (len (length version))
           (major (if (>= len 1) (string->number (list-ref version 0)) 0))
           (minor (if (>= len 2) (string->number (list-ref version 1)) 0))
           (patch (if (>= len 3) (string->number (list-ref version 2)) 0)))
      (or (> major request-major)
          (and
            (= major request-major)
            (> minor request-minor))
          (and
            (= major request-major)
            (= minor request-minor)
            (>= patch request-patch))))))

(mozc-configure-widgets)

(register-im
  'mozc
  "ja"
  "UTF-8"
  mozc-im-name-label
  mozc-im-short-desc
  #f
  mozc-init-handler
  mozc-release-handler
  context-mode-handler
  mozc-press-key-handler
  mozc-release-key-handler
  mozc-reset-handler
  mozc-get-candidate-handler
  mozc-set-candidate-index-handler
  context-prop-activate-handler
  #f
  #f ;mozc-focus-in-handler
  #f ;mozc-focus-out-handler
  #f
  mozc-displace-handler
)
