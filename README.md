# aidev-mode

AI-assisted development tools for Emacs, leveraging language models to help with code generation, refactoring, and other programming tasks.

## Features

- Generate code from natural language prompts
- Refactor selected regions or entire buffers using AI suggestions
- Create new buffers with AI-generated content
- Interactive chat buffer for continuous conversations with AI
- Support for multiple AI providers:
  - Ollama (local models)
  - OpenAI (GPT models)
  - Anthropic (Claude models)

## Installation

### MELPA

Once this package is available on MELPA, you can install it via:

```
M-x package-install RET aidev-mode RET
```

### Manual Installation

1. Clone this repository
2. Add the following to your Emacs configuration:

```elisp
(add-to-list 'load-path "/path/to/aidev-mode")
(require 'aidev-mode)
```

## Configuration

### Basic Configuration

```elisp
;; Enable aidev-mode globally
(aidev-global-mode 1)

;; Set AI provider (options: 'ollama, 'openai, 'claude)
(setq aidev-provider 'ollama)

;; Set default model
(setq aidev-default-model "deepseek-coder-v2:latest")

;; Set custom Ollama URL if needed
(setq aidev-ollama-url "http://localhost:11434/")
```

### Chat Configuration

```elisp
;; Customize the chat system prompt
(setq aidev-chat-system-prompt
      "You are a helpful coding assistant. Provide concise, accurate answers.")

;; Customize chat buffer appearance
(setq aidev-chat-user-prompt-prefix "Me: ")
(setq aidev-chat-ai-response-prefix "Assistant: ")
(setq aidev-chat-separator "\n\n")
(setq aidev-chat-buffer-name "*My AI Assistant*")
```

### Environment Variables

For API-based providers, set these environment variables:

- OpenAI: `OPENAI_API_KEY`
- Anthropic: `ANTHROPIC_API_KEY`
- Ollama: `AIDEV_OLLAMA_ADDRESS` (optional, for custom Ollama URL)

## Usage

### Global Commands

| Keybinding | Command | Description |
|------------|---------|-------------|
| `C-c C-a i` | `aidev-insert-chat` | Insert AI-generated content at point |
| `C-c C-a r` | `aidev-refactor-region-with-chat` | Refactor selected region |
| `C-c C-a b` | `aidev-refactor-buffer-with-chat` | Refactor entire buffer |
| `C-c C-a n` | `aidev-new-buffer-from-chat` | Create new buffer with AI-generated content |
| `C-c C-a c` | `aidev-start-chat` | Start an interactive chat session with AI |

### Chat Buffer Commands

The chat buffer has its own minor mode (`aidev-chat-mode`) with these commands:

| Keybinding | Command | Description |
|------------|---------|-------------|
| `C-c C-c` | `aidev-chat-send-buffer-contents` | Send entire buffer contents to AI |

## License

This project is licensed under the GPL-3.0 License - see the LICENSE file for details.
