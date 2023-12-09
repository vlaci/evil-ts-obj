;;; evil-ts-obj-bash.el --- Bash setting for evil-ts-obj -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2023 Denis Zubarev
;;
;; Author: Denis Zubarev <dvzubarev@yandex.ru>
;; Maintainer: Denis Zubarev <dvzubarev@yandex.ru>
;; Version: 0.0.1
;; Keywords: convenience tools
;; Package-Requires: ((emacs "30.0.50"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;;  bash setting for evil-ts-obj
;;
;;; Code:

(require 'treesit)
(require 'evil-ts-obj-conf)
(require 'evil-ts-obj-core)

(defcustom evil-ts-obj-bash-compound-nodes
  '("function_definition"
    "if_statement"
    "elif_clause"
    "else_clause"
    "while_statement"
    "for_statement"
    "c_style_for_statement"
    "case_statement"
    "list")
  "Nodes that designate compound statement in bash."
  :type '(repeat string)
  :group 'evil-ts-obj)

(defun evil-ts-obj-bash-compound-pred (node)
  "Predicate for detecting compound thing, represented by `NODE'.
For list node,
it returns t only for the furthest parent of the same type."
  (let ((node-type (treesit-node-type node)))
    (if (equal node-type "list")
        (not (equal node-type (treesit-node-type (treesit-node-parent node))))
      t)))


(defcustom evil-ts-obj-bash-statement-nodes
  '("command"
    "unset_command"
    "test_command"
    "declaration_command"
    "variable_assignment"
    "redirected_statement"
    "pipeline")
  "Nodes that designate simple statement in bash."
  :type '(repeat string)
  :group 'evil-ts-obj)



(defun evil-ts-obj-bash-param-pred (node)
  "Predicate for detecting param thing.
Return t if `NODE' is a node that represents a parameter."
  (equal (treesit-node-field-name node) "argument"))

(defcustom evil-ts-obj-bash-things
  `((compound ,(cons (evil-ts-obj-conf--make-nodes-regex evil-ts-obj-bash-compound-nodes)
                     #'evil-ts-obj-bash-compound-pred))
     (statement ,(evil-ts-obj-conf--make-nodes-regex evil-ts-obj-bash-statement-nodes))
     (param evil-ts-obj-bash-param-pred))
  "Things for bash."
  :type 'repeate
  :group 'evil-ts-obj)


(defcustom evil-ts-obj-bash-statement-seps
  '("|" ";")
  "Separators for bash statement."
  :type '(repeat string)
  :group 'evil-ts-obj)

(defun evil-ts-obj-bash-extract-compound-inner (node)
  "Return range for a compound inner text object.
Compound is represented by a `NODE'."
  (let (first-child last-child)
    (pcase (treesit-node-type node)
      ((or "function_definition"
           "while_statement"
           "for_statement"
           "c_style_for_statement")
       (when-let ((body-node (treesit-node-child-by-field-name node "body")))
         (setq first-child (treesit-node-child body-node 0 t)
               last-child (treesit-node-child body-node -1 t))))
      ("if_statement"
                                        ;skip condition node
       (setq first-child (treesit-node-child node 1 t))
       ;; run till we are not on  elif_clause or else_clause
       (when-let* ((all-children (treesit-node-children node t))
                   (if-children (seq-take-while
                                 (lambda (n) (not (member (treesit-node-type n)
                                                          '("elif_clause" "else_clause"))))
                                 all-children)))
         (setq last-child (car (last if-children)))))
      ((or "elif_clause" "case_statement" "else_clause")
       (let ((first-child-idx (if (equal (treesit-node-type node) "else_clause")
                                  0
                                1)))
                                        ;skip condition node
         (setq first-child (treesit-node-child node first-child-idx t)
               last-child (treesit-node-child node -1 t)))))
    (when (and first-child last-child)
      (list (treesit-node-start first-child)
            (treesit-node-end last-child)))))

(defun evil-ts-obj-bash-statement-ext (node)
  (when-let* ((next-sibl (treesit-node-next-sibling node))
              ((equal (treesit-node-type next-sibl) ";")))
    (list (treesit-node-start node)
          (treesit-node-end next-sibl))))

(defun evil-ts-obj-bash-param-upper (node)
  (let ((start-pos (treesit-node-start node))
               (end-pos (treesit-node-end node)))
    (when-let (next-sibling (treesit-node-next-sibling node t))
      (setq end-pos (treesit-node-start next-sibling)))

    (let ((final-sibling node))
      (while (and (setq node (treesit-node-prev-sibling node t))
                  (not (equal (treesit-node-type node) "command_name")))
        (setq final-sibling node))
      (setq start-pos (treesit-node-start final-sibling)))
    (list start-pos end-pos)))

(defun evil-ts-obj-bash-ext-func (spec node)
  "Main extension function for bash. TODO spec"

  (pcase spec
    ((pmap (:thing 'compound) (:text-obj 'inner))
     (evil-ts-obj-bash-extract-compound-inner node))
    ((pmap (:thing 'statement) (:text-obj 'outer))
     (evil-ts-obj-bash-statement-ext node))
    ((pmap (:thing 'param) (:text-obj 'outer))
     (evil-ts-obj-param-outer-mod node))
    ((pmap (:thing 'param) (:text-obj 'upper))
     (evil-ts-obj-bash-param-upper node))))


;;;###autoload
(defun evil-ts-obj-bash-setup-things ()
  "Set all variables needed by evil-ts-obj-core."
  (make-local-variable 'treesit-thing-settings)
  (cl-callf append (alist-get 'bash treesit-thing-settings)
    evil-ts-obj-bash-things)

  (cl-callf plist-put evil-ts-obj-conf-thing-modifiers
   'bash #'evil-ts-obj-bash-ext-func)

  (cl-callf plist-put evil-ts-obj-conf-sep-regexps
    'bash (evil-ts-obj-conf--make-nodes-regex
           evil-ts-obj-bash-statement-seps))

  (cl-callf plist-put evil-ts-obj-conf-nav-things
    'bash '(or param statement compound)))



(provide 'evil-ts-obj-bash)
;;; evil-ts-obj-bash.el ends here
