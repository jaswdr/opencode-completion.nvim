# opencode-completion.nvim

A Neovim plugin that integrates with OpenCode server for AI-powered code completion using Treesitter for context.

## Features

- Press `<C-l>` to trigger completion at the cursor position.
- Uses Treesitter to extract contextual code (e.g., current function or block).
- Sends a prompt to OpenCode server for completion.
- Displays "Vibe coding..." as ghost text while waiting.
- Inserts the completed code directly.

## Requirements

- Neovim 0.7+
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- OpenCode server running on `http://localhost:4096` (run `opencode serve`)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  "jaswdr/opencode-completion.nvim",
  dependencies = { "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter" },
  config = function()
    require("opencode-completion").setup()
  end,
}

```

## Usage

1. Start OpenCode server: `opencode serve --port=4096`
2. Open a file in Neovim.
3. Place cursor where you want completion.
4. Press `<C-l>` or run `:OpenCodeComplete`.

The plugin will show "Vibe coding..." and replace it with the completion.

## Debugging Commands

- `:OpenCodeComplete`: Manually trigger completion (same as `<C-l>`).
- `:OpenCodeSession`: Show the current session ID (for debugging session persistence).

## Configuration

Currently minimal config. Extend `setup(opts)` for custom server URL, etc.

## Troubleshooting

- Ensure Treesitter parsers are installed for your language (e.g., `:TSInstall lua`).
- Check OpenCode server is running and accessible.
- If no completion, check Neovim notifications for errors.
