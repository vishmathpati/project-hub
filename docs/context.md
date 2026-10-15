# Find where session context goes

Open a project from **Projects**. **Overview** opens first. You can return to it with **⌘9**.

Start with the suggested next action. When a session captured MCP tool definitions, Overview shows their approximate text size beside the option to load tools only when needed. This identifies context to review. The estimate is not a promise that every token can be removed.

Choose a recent Claude or Codex session. **Last request input** shows the input for the last recorded request. **Session traffic** counts recorded input and output across the session. The traffic chart separates fresh input, cache creation, cache reads, and output. Cached Codex input is counted once.

Use the captured-text chart and item list to inspect skills, agents, MCP tools, and instructions. Filter by scope or search for a name. Reveal a source to inspect its origin. An estimate uses captured text from that session. A current candidate is a matching file found today, which does not prove that the same file supplied the historical session.

Approximate token values use characters divided by four. They do not reconcile to provider usage counters or prove how much context remains after compaction. **Unknown** means the transcript lacks the required evidence. A coverage note identifies incomplete records, unsupported counters, and scan limits. Select **Scan more** to increase the budget for a large session. Partial reports label their values as scanned input and traffic.

Select **Current defaults** to inspect the sources available today. A skill file estimate describes its full text, which loads when invoked. It does not describe the smaller catalog entry advertised at startup.

To reduce future context, preview tool search or **On demand** for an eligible standalone Claude skill. The preview shows the exact change to this project's `.claude/settings.local.json`. Review the before and after text, then select **Apply**. Start a new Claude session to use the setting. Tool search requires compatible model and proxy support, and savings vary with the session.

Select **Undo** to restore the exact prior settings. Project Hub refuses to overwrite a settings file changed since the preview or apply. Plugin skills and unsupported sources offer source inspection instead of a guessed settings change.

Context reads local files. Opening this page does not launch Claude, Codex, MCP servers, or model requests.

To review installed skills, select **Skills**. It opens on **This project**. Use the scope filter to see global, inherited, or provider-managed sources. Global availability is included even when the project scanner stops at a Git repository boundary. A skill can have origins in more than one scope.

Each skill appears once. Expand a row to see its separate provider copies and exact source paths. Shared global sources show **Available** and offer source inspection or copying. Project edits and removal apply to the exact local origin beside the action.

Select **Add skill** to open the library. Choose the source and provider for the installation. Close the library to return to the project list.
