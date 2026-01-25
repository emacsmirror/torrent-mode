;;; torrent-mode.el --- Display torrent files in a tabulated view  -*- lexical-binding: t; -*-

;; Copyright (C) 2023 by Sergey Trofimov
;; SPDX-License-Identifier: Unlicense

;; Author: Sergey Trofimov <sarg@sarg.org.ru>
;; Version: 0.2.1
;; URL: https://github.com/sarg/torrent-mode.el
;; Package-Requires: ((emacs "26.1") (tablist "1.0") (bencoding "1.0"))

;;; Commentary:
;; This package displays torrent files using tablist-mode.

;;; Code:
(require 'tablist)
(require 'bencoding)

(defgroup torrent nil
  "Tablist-based mode to view torrent files."
  :group 'comm
  :prefix "torrent-mode-")

(defcustom torrent-mode-download-function nil
  "Function that starts download of selected files."
  :type 'function
  :group 'torrent)

(defcustom torrent-mode-none-marked-means-all t
  "When no files are marked call download function with empty list."
  :type 'boolean
  :group 'torrent)

(defvar-local torrent-mode--buffer-file-name nil)

(defun torrent-mode-download-selected ()
  "Call user-defined function to download selected items."
  (interactive nil torrent-mode)
  (if torrent-mode-download-function
      (let* ((marked (tablist-get-marked-items nil t))
             (single-mark (eq t (car marked))))
        (when (and torrent-mode-none-marked-means-all
                   (or single-mark (= 1 (length marked))))
          (pop marked))
        (apply torrent-mode-download-function
               torrent-mode--buffer-file-name
               (mapcar #'car marked)))
    (user-error "Download function not defined")))

;;;###autoload
(define-derived-mode torrent-mode tablist-mode
  "torrent"
  "Major mode for torrent files."

  ;; don't save it incidentally
  (setq torrent-mode--buffer-file-name buffer-file-name
        buffer-file-name nil)
  (auto-save-mode -1)
  (set-buffer-multibyte nil)

  (goto-char (point-min))
  (let* ((bencoding-dictionary-type 'hash-table)
         (data (bencoding-read))
         (info (gethash "info" data))
         (files (or (gethash "files" info) (list info)))
         (sortfun
          (lambda (n)
            (lambda (A B) (< (get-text-property 0 'sortval (aref (nth 1 A) n))
                             (get-text-property 0 'sortval (aref (nth 1 B) n)))))))

    (setq tabulated-list-entries
          (seq-map-indexed
           (lambda (file index)
             (let* ((size (gethash "length" file))
                    (name (decode-coding-string
                           (string-join (or (gethash "path.utf-8" file)
                                            (gethash "path" file)
                                            (list (or (gethash "name.utf-8" file)
                                                      (gethash "name" file))))
                                        "/")
                           'utf-8)))

               (list index
                     (vector (propertize (number-to-string (1+ index)) 'sortval index)
                             (propertize (file-size-human-readable size) 'sortval size)
                             name))))
           files))

    (setq tabulated-list-format
          (vector `("Idx" 4 ,(funcall sortfun 0) . (:right-align t))
                  `("Size" 6 ,(funcall sortfun 1) . (:right-align t))
                  `("Name" 80 t))
          tabulated-list-padding 3
          tabulated-list-sort-key '("Idx")))

  (define-key torrent-mode-map
              [remap tablist-do-delete]
              #'torrent-mode-download-selected)

  (set-buffer-multibyte t)
  (tabulated-list-init-header)
  (tabulated-list-print)
  (hl-line-mode))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.torrent\\'" . torrent-mode))

(provide 'torrent-mode)
;;; torrent-mode.el ends here
