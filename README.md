# prime-send.nvim

> The simplest possible Prime-agent integration for Neovim.

prime-send.nvim sends a message to a Prime agent from the editor, augmented with a reference to
the file and line you are looking at. Messages are delivered by spawning the configured command
with the `send` subcommand and the message passed as a direct process argument list - no shell
and no stdin are involved. If there is no previously selected agent, a floating selector lists
the agents right before the first delivery, so the plugin never gets in your way when you have a
hot idea to type to your agent right away. The selection persists and can be changed at any time
with `:PrimeSendSelectAgent`.

## Commands

| Command | Description |
| --- | --- |
| `:PrimeSend` | Prompt for a comment and deliver `{reference} Comment: {comment}` to the pinned agent on Enter (<CR>). An empty comment opens the scratch buffer for extended input. |
| `:PrimeSendSelectAgent` | Open the floating selector over the agents known by `prime-agent list --json --all` and pin the chosen one. |
| `:PrimeSendMultiple` | Capture a comment as `:PrimeSend` does, but append the composed entry to the pending queue instead of delivering. Echoes the pending count. |
| `:PrimeSendMultiple!` | Deliver every pending entry as a single message, entries separated by one blank line, and clear the queue. Echoes `prime-send: nothing pending` and spawns nothing when the queue is empty. |
| `:PrimeSendMultipleCancel` | Discard every pending entry and echo the discarded count. |

## Selector

The selector is a centered floating window showing one line per agent: id, name, lifecycle,
activity, and a summary. Move with the normal navigation keys and:

- `<CR>` picks the agent under the cursor and pins it.
- `<Esc>` or `q` cancels, leaving the previous pin (if any) cleared.
- Closing the window cancels as well.

Failures are reported as warnings and never raise: a command that cannot be spawned echoes
`prime-send: failed to spawn "..."`, a listing that yields no agents echoes
`prime-send: no agents found` (or the listing error), and a failed delivery echoes
`prime-send: delivery failed: ...` with the command output. If `prime-agent` is not on the PATH
of the environment Neovim runs in, set the absolute path in the `cmd` option.

## Options

```lua
require("prime-send").setup({
  cmd = "prime-agent", -- command spawned for both listing and delivery
  busy = "send",       -- one of "send", "steer", "follow-up"
})
```

- `cmd` (string, default `"prime-agent"`): the command spawned for both the `list --json --all`
  listing and the `send` delivery. Can be an absolute path to a wrapper.
- `busy` (string, default `"send"`): the delivery mode. `"send"` passes no flag; `"steer"` passes
  `--steer` and `"follow-up"` passes `--follow-up` between the identity and `--message`. Any other
  value raises an error.

## Message format

Every entry carries its own reference, and the reference is machine-greppable in the first line.

Single-line comment, one line per location:

```
src/x.lua:42 Comment: fix this
```

Multi-line comment: the first line is the reference plus ` Comment:` alone, and the body follows
verbatim:

```
src/x.lua:42 Comment:
the body
follows here
```

Aggregated sends join the entries with one blank line and no numbering:

```
src/x.lua:42 Comment: fix this

src/y.lua:7 Comment:
another entry
```

## Buffer support

- **Normal buffers**: the reference is the file path relative to the project root (the git
  toplevel of the buffer directory, else the root of the first attached LSP client), then a colon,
  then the cursor line. In visual mode it becomes `{start}-{end}`, normalized ascending. Without a
  detectable project root the absolute path is kept.
- **Diff and patch buffers** (filetype `diff` or a `.patch`/`.diff` file): the cursor position
  inside a hunk is mapped through the diff to the line it denotes in the referenced file, so the
  agent sees the exact source line, not the patch line. Caveats: positions on headers or between
  hunks fall back to the patch file reference; deletion-only hunks map to old-side line numbers;
  files removed by a patch are referenced by their recorded path.
- **Fugitive buffers** (`fugitive://` names with a commit sha or a stage digit): the reference is
  resolved to the working-tree file path via `FugitiveReal` when available, else by deriving the
  toplevel from the git dir. Caveats: a buffer without a work-tree file path (such as an index
  buffer) echoes `prime-send: no reference for this buffer` and sends nothing; a linked worktree
  is detected through its admin directory and the reference resolves to the file path under the
  linked worktree root.

## Development

Run `make check` to check formatting, lint the Lua files, and run the test suite. It fetches
Plenary into the ignored `.deps/` directory on the first test run. The command requires Make, Git,
Neovim, StyLua, and Luacheck.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "CarlosNihelton/prime-send.nvim",
  config = function()
    require("prime-send").setup()
  end,
}
```

Run `:helptags ALL` after installing. See `:h prime-send` for the full documentation.

## Keymap examples

```lua
vim.keymap.set("n", "<leader>as", ":PrimeSend<CR>", { desc = "Send to agent" })
vim.keymap.set("v", "<leader>as", ":PrimeSend<CR>", { desc = "Send selection to agent" })
vim.keymap.set("n", "<leader>aa", ":PrimeSendSelectAgent<CR>", { desc = "Select agent" })
vim.keymap.set("n", "<leader>am", ":PrimeSendMultiple<CR>", { desc = "Queue comment" })
vim.keymap.set("n", "<leader>aM", ":PrimeSendMultiple!<CR>", { desc = "Send queued comments" })
```

## Disclaimer

This project is independent software. It is not affiliated with, endorsed by, or sponsored by
Prime Intellect, the makers of Prime Agent.
