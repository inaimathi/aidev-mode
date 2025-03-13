;;; aidev-mode.el --- AI-assisted development tools for Emacs -*- lexical-binding: t; -*-

;; Copyright (C) 2025 inaimathi

;; Author: inaimathi <leo.zovic@example.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: tools, convenience, ai
;; URL: https://github.com/yourusername/aidev-mode

;;; Commentary:

;; This package provides AI-assisted development tools for Emacs,
;; leveraging language models like Ollama, OpenAI, and Claude to help
;; with code generation, refactoring, and other programming tasks.

;;; Code:

(require 'request)
(require 'json)
(require 'url)

(defgroup aidev nil
  "AI-assisted development tools for Emacs."
  :prefix "aidev-"
  :group 'tools)

(defcustom aidev-default-model "deepseek-coder-v2:latest"
  "Default model to use for AI services."
  :type 'string
  :group 'aidev)

(defcustom aidev-provider 'claude
  "The AI service provider to use."
  :type '(choice
          (const :tag "Ollama" ollama)
          (const :tag "OpenAI" openai)
          (const :tag "Claude" claude))
  :group 'aidev)

(defcustom aidev-ollama-url nil
  "URL for the Ollama service."
  :type '(choice (string :tag "URL")
                (const :tag "Auto-detect" nil))
  :group 'aidev)

(defvar aidev-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-a i") 'aidev-insert-chat)
    (define-key map (kbd "C-c C-a r") 'aidev-refactor-region-with-chat)
    (define-key map (kbd "C-c C-a b") 'aidev-refactor-buffer-with-chat)
    (define-key map (kbd "C-c C-a n") 'aidev-new-buffer-from-chat)
    (define-key map (kbd "C-c C-a c") 'aidev-start-chat)
    map)
  "Keymap for `aidev-mode'.")

;;;###autoload
;; Define a keymap for the chat buffer
(defvar aidev-chat-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") 'aidev-chat-send-buffer-contents)
    map)
  "Keymap for AI chat buffer.")

;; Define a minor mode specifically for the chat buffer
(define-minor-mode aidev-chat-mode
  "Minor mode for AI chat buffers."
  :init-value nil
  :lighter " AI-Chat"
  :keymap aidev-chat-mode-map
  :group 'aidev-chat)

(define-minor-mode aidev-mode
  "Minor mode for AI-assisted development."
  :init-value nil
  :lighter " AIdev"
  :keymap aidev-mode-map
  :group 'aidev
  (if aidev-mode
      (message "AIdev mode enabled")
    (message "AIdev mode disabled")))

(define-globalized-minor-mode aidev-global-mode aidev-mode (lambda () (aidev-mode 1)))

(defun aidev-insert-chat (prompt)
  "Insert AI-generated content based on PROMPT at point."
  (interactive "sPrompt: ")
  (let* ((system (aidev--prepare-system-message
                  "The likeliest requests involve generating code. If you are asked to generate code, only return code, and no commentary. If you must, provide minor points and/or testing examples in the form of code comments (commented in the appropriate syntax) but no longer prose unless explicitly requested."))
         (prompt (aidev--prepare-prompt prompt t)))
    (insert (aidev--invert-markdown-code (aidev--chat system prompt)))))

(defun aidev-refactor-region-with-chat (prompt)
  "Refactors the current region using `aidev--chat` function and a PROMPT."
  (interactive "sPrompt: ")
  (when (use-region-p)
    (let* ((system (aidev--prepare-system-message
                    "The user wants you to help them refactor a piece of code they've already written. Unless specified by their prompt, you should output code in the same language as the input code. Output absolutely nothing but code; the message you return should be a drop-in replacement for the code the user needs help with."))
           (prompt (aidev--prepare-prompt prompt t))
           (data (aidev--chat system prompt))
           (reg-start (region-beginning))
           (reg-end (region-end)))
      (goto-char reg-start)
      (delete-region reg-start reg-end)
      (insert (aidev--invert-markdown-code data)))))

(defun aidev-refactor-buffer-with-chat (prompt)
  "Refactors the current buffer using `aidev--chat` function and a PROMPT."
  (interactive "sPrompt: ")
  (let* ((system (aidev--prepare-system-message
                  "The user wants you to help them refactor a piece of code they've already written. Unless specified by their prompt, you should output code in the same language as the input code. Output absolutely nothing but code; the message you return should be a drop-in replacement for the code the user needs help with."))
         (prompt (aidev--prepare-prompt prompt))
         (data (aidev--chat system prompt)))
    (delete-region (point-min) (point-max))
    (insert (aidev--invert-markdown-code data))))

(defun aidev-new-buffer-from-chat (prompt)
  "Creates a new buffer with the result of a chat request using PROMPT."
  (interactive "sPrompt: ")
  (let* ((system (aidev--prepare-system-message
                  "The likeliest requests involve generating code. If you are asked to generate code, only return code, and no commentary. If you must, provide minor points and/or testing examples in the form of code comments (commented in the appropriate syntax) but no longer prose unless explicitly requested."))
         (messages (aidev--prepare-prompt prompt t))
         (result (aidev--chat system messages))
         (new-buffer (generate-new-buffer "*AI Generated Code*")))
    (with-current-buffer new-buffer
      (when (fboundp 'major-mode)
        (funcall major-mode))
      (insert (aidev--invert-markdown-code result)))
    (switch-to-buffer new-buffer)))

(defgroup aidev-chat nil
  "Settings for AI chat functionality."
  :group 'aidev)

(defcustom aidev-chat-system-prompt
  "You are a helpful assistant. Respond concisely and helpfully to the user's messages."
  "Default system prompt for chat sessions."
  :type 'string
  :group 'aidev-chat)

(defcustom aidev-chat-buffer-name "*AIdev Chat*"
  "Default name for the chat buffer."
  :type 'string
  :group 'aidev-chat)

(defcustom aidev-chat-user-prompt-prefix "User: "
  "Prefix for user messages in the chat buffer."
  :type 'string
  :group 'aidev-chat)

(defcustom aidev-chat-ai-response-prefix "AI: "
  "Prefix for AI responses in the chat buffer."
  :type 'string
  :group 'aidev-chat)

(defcustom aidev-chat-separator "\n\n"
  "Separator between chat messages."
  :type 'string
  :group 'aidev-chat)

(defvar-local aidev-chat-messages nil
  "List of messages in the current chat session.")

(defvar-local aidev-chat-system-prompt-used nil
  "System prompt used in the current chat session.")

(defun aidev-start-chat (prompt)
  "Start a new chat session with the AI using PROMPT as the initial message."
  (interactive "sStart chat with: ")
  (let ((buffer (get-buffer-create aidev-chat-buffer-name)))
    (with-current-buffer buffer
      (text-mode)
      (erase-buffer)
      (setq aidev-chat-messages nil)
      (setq aidev-chat-system-prompt-used aidev-chat-system-prompt)
      (insert aidev-chat-user-prompt-prefix prompt aidev-chat-separator)
      (aidev-chat-mode 1)
      (aidev-chat-send-message prompt))
    (switch-to-buffer buffer)
    (goto-char (point-max))))

(defun aidev-chat-send-message (message)
  "Send MESSAGE to the AI and insert the response in the current buffer."
  (interactive
   (list
    (if (region-active-p)
        (buffer-substring-no-properties (region-beginning) (region-end))
      (read-string "Message: "))))

  (unless (eq major-mode 'text-mode)
    (error "Can only send messages from the chat buffer"))

  ;; Initialize the chat if needed
  (unless aidev-chat-messages
    (setq aidev-chat-system-prompt-used aidev-chat-system-prompt)
    (setq aidev-chat-messages nil))

  ;; Add user message to the messages list
  (push `(("role" . "user") ("content" . ,message)) aidev-chat-messages)

  ;; If we're sending a message from a region, make sure it appears in the buffer
  (when (and (region-active-p) (not (= (point) (point-max))))
    (goto-char (point-max))
    (insert aidev-chat-user-prompt-prefix message aidev-chat-separator))

  ;; Get response
  (let* ((messages (reverse aidev-chat-messages))
         (response (aidev--chat aidev-chat-system-prompt-used messages)))

    ;; Add AI response to the messages list
    (push `(("role" . "assistant") ("content" . ,response)) aidev-chat-messages)

    ;; Insert response in the buffer
    (goto-char (point-max))

    ;; Check if the buffer ends with the proper separator
    ;; If not, ensure we have proper spacing before inserting the AI response
    (let ((buffer-end (point))
          (separator-length (length aidev-chat-separator)))
      (when (< (point-min) buffer-end)
        ;; Only check if buffer has enough content to possibly contain the separator
        (if (and (>= (- buffer-end (point-min)) separator-length)
                 (string= (buffer-substring-no-properties
                          (- buffer-end separator-length) buffer-end)
                          aidev-chat-separator))
            ;; We already have the proper separator at the end
            nil
          ;; No separator at end, add it
          (insert aidev-chat-separator))))

    ;; Insert the AI response with its prefix
    (insert aidev-chat-ai-response-prefix response aidev-chat-separator)

    ;; Setup for the next user message
    (goto-char (point-max))))

(defun aidev-chat-send-buffer-contents ()
  "Send the current buffer contents up to the point as a message to the AI."
  (interactive)
  (let ((message (buffer-substring-no-properties (point-min) (point))))
    (aidev-chat-send-message message)))

;;;;;;;;;; Prompt preparation routines
(defun aidev--prepare-system-message (additional-instructions)
  "Prepare the system message with common instructions and ADDITIONAL-INSTRUCTIONS."
  (string-join
   (list
    "You are an extremely competent programmer. You have an encyclopedic understanding, high-level understanding of all programming languages and understand how to write the most understandeable, elegant code in all of them."
    (format "The user is currently working in the major mode '%s', so please return code appropriate for that context." major-mode)
    additional-instructions)
   "\n"))

(defun aidev--prepare-prompt (prompt &optional include-region)
  "Prepare the PROMPT, optionally including the active region
if INCLUDE-REGION is non-nil."
  `(,@(when (and include-region (region-active-p))
        `((("role" . "user") ("content" . ,(buffer-substring-no-properties (region-beginning) (region-end))))))
    (("role" . "user") ("content" . ,prompt))))

;;;;;;;;;; Markdown-related sanitation
(defun aidev--invert-markdown-code (md-block)
  "Extract code from markdown blocks in MD-BLOCK, commenting out non-code parts."
  (if (string-match-p "^[ \t]*```" md-block)
      (let* ((lines (split-string md-block "\n"))
             (in-code-block nil)
             (c-start (or comment-start ";; "))
             (c-end (or comment-end ""))
             result)
        (dolist (line lines)
          (if (string-match-p "^[ \t]*```" line)
              (setq in-code-block (not in-code-block))
            (push (if in-code-block
                      line
                    (concat c-start line c-end))
                  result)))
        (string-join (nreverse result) "\n"))
    md-block))

(defun aidev--strip-markdown-code (md-block)
  "Strip markdown code delimiters from MD-BLOCK."
  (replace-regexp-in-string
   "\\(?:^```[a-zA-Z-]*\\s-*\n\\|\\n?```\\s-*$\\)"
   ""
   md-block))

;;;;;;;;;; Raw chat basics
(defun aidev--chat (system messages)
  "Chat with AI using SYSTEM prompt and MESSAGES."
  (string-trim
   (pcase aidev-provider
     ('ollama (aidev---ollama messages system aidev-default-model))
     ('openai (aidev---openai messages system aidev-default-model))
     ('claude (aidev---claude messages system aidev-default-model))
     (_ (error "Unknown AI provider: %s" aidev-provider)))))

;;;;;;;;;; Ollama-specific functions
(defun aidev---ollama-available (url)
  "Check if there's a listening Ollama server at URL."
  (let* ((parsed-url (url-generic-parse-url url))
         (host (url-host parsed-url))
         (port (url-port parsed-url))
         (connected nil))
    (and host port
         (condition-case nil
             (let ((proc (make-network-process
                          :name "ollama-test"
                          :host host
                          :service port
                          :nowait t)))
               (set-process-sentinel
                proc
                (lambda (_ event)
                  (when (string-match "open" event)
                    (setq connected t))))
               (sleep-for 0.2)
               (delete-process proc)
               (and connected url))
           (error nil)))))

(defvar aidev---ollama-default-url
  (let ((env-address (getenv "AIDEV_OLLAMA_ADDRESS")))
    (or env-address
	(and aidev-ollama-url (aidev---ollama-available aidev-ollama-url))
	(aidev---ollama-available "http://192.168.0.12:11434/")
	(aidev---ollama-available "http://localhost:11435/")
	(aidev---ollama-available "http://localhost:11434/"))))

(defun aidev---ollama (messages &optional system model)
  "Send MESSAGES to Ollama API using the generate endpoint.
MODEL defaults to \"deepseek-coder-v2:latest\".
SYSTEM is an optional system prompt."
  (unless aidev---ollama-default-url
    (signal 'ollama-url-unset '("Ollama URL not set and automatic detection failed")))
  (let* ((model (or model "deepseek-coder-v2:latest"))
         (url-request-method "POST")
         (url-request-extra-headers
          '(("Content-Type" . "application/json")))
         (prompt (format "SYSTEM PROMPT: %s MESSAGES: %s"
                         (or system "")
                         (json-encode messages)))
         (url-request-data
          (json-encode
           `((prompt . ,prompt)
	     (stream . :json-false)
             (model . ,model))))
         (response-buffer
          (url-retrieve-synchronously
           (concat aidev---ollama-default-url "/api/generate")))
         response)
    (unwind-protect
        (with-current-buffer response-buffer
          (goto-char (point-min))
          (re-search-forward "^$")
          (forward-char)
	  (let ((js (json-read)))
	    (setq response js)))
      (kill-buffer response-buffer))
    (cdr (assoc 'response response))))

(defun aidev---decode-utf8-string (str)
  "Fix misencoded UTF-8 characters in STR.
Replaces misencoded em-dashes and typographic quotes
with standard ASCII equivalents."
  (let ((result str))
    ;; Replace misencoded em-dash (â) with hyphen (-)
    (setq result (replace-regexp-in-string "â" "-" result))
    ;; Replace misencoded right single quote (â) with a straight apostrophe (')
    (setq result (replace-regexp-in-string "â" "'" result))
    ;; Optionally replace misencoded left/right double quotes with standard double quotes:
    (setq result (replace-regexp-in-string "â" "\"" result))
    (setq result (replace-regexp-in-string "â" "\"" result))
    result))

;;;;;;;;;; OpenAI-specific functions
(defun aidev---openai (messages &optional system model)
  "Send MESSAGES to OpenAI API.
MODEL defaults to \"o1-mini\".
SYSTEM is an optional system prompt."
  (let* ((model (or model "o3-mini"))
	 (system-supported-models '("gpt-3.5-turbo" "gpt-4" "gpt-3.5-turbo-0301"))
         (url-request-method "POST")
         (url-request-extra-headers
          `(("Content-Type" . "application/json")
            ("Authorization" . ,(concat "Bearer " (getenv "OPENAI_API_KEY")))))
	 (messages-with-system
          (if system
              (if (member model system-supported-models)
                  ;; Model supports system prompts: add as a system message.
                  (cons `((role . "system")
                          (content . ,system))
                        messages)
                ;; Model does not support system prompts: add as a user message.
                (cons `((role . "user")
                        (content . ,(concat "SYSTEM_PROMPT: " system)))
                      messages))
            messages))
         (url-request-data
          (json-encode
           `((messages . ,messages-with-system)
             (model . ,model))))
         (response-buffer
          (url-retrieve-synchronously
           "https://api.openai.com/v1/chat/completions"))
         response)
    (unwind-protect
	(with-current-buffer response-buffer
          (goto-char (point-min))
          (re-search-forward "^$")
          (forward-char)
          (setq response (json-read)))
      (kill-buffer response-buffer))
    (aidev---decode-utf8-string
     (cdr (assoc 'content (cdr (assoc 'message (aref (cdr (assoc 'choices response)) 0))))))))

;;;;;;;;;; Claude-specific functions
(defun aidev---claude (messages &optional system model)
  "Send MESSAGES to Claude API.
MODEL defaults to \"claude-3-5-sonnet-20240620\".
SYSTEM is an optional system prompt."
  (let* ((model (or model "claude-3-5-sonnet-20240620"))
         (url-request-method "POST")
         (url-request-extra-headers
          `(("Content-Type" . "application/json")
            ("X-Api-Key" . ,(getenv "ANTHROPIC_API_KEY"))
            ("anthropic-version" . "2023-06-01")))
         (url-request-data
          (json-encode
           (append
            `((messages . ,messages)
              (model . ,model)
              (max_tokens . 4096))
            (when system
              `((system . ,system))))))
         (response-buffer
          (url-retrieve-synchronously
           "https://api.anthropic.com/v1/messages"))
         response)
    (unwind-protect
	(with-current-buffer response-buffer
          (goto-char (point-min))
          (re-search-forward "^$")
          (forward-char)
          (setq response (json-read)))
      (kill-buffer response-buffer))
    (cdr (assoc 'text (aref (cdr (assoc 'content response)) 0)))))

(provide 'aidev-mode)
;;; aidev-mode.el ends here
