# Domain glossary

Terms used in code, docs, and user-facing text of prime-send.nvim. A glossary only: no decisions, no implementation details.

- **Agent**: a prime-agent session that can receive messages. Identified by its session id, its optional session name, or its worker id.
- **Session id**: the stable UUID that identifies an agent across restarts.
- **Session name**: an optional human-assigned label for an agent.
- **Worker id**: the short id of the process currently serving an agent; it changes every time the agent is resumed.
- **Active agent**: an agent whose worker process is running right now.
- **Saved agent**: an agent persisted on disk; messaging it resumes it with a new worker.
- **Pinned agent**: the agent chosen to receive subsequent messages; persists until re-chosen.
- **Selector**: the picker that lists agents and lets the user pin one.
- **Selector timing**: selection happens at the last moment, right before the first message is delivered, never before the user has composed their message.
- **Message**: the complete text delivered to an agent; composed of a reference and a comment.
- **Reference**: the file location carried by a message: a path plus a line or a line range.
- **Comment**: the user-written text saying what the agent should look at.
- **Wire format**: the fixed layout that combines a reference and a comment into a message.
- **Project root**: the directory that file paths in references are relative to.
- **Normal buffer**: a buffer backed by a working-tree file.
- **Diff buffer**: a buffer whose content is a unified diff, including patch files on disk and diff command output.
- **Hunk mapping**: translating a position in a diff buffer to the position it denotes in the referenced file.
- **Scratch buffer**: the floating markdown buffer for composing a multi-line comment.
- **Pending queue**: the collected entries waiting to be delivered together.
- **Entry**: one reference-plus-comment unit stored in the pending queue.
- **Aggregated send**: a single message carrying every entry of the pending queue.
