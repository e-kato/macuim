;;;
;;; Copyright (c) 2010 uim Project http://code.google.com/p/uim/
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

(require "i18n.scm")

(define mozc-im-name-label (N_ "Mozc"))
(define mozc-im-short-desc (N_ "Mozc Japanese engine"))

(define-custom-group 'mozc
		     (ugettext mozc-im-name-label)
		     (ugettext mozc-im-short-desc))

;;
;; segment separator
;;

(define-custom 'mozc-show-segment-separator? #f
  '(mozc segment-sep)
  '(boolean)
  (N_ "Show segment separator")
  (N_ "long description will be here."))

(define-custom 'mozc-segment-separator "|"
  '(mozc segment-sep)
  '(string ".*")
  (N_ "Segment separator")
  (N_ "long description will be here."))

(custom-add-hook 'mozc-segment-separator
                 'custom-activity-hooks
                 (lambda ()
                   mozc-show-segment-separator?))

;;
;; toolbar
;;

;; Can't be unified with action definitions in mozc.scm until uim
;; 0.4.6.
(define mozc-input-mode-indication-alist
  (list
   (list 'action_mozc_direct
	 'ja_direct
	 "-"
	 (N_ "Direct input")
	 (N_ "Direct input mode"))
   (list 'action_mozc_hiragana
	 'ja_hiragana
	 "あ"
	 (N_ "Hiragana")
	 (N_ "Hiragana input mode"))
   (list 'action_mozc_katakana
	 'ja_katakana
	 "ア"
	 (N_ "Katakana")
	 (N_ "Katakana input mode"))
   (list 'action_mozc_halfkana
	 'ja_halfkana
	 "ｱ"
	 (N_ "Halfwidth Katakana")
	 (N_ "Halfwidth Katakana input mode"))
   (list 'action_mozc_halfwidth_alnum
	 'ja_halfwidth_alnum
	 "a"
	 (N_ "Halfwidth Alphanumeric")
	 (N_ "Halfwidth Alphanumeric input mode"))
   (list 'action_mozc_fullwidth_alnum
	 'ja_fullwidth_alnum
	 "Ａ"
	 (N_ "Fullwidth Alphanumeric")
	 (N_ "Fullwidth Alphanumeric input mode"))))


;;; Buttons

(define-custom 'mozc-widgets '(widget_mozc_input_mode)
  '(mozc toolbar)
  (list 'ordered-list
	(list 'widget_mozc_input_mode
	      (_ "Input mode")
	      (_ "Input mode")))
  (_ "Enabled toolbar buttons")
  (_ "long description will be here."))

;; dynamic reconfiguration
;; mozc-configure-widgets is not defined at this point. So wrapping
;; into lambda.
(custom-add-hook 'mozc-widgets
		 'custom-set-hooks
		 (lambda ()
		   (mozc-configure-widgets)))


;;; Input mode

(define-custom 'default-widget_mozc_input_mode 'action_mozc_direct
  '(mozc toolbar)
  (cons 'choice
	(map indication-alist-entry-extract-choice
	     mozc-input-mode-indication-alist))
  (_ "Default input mode")
  (_ "long description will be here."))

(define-custom 'mozc-input-mode-actions
	       (map car mozc-input-mode-indication-alist)
  '(mozc toolbar)
  (cons 'ordered-list
	(map indication-alist-entry-extract-choice
	     mozc-input-mode-indication-alist))
  (_ "Input mode menu items")
  (_ "long description will be here."))

;; value dependency
(if custom-full-featured?
    (custom-add-hook 'mozc-input-mode-actions
		     'custom-set-hooks
		     (lambda ()
		       (custom-choice-range-reflect-olist-val
			'default-widget_mozc_input_mode
			'mozc-input-mode-actions
			mozc-input-mode-indication-alist))))

;; activity dependency
(custom-add-hook 'default-widget_mozc_input_mode
		 'custom-activity-hooks
		 (lambda ()
		   (memq 'widget_mozc_input_mode mozc-widgets)))

(custom-add-hook 'mozc-input-mode-actions
		 'custom-activity-hooks
		 (lambda ()
		   (memq 'widget_mozc_input_mode mozc-widgets)))

;; dynamic reconfiguration
(custom-add-hook 'default-widget_mozc_input_mode
		 'custom-set-hooks
		 (lambda ()
		   (mozc-configure-widgets)))

(custom-add-hook 'mozc-input-mode-actions
		 'custom-set-hooks
		 (lambda ()
		   (mozc-configure-widgets)))

(define-custom 'mozc-use-with-vi? #f
  '(mozc special-op)
  '(boolean)
  (N_ "Enable vi-cooperative mode")
  (N_ "long description will be here."))

  
