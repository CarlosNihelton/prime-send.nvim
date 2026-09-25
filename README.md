# prime-send.nvim

> The simplest possible Prime-agent integration for Neovim.

Built on top of the simple `prime-agent send <AGENT> <MESSAGE>` command line, this plugin allows a
very simple use case: send a message to the selected agent augmented with the cursor or selection
information. Trigger this with the `:PrimeSend` command or with the configured keymap. If there is
no previously selected agent, then a `vim.ui.select` selector is shown with the list of active
agents as shown by `prime-agent list`. Selection is defferred to the last moment, so the plugin
doesn't get on your way when you have a hot idea to type to your agent right away. Selection
persists within the plugin state and may changed at any time by running the `:PrimeSendSelectAgent`
command.

Although simple, this plugin has some sauce:

- It computes the correct file path and lines when the cursor is on a hunk: patch files, git diff,
and similar don't offer a direct map from the buffer to the actual file we're supposed to call
attention of the coding agent.
- If a project root is detectable, it sends the file path relative to the project root. Otherwise it
  will be an absolute path.
- It favours simple input with a single line text box, but allow extended input via a scratch
markdown buffer so you can rely on advanced text completion and markdown syntaxes when composing
messages to your agent.
- It passes the prompt to the `prime-agent send` process via `stdin` to avoid shell escaping
problems or too long prompts triggering Linux `ARG_MAX`.
- In normal mode it sends `{filepath}:{line}`, in selection mode it sends
`{filepath}:{start}-{end}`.
- Aggregated messages sends: run `:PrimeSendMultiple` to start collecting multiple comments from
different locations as you go over the sources. Then use the same command and the aggregated prompt
with all the references to the files, locations and comments.

Behaviours considered but not in scope for the MVP:

- More invasive integrations, like custom tools, extensions or MCPs. We want to be the simplest
solution out there.
- Integration with the Pi ecosystem. If one day Pi delivers an out-of-the-box mechanism to send
messages to running agents like Prime does, then we will definitely want to support it. For the time
being, implementing custom tools is not worth it and there are suitable alternatives out there.
- Spawning agents. We just assume you're already working with agents and just want to send a message
from the comfort of your preferred editor as you review code they write. No more than that. Thus no
start or resume of agents.
