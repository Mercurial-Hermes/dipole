# LLM-Friendly Commenting Standard

To ensure ChatGPT always understands module intent, add headers like this:

```zig
// --- BEGIN LLM CONTEXT ---
// Module: LLDBDriver
// Purpose: Provide an abstraction over LLDB (interactive PTY + batch).
// Responsibilities:
//   - spawn lldb
//   - manage stdin/stdout
//   - detect prompt output
//   - expose attach/detach/stepi/readPc
// Current Mode: batch (interactive PTY in progress)
// Dependencies: none external; uses std.posix, ArrayList
// Notes:
//   - Apple Silicon suppresses prompts unless connected to PTY
//   - readUntilPrompt has timeout logic to avoid blocking
// --- END LLM CONTEXT ---
