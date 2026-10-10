# Architecture decision records

Decisions that are hard to reverse or surprising. Each ADR is numbered within a topic section.

## 1. Message format

### 1.1 - Wire format of messages to agents

* **Problem/Context**: Messages are delivered through the prime-agent send command and read by coding agents inside running sessions. Users and agents will build habits around the shape of the text; changing it after release breaks those habits silently. The reference must stay machine-greppable and the comment human-readable in the same line.
* **Decision**: A message is one line per location when the comment is single-line: the reference `path:line` (or `path:start-end` for a selection), the literal ` Comment: ` marker, then the comment. When the comment is multi-line, the first line is the reference plus ` Comment:` alone, and the body follows verbatim on the next lines. Every entry, aggregated or not, carries its own reference. Aggregated entries are separated by one blank line and carry no numbering. Every delivered message ends with a fixed delivery note separated by one blank line: `[Sent via prime-send neovim plugin. Reply inline in your session, do not send messages.]` — the note is added once per message (not per entry) at the delivery choke point, never inside a comment body, and never to the CLI arguments other than the message text.
* **Consequences**:
  - Positive: agents can parse the location from the first line of any message; the format is stable and predictable across single and aggregated sends; selection ranges and multi-line bodies fit without escaping; the delivery note tells the receiving agent that the sender is a human in an editor (the prime-agent CLI stamps an ephemeral session id as the sender) and that replies belong in the receiving session, preventing agents from attempting reply messages into unreachable sender ids.
  - Negative: the ` Comment: ` marker and layout are a public contract that cannot be restyled after release; messages with no file location cannot be sent at all.
