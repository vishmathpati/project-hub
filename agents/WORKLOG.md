# Worklog — agents
> Cleared after each session.

## 2026-05-28 23:13 IST

- Follow-up at 2026-05-30 18:18 IST:
  - Used two fresh read-only subagents to check env-wrapper readback scope and risk boundaries, then closed them after the batch.
  - Added shared `MCPLaunchNormalizer` for inventory/readback metadata so global JSON/TOML MCP rows, project `readAllServerEntries`, and Claude local project rows unwrap `/usr/bin/env -S` / `--split-string`, inline env assignments, passthrough env names, and Docker env/env-file hints.
  - Kept `ConfigWriter.readServer` raw for edit/writeback safety and added a regression proving the authored `/usr/bin/env -S` shape is preserved there.
  - Validation: focused 4-test readback slice passed after SwiftPM cache escalation; `git diff --check` passed.

- Follow-up at 23:50 IST:
  - Used three fresh read-only subagents to scout the next safe-fix, import/health, and skills/project-detection compatibility gaps, then closed them after the batch.
  - Added `/usr/bin/env -S` / `--split-string` wrapper support across MCP import, Health, and Compatibility diagnostics, including env `-i` / `-u` tolerance.
  - Expanded `ProjectStore.detectedTools` so Claude/Codex skills, instruction files, and project settings markers make non-git folders discoverable as AI-tool projects.
  - Normalized Claude-style remote MCP `Authorization: Bearer ${TOKEN_ENV}` headers into Codex `bearer_token_env_var` during Codex TOML preview/write, avoiding literal non-expanding `http_headers`.
  - Validation: focused 7-test compatibility slice passed after SwiftPM cache escalation; `git diff --check` passed.

- Matched ordinary global/project MCP inventory OAuth handling to Health/Compatibility by dropping placeholder-only OAuth metadata such as `your-client-id` and `...`.
- Fixed Compatibility Verify affordance for app-managed connector/extension-only lenses: button gating now uses directly verifiable MCP servers, and the empty state explains when verification belongs in the owning app.
- Added metadata and fix-plan plumbing for malformed Codex plugin MCP policy key/value findings so Project Hub can preview-remove only the invalid TOML section key with stale-preview protection.
- Validation: focused OAuth inventory and plugin-policy tests passed with 3 tests after SwiftPM cache escalation; `git diff --check` passed.
- Subagents: read-only sidecars Aristotle and Peirce identified the plugin-policy cleanup path and Verify empty-state issue; both were closed after the batch.

## 2026-05-28 23:06 IST

- Extended safe MCP command-string normalization to Rust and Go source launchers (`cargo run ...`, `go run ...`) across import, global/project inventory, health, writer, and Compatibility paths.
- Preserved `env_file` when writing remote/hosted MCP servers into Codex TOML, closing a write/health parity gap for copied VS Code/Roo/JSON remote configs.
- Fixed copied Compatibility reports to include live Verify rows by server ID and use verified MCP health in detailed server rows.
- Validation: focused command-string/env-file tests passed with 3 tests after SwiftPM cache escalation; `git diff --check` passed.
- Subagents: read-only sidecars Turing and Parfit identified the remote `env_file` parity gap and report live-Verify copy gap; both were closed after the batch.

## 2026-05-28 22:59 IST

- Verified the official Homebrew MCP docs publish Claude/Cursor configs as `command: "brew mcp-server"`.
- Added `brew` to the safe command-string starter allowlist across the duplicated normalization paths:
  - `ImportParser`, `FullConfigReader`, `MCPReader`, `ConfigWriter`, `CompatibilityScanner`, and `MCPHealthChecker`.
- Added focused import and project-inventory regressions for the Homebrew command-string shape.
- Used one read-only sidecar to check for other obvious safe starters, then closed it after completion.
- Validation: focused Homebrew command-string tests passed with 2 tests after SwiftPM cache escalation, and `git diff --check` passed.

## 2026-05-28 22:56 IST

- Used one read-only sidecar to check remaining MCP auth/import gaps, then closed it after the batch.
- Fixed Compatibility OAuth placeholder parity with MCP Health:
  - Placeholder-only OAuth values such as `your-client-id` and `...` no longer count as meaningful app-owned OAuth metadata.
  - Hosted OAuth providers still surface "Hosted MCP OAuth required" when the only OAuth metadata is placeholder text.
  - Real non-placeholder OAuth metadata still appears as app-managed OAuth and suppresses hosted-OAuth noise for that project surface.
- Validation: focused Compatibility OAuth placeholder tests passed with 3 tests after SwiftPM cache escalation, and `git diff --check` passed.

## 2026-05-28 22:45 IST

- Refined Docker MCP health semantics after official Docker storage docs review:
  - Bind mounts point at host paths, including relative `--mount type=bind,source=...` values.
  - Named volumes are Docker-managed, so `-v name:/data` and `--mount type=volume,source=name` should not be reported as missing host filesystem paths.
  - Structured mount `type` values are parsed case-insensitively, and empty sources are ignored instead of becoming fake relative paths.
- Updated `MCPHealthChecker` and `CompatibilityScanner` with focused regression coverage.
- Validation: focused Docker named-volume/bind and structured-mount tests passed after SwiftPM cache escalation, and `git diff --check` passed.
- Spawned one read-only sidecar and closed it before ending the batch per subagent cleanup rule.

## 2026-05-23 06:31 IST

- Follow-up at 23:45 IST:
  - Used two fresh read-only subagents for Codex docs/code review of profile-scoped plugin MCP policy, then closed them after the batch completed.
  - Verified official Codex config docs list `plugins.<plugin>.mcp_servers.<server>` policy keys and `profiles.<name>.*` profile-scoped overrides for supported config keys.
  - Added profile-scoped Codex plugin MCP policy detection for `profiles.<profile>.plugins.<plugin>.mcp_servers.<server>` and per-tool approval sections.
  - Settings evidence now includes profile-prefixed plugin MCP policy keys and summary counts; malformed profile-scoped policy sections/values now produce the same schema diagnostics as top-level plugin policy.
  - Kept profile-scoped `enabled = false` as settings evidence only, not effective server-disabled state, because the scan does not prove the active runtime profile.
  - Validation: `swift test --filter CompatibilityPluginMCPTests`, `swift test --filter 'CompatibilityPluginMCPTests|CompatibilityContextSettingsTests'`, `swift build`, `bash build-app.sh`, `plutil -lint ProjectHub.app/Contents/Info.plist`, `git diff --check`, and debug scans passed at 2026-05-23 23:45 IST.

- Follow-up at 23:27 IST:
  - Used two fresh read-only subagents for official-doc/local-evidence review and Global MCP code-risk review, then closed them after the batch completed.
  - Verified from official Codex docs and real local config/cache evidence that configured Codex plugin-bundled MCP servers are installed inventory, while cache-only marketplace entries such as the local Vercel cache should not appear as installed Global MCP servers.
  - Extended Global MCP inventory to include configured Codex plugin MCP servers from installed `.codex-plugin/plugin.json` manifests, with plugin-relative command/path resolution and disabled state from whole-plugin or server-level Codex policy.
  - Added read-only metadata to `ServerEntry` and disabled Global MCP edit/copy/delete/toggle controls for plugin-owned MCP rows so plugin bundle files are not mutated through direct MCP config flows.
  - Added focused coverage for configured plugin MCP rows, disabled plugin rows, server-policy-disabled rows, cache-only exclusion, resolved plugin-relative commands, and duplicate direct/plugin server IDs.
  - Validation: `swift test --filter FullConfigReaderTests`, `swift test --filter 'FullConfigReaderTests|MCPHealthCheckerTests|CompatibilityPluginMCPTests'`, `swift build`, `bash build-app.sh`, `plutil -lint ProjectHub.app/Contents/Info.plist`, `git diff --check`, and debug scans passed at 2026-05-23 23:27 IST.

- Follow-up at 23:17 IST:
  - Used two read-only subagents for Codex plugin MCP dogfood and Compatibility UI/report review, then closed them after the batch completed.
  - Confirmed real configured Codex plugin MCP coverage for `computer-use@openai-bundled` and disabled `cloudflare@openai-curated`; also confirmed the older Global MCP view still reads only direct Codex MCP config and does not dereference configured plugin-bundled MCP servers.
  - Fixed the previewed Codex plugin MCP server enable plan so it preserves `requiresRestartAfterWrite` from the surface instead of downgrading the fix to a rescan-only follow-up.
  - Added the Compatibility manual-action queue to the copied Markdown report so restart/auth/manual next steps are not lost when users export the report.
  - Validation: `swift test --filter CompatibilityPluginMCPTests`, `swift build`, `bash build-app.sh`, `plutil -lint ProjectHub.app/Contents/Info.plist`, `git diff --check`, and debug scans passed at 2026-05-23 23:17 IST.

- Follow-up at 22:41 IST:
  - Re-verified Codex plugin marketplace, manifest, cache, and plugin-scoped MCP policy behavior against official OpenAI docs through read-only subagents.
  - Added read-only Compatibility settings evidence for Codex personal plugin marketplace, project `.agents/plugins/marketplace.json`, and legacy project `.claude-plugin/marketplace.json`, visible for both Codex CLI and Codex Desktop.
  - Added read-only installed Codex plugin manifest surfaces for both Codex CLI and Codex Desktop so malformed plugin bundle metadata is visible even when no MCP server row can be created.
  - Manifest scanning now reports invalid `mcpServers` shapes, non-`./` paths, out-of-root paths, and missing target files instead of silently skipping those plugin MCP bundles.
  - Codex settings keys and summaries now surface plugin-scoped MCP policy, including `default_tools_approval_mode`, `enabled_tools`, and per-tool `approval_mode`, without treating valid policy as a warning.
  - Closed both subagents immediately after the batch completed.
  - Validation: `swift test --filter CompatibilityPluginMCPTests`, `swift test --filter CompatibilityContextSettingsTests`, `swift build`, `bash build-app.sh`, `plutil -lint ProjectHub.app/Contents/Info.plist`, `git diff --check`, and edited-file whitespace/debug scans passed at 2026-05-23 22:41 IST.

- Follow-up at 22:21 IST:
  - Re-verified Codex plugin MCP behavior against official OpenAI docs with subagents, including plugin cache layout, `.codex-plugin/plugin.json`, `mcpServers` path rules, shared Codex config, and plugin-scoped MCP policy.
  - Added Codex plugin-bundled MCP discovery for installed plugins listed in `~/.codex/config.toml`, mapped to `~/.codex/plugins/cache/<marketplace>/<plugin>/<version>/.codex-plugin/plugin.json`.
  - Plugin MCP rows now appear for both Codex CLI and Codex Desktop, remain read-only/plugin-owned, require restart after policy changes, and reuse existing static health/auth checks.
  - Plugin `.mcp.json` reads now support wrapped `mcpServers`, official wrapped `mcp_servers`, and direct server-map shapes.
  - Relative plugin commands/cwd/path-like strings resolve against the plugin root, covering local plugin MCPs such as Computer Use style app-bundle commands.
  - Disabled plugin state and disabled bundled MCP server policy from `plugins.<plugin>.mcp_servers.<server>.enabled = false` now mark bundled server rows disabled.
  - Closed both subagents immediately after the batch completed.
  - Validation: `swift test --filter CompatibilityPluginMCPTests`, `swift test --filter MCPHealthCheckerTests`, `swift test --filter CompatibilitySkillSupportTests`, `swift test --filter CompatibilityProjectMCPTests`, `swift build`, `bash build-app.sh`, `plutil -lint ProjectHub.app/Contents/Info.plist`, `git diff --check`, and edited-file whitespace/debug scans passed at 2026-05-23 22:21 IST.

- Follow-up at 07:09 IST:
  - Refined nested Codex project MCP duplicate-name handling after read-only subagent review.
  - Same-named Codex project `[mcp_servers.<name>]` tables now merge effective config from root to selected subdirectory, including recursive leaf-key merge for nested subtables such as `env`.
  - Additive or identical nested layers no longer surface generic duplicate/conflict findings; actual closer-layer overrides produce `server.shadowed-by-project-layer` warnings naming leaf keys such as `args` or `env.BAR`.
  - Closed the subagent immediately after the review batch completed.
  - Validation: `swift test --filter CompatibilityProjectMCPTests` passed with 9 tests at 2026-05-23 07:09 IST; `swift test --filter 'CompatibilityProjectMCPTests|CompatibilityContextSettingsTests'` passed with 50 tests at 2026-05-23 07:11 IST; `swift build` passed; `swift test` passed with 222 tests at 2026-05-23 07:15 IST.

- Follow-up at 06:50 IST:
  - Re-verified Codex nested project config behavior through read-only subagents against official OpenAI Codex docs and local code paths.
  - Compatibility scan now preserves the selected path before root normalization and adds read-only Codex project MCP/settings surfaces for existing nested `.codex/config.toml` layers between the detected project root and selected subdirectory.
  - Nested Codex layer surfaces keep their own paths and are not marked safe write targets; root `.codex/config.toml` remains the current write/import destination until the UI explicitly supports choosing a layer.
  - Added coverage for nested Codex MCP server discovery and nested ignored project settings findings.
  - Closed both subagents immediately after the batch completed.
  - Validation: `swift test --filter 'CompatibilityProjectMCPTests|CompatibilityContextSettingsTests'` passed with 47 tests at 2026-05-23 06:50 IST; `swift build` passed; `swift test` passed with 219 tests at 2026-05-23 06:56 IST.

- Follow-up at 06:39 IST:
  - Re-verified Codex project config behavior through read-only subagents against official OpenAI Codex docs and local code paths.
  - Compatibility now detects exact parent ignored project sections/keys in `.codex/config.toml`, including `[profiles]`, `[model_providers]`, `[otel]`, top-level `profiles`, top-level `model_providers`, and top-level `otel`.
  - ConfigWriter ignored-project cleanup now removes exact parent sections and nested descendants using root-aware matching instead of prefix strings, preserving unrelated sections such as `[mcp_servers.keep]`.
  - Added direct tests that project `.codex/config.toml` reports trust-required when the user-level `[projects."<path>"].trust_level` entry is missing and suppresses it once trusted.
  - Closed both subagents immediately after the batch completed.
  - Validation: `swift test --filter 'CompatibilityContextSettingsTests|ConfigWriterSettingsRepairTests'` passed with 81 tests at 2026-05-23 06:39 IST; `swift build` passed; `swift test` passed with 217 tests at 2026-05-23 06:44 IST.

- Added Compatibility visibility for adjacent editor-specific project MCP files:
  - Cursor `.cursor/mcp.json`, VS Code `.vscode/mcp.json`, and Roo `.roo/mcp.json` now produce informational findings when present in a selected project, because Claude Code/Codex primary tools will not consume those files directly.
  - Findings include readable server names when parsing succeeds, fall back to a clear "could not read any MCP servers" note for invalid/empty files, and point users to explicit import/copy into Claude Code `.mcp.json` or Codex `.codex/config.toml`.
  - Added a dedicated `project.mcp-not-used-by-primary-tools` issue code so these findings land in the Unknown/info bucket instead of counting as broken configuration.
- Re-verified adjacent-editor project MCP docs via read-only subagent:
  - Cursor uses `.cursor/mcp.json` with `mcpServers`.
  - VS Code uses `.vscode/mcp.json` with `servers`.
  - Roo uses `.roo/mcp.json` with `mcpServers`.
- Used two read-only subagents for docs and code-shape review; closed both after the batch completed.
- Validation:
  - `swift test --filter CompatibilityProjectMCPTests` passed with 5 tests.
  - `swift test --filter 'CompatibilityProjectMCPTests|ProjectMCPReaderTests|ConfigWriterProjectScopeTests'` passed with 24 tests.
  - `swift build` passed.
  - `swift test` passed with 213 tests at 2026-05-23 06:31 IST.

## 2026-05-23 06:21 IST

- Tightened Compatibility project MCP behavior from fresh official-doc/source review:
  - Re-verified Claude Code MCP scopes and settings, Claude Desktop local/extension/managed boundaries, Codex CLI/app shared `config.toml` behavior, Codex MCP schema, project-config restrictions, and Codex skills/instructions through a read-only subagent.
  - Compatibility now applies Claude Code `disabledMcpjsonServers` from user, project, local project, managed settings, and managed drop-ins to project `.mcp.json` server rows.
  - Settings-disabled project MCP servers remain visible as disabled and still resolve their active `mcpServers` config for health/report plumbing.
  - Shared Codex CLI/Desktop servers from the same physical `config.toml` are deduped in All/Project/Global Compatibility server lists and Verify target selection while CLI/Desktop filters keep distinct rows.
- Used two read-only subagents for source-backed docs and scanner/UI risk review; closed both after the batch completed.
- Validation:
  - `swift test --filter CompatibilityProjectMCPTests` passed with 2 tests.
  - `swift test --filter 'CompatibilityProjectMCPTests|CompatibilityMCPAuthTests|ClaudeCodeManagedPolicyTests'` passed with 6 tests.
  - `swift build` passed.
  - `swift test` passed with 210 tests at 2026-05-23 06:21 IST.

## 2026-05-23 06:01 IST

- Aligned project-scope MCP discovery with official/source-backed locations:
  - Re-checked Claude Code `.mcp.json`, VS Code `.vscode/mcp.json` with `servers`, Roo `.roo/mcp.json` with `mcpServers`, Roo global `~/.roo/mcp_settings.json`, Cursor `.cursor/mcp.json`, and Codex `.codex/config.toml` through a read-only subagent batch.
  - `MCPReader` now aggregates project servers through `ConfigWriter.readAllServers` for Claude Code, Cursor, VS Code, Roo, and Codex rather than custom one-off parsers.
  - Project detection/root marking now recognizes `.vscode/mcp.json` and `.roo/mcp.json`, and project tool badges include Claude Code, Cursor, VS Code, Roo, and Codex project MCP configs.
  - Project MCP rows and profile copy/count flows now preserve disabled project entries and cover VS Code/Roo project files.
  - Roo global reads/writes now use `~/.roo/mcp_settings.json` with legacy read fallback, and JSON mutation/preview refuses invalid existing JSON instead of silently replacing it.
  - Live context MCP estimates now count all project MCP sources and avoid collapsing same-named servers across different source files.
- Folded the final subagent audit into the patch:
  - Profile copy now strips JSONC comments for source/preview JSON and refuses to overwrite invalid existing destination MCP JSON.
  - Claude disabled project server names now union `mcpServers_disabled` with `disabledMcpjsonServers` and parse JSONC comments.
  - Live context MCP estimates now read disabled project entries from `ConfigWriter.readAllServerEntries` so disabled servers remain visible but inactive.
- Used one final read-only subagent for diff/docs risk review and closed it after completion.
- Validation:
  - `swift test --filter ProjectMCPReaderTests` passed with 8 tests.
  - `swift test --filter 'ProjectMCPReaderTests|ProjectRootDetectorTests|ConfigWriterProjectScopeTests'` passed with 33 tests.
  - `swift build` passed.
  - `swift test` passed with 208 tests at 2026-05-23 06:10 IST.
  - `git diff --check` passed before and after protocol doc updates.

## 2026-05-23 05:46 IST

- Hardened project-scope MCP imports:
  - Project mode now requires a selected project folder before Import can run.
  - Global-only or CLI-only tools are disabled in Project mode and labeled with explicit notes instead of being silently written to user/global config.
  - Import execution passes the chosen project scope directly to `ConfigWriter` and guards against stale invalid selections.
  - Import results now store the actual scope, project root, and config path so Done/Next steps point at the written project file.
  - Diff previews now use a batch preview path so multiple imported servers show the combined final config file instead of only the last server.
- Extracted scope gating into `MCPImportScopePlanner` so project-root requirements, selected-tool eligibility, select-all eligibility, unsupported tool notes, and blank server-name rejection are directly testable.
- Used three read-only subagents for scope fallback review, official/local scope support review, and UX/test verification; closed the whole batch after completion. Used one final read-only verification subagent after patching and closed it after its report.
- Validation:
  - `swift test --filter ConfigWriterProjectScopeTests` passed with 10 tests.
  - `swift build` passed.
  - `swift test` passed with 197 tests at 2026-05-23 05:46 IST.
  - `git diff --check` passed.

## 2026-05-23 05:31 IST

- Added MCP Registry install-method choices:
  - Refactored Registry `server.json` parsing around shared option generation so normal parsing can still produce all parsed servers while import flows can present one choice per `remotes[]`/`packages[]` install method.
  - Paste, GitHub direct `server.json`, GitHub MCP Registry fallback, and source archive `server.json` imports now offer multiple Registry HTTP/SSE/npm/PyPI/Docker/NuGet options as mutually exclusive choices instead of silently flattening alternatives.
  - GitHub Registry fallback now preserves `importChoices` when returning matched Registry metadata, and direct GitHub `server.json` candidates can trigger the same choice flow before README fallback.
  - Registry package entries with non-stdio transports now preserve remote URL variables and headers as their own package choice.
  - The choice UI now says "Choose install method" for Registry alternatives and shows obvious needs such as Docker runtime, env vars, headers, and URL placeholders before preview/write.
- Re-verified official MCP Registry docs:
  - `remotes[]` can expose Streamable HTTP, SSE, or both at different URLs.
  - `packages[]` covers package install methods such as npm, PyPI, NuGet, OCI/Docker, and MCPB.
  - The docs explicitly allow `remotes` and `packages` to coexist so host applications can choose the preferred installation method.
- Used three read-only subagents for Registry docs/examples, implementation shape, and UX/testing risks; all three subagent threads were closed immediately after the batch completed.
- Validation:
  - `swift test --filter ImportParserRegistryManifestTests` passed with 8 tests.
  - `swift test --filter ImportParserArchiveTests` passed with 7 tests.
  - `swift test --filter ImportParserGitHubURLTests` passed with 28 tests.
  - `swift test --filter ImportParser` passed with 56 tests.
  - `swift test` passed with 187 tests at 2026-05-23 05:31 IST.
  - `swift build` passed.
  - `git diff --check` passed.

## 2026-05-23 05:19 IST

- Extended local source archive imports:
  - Source `.zip`, `.tgz`, and `.tar.gz` previews now collect all safe import choices from the bounded archive candidate set instead of returning after the first parseable entry.
  - Archive choices preserve internal path provenance such as `server.json`, `mcp.json`, `mcp-fetch.json`, or `README.md` plus the parsed snippet/source label.
  - Archives with multiple safe choices now use the same choose-before-preview stage as README/import snippets; single-choice archives still auto-preview.
  - MCPB/DXT and Desktop extension `.zip` files remain Claude Desktop handoff-only, with copy that separates extension installation from source-archive import.
  - Import-sheet state resets now clear stale extension/source preview data when users paste new content, switch source modes, choose JSON, choose another archive, or hit an archive parse failure.
  - The archive picker now includes `.gz`, making parser-supported `.tar.gz` files visible in the local choose flow.
- Used three read-only subagents for archive distribution examples, implementation shape, and UX/testing risks; all three subagent threads were closed immediately after the batch completed.
- Validation:
  - `swift test --filter ImportParserArchiveTests` passed with 6 tests.
  - `swift test --filter ImportParser` passed with 50 tests.
  - `swift test` passed with 181 tests at 2026-05-23 05:18 IST.
  - `swift build` passed.
  - `git diff --check` passed.

## 2026-05-23 05:08 IST

- Added multi-choice README/import handling:
  - Introduced parser-owned `ParsedImportChoice` extraction that reuses the existing URL, `mcp add`, `add-json`, bare command, Codex TOML, and JSON snippet parsers while deduplicating repeated snippets.
  - GitHub README fallback now auto-previews a single safe snippet but returns explicit choices when a README contains multiple parseable safe snippets.
  - Direct config files, discovered nested `server.json`, and MCP Registry matches remain high-confidence auto-preview paths and do not show choice UI.
  - The import sheet now has a choose-before-preview stage for ambiguous README/import snippets, showing option type, raw snippet provenance, and server count before writing anything.
  - Paste-mode README snippets now use the same multi-choice extraction path.
- Used three read-only subagents for source-backed examples, implementation shape, and UX/testing risks; all three subagent threads were closed immediately after the batch completed.
- Validation:
  - `swift test --filter ImportParserGitHubURLTests` passed with 26 tests.
  - `swift test --filter ImportParser` passed with 47 tests.
  - `swift test` passed with 178 tests at 2026-05-23 05:08 IST.
  - `swift build` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.

## 2026-05-23 04:58 IST

- Added MCP Registry fallback for GitHub MCP imports:
  - Repo and tree URL imports now check the official MCP Registry after direct config candidates and lazy nested `server.json` discovery miss, but before README fallback.
  - Registry lookup pages through `GET /v0.1/servers?version=latest&limit=100`, then matches exact normalized GitHub `repository.url` metadata client-side because the official `search` parameter is name-only.
  - Tree URL imports require compatible `repository.subfolder` metadata and reject mismatched subfolders.
  - Multiple exact registry matches are treated as ambiguous and fall through instead of auto-importing an arbitrary server.
  - Registry fetch failures and misses are non-fatal, preserving README fallback behavior.
- Tightened URL import UX for registry checks:
  - The URL sheet now shows "Checking MCP Registry for this GitHub repository..." while registry pages are fetched.
  - Successful registry previews use registry-specific provenance instead of pretending a GitHub file was read.
  - Failure copy now mentions both GitHub candidate fetches and MCP Registry matching.
- Used three read-only subagents for official registry research, implementation shape, and UX/testing risks; all three subagent threads were closed immediately after the batch completed.
- Validation:
  - `swift test --filter ImportParserGitHubURLTests` passed with 23 tests.
  - `swift test` passed with 175 tests at 2026-05-23 04:58 IST.
  - `swift build` passed.
  - `git diff --check` passed.

## 2026-05-23 04:43 IST

- Extended GitHub MCP repo discovery:
  - Repo and tree URL candidate plans now include Cursor `.cursor/mcp.json` and VS Code `.vscode/mcp.json` after existing Claude config names and before README fallback.
  - Repo and tree URL imports now support lazy GitHub tree discovery for bounded nested `server.json` files, trying direct config candidates first, discovered manifests second, and README snippets last.
  - Tree URL discovery uses the same ref/prefix split logic as candidate generation, including slash-ref fallback behavior.
  - GitHub discovery deduplicates by URL only so different ref/API fallback candidates are still attempted when needed.
- Tightened URL import state:
  - GitHub tree discovery fetches use raw API text while file candidates still decode GitHub Contents API base64 responses.
  - URL-mode fetches now use a request token; changing source mode or URL invalidates in-flight fetches, clears stale preview state, and re-enables fetch controls.
- Rechecked official/current import locations through sidecars:
  - VS Code workspace MCP uses `.vscode/mcp.json` with top-level `servers`.
  - Cursor project MCP uses `.cursor/mcp.json` with top-level `mcpServers`.
  - Claude Code project MCP uses root `.mcp.json`.
  - MCP Registry `server.json` is metadata, and `repository.subfolder` is documented; registry lookup and multi-choice README imports remain future work.
- Used three read-only sidecar agents for implementation shape, source-backed MCP/GitHub research, and UX/testing risks; all three sidecar threads were closed after the batch completed.
- Validation:
  - `swift test --filter ImportParserGitHubURLTests` passed with 15 tests.
  - `swift test --filter ImportParser` passed with 36 tests.
  - `swift test` passed with 167 tests at 2026-05-23 04:43 IST.
  - `swift build` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.

## 2026-05-23 04:32 IST

- Hardened GitHub MCP URL imports for real-world URL shapes:
  - Tree/blob URLs now generate fallback candidates for branch or tag refs containing slashes, using the normal raw URL first and GitHub Contents API `?ref=` candidates for ambiguous slash-ref interpretations.
  - GitHub source notes now include the resolved ref so preview provenance does not look like a default-branch fetch when users import from a non-default branch or tag.
  - GitHub Contents API responses are decoded from base64 before parser resolution.
  - GitHub release and archive URLs now produce archive/download guidance instead of being treated as fetchable HTML pages or fake hosted MCP endpoints.
- Tightened URL import UX:
  - Switching source modes or editing the remote URL now clears stale fetched text, source notes, parse errors, selected servers, and selected target apps so `Next` cannot apply content fetched from a previous URL.
- Added focused GitHub coverage:
  - Slash-ref tree URLs include Contents API fallback candidates without duplicate URLs.
  - Slash-ref blob URLs include blob-path-only fallback candidates and never expand into repository config probing.
  - README fallback success is covered after config candidates miss.
  - GitHub release/latest, release/tag, release/download, and archive URLs produce archive guidance rather than remote-server imports.
- Rechecked official/current research via sidecars:
  - GitHub supports source archives and release asset downloads.
  - GitHub branch/tag names can contain slashes, so naive single-segment ref parsing is unsafe.
  - MCP Registry `server.json` remains the right first candidate, while subfolder discovery, `.cursor/mcp.json`, `.vscode/mcp.json`, and multi-choice README imports remain future work.
- Used three read-only sidecar agents for code edge cases, source-backed GitHub/MCP distribution research, and UX/testing review; all three sidecar threads were closed after the batch completed.
- Validation:
  - `swift test --filter ImportParserGitHubURLTests` passed with 13 tests.
  - `swift test --filter ImportParser` passed with 34 tests.
  - `swift test` passed with 165 tests at 2026-05-23 04:32 IST.
  - `swift build` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.

## 2026-05-23 04:20 IST

- Hardened GitHub MCP candidate resolution:
  - Added `ImportParser.resolveGitHubContent` to fetch GitHub candidates in order, record every fetch/parse attempt, stop on the first parseable server config, and preserve the last fetched text for user preview when all candidates fail to parse.
  - Added typed attempt/resolution structs so fallback behavior is testable without driving the SwiftUI sheet.
  - Kept blob URLs as single-candidate raw file fetches while repository/tree URLs retain `server.json` and MCP config priority before README fallback.
- Tightened import-sheet behavior:
  - GitHub URL fetch now applies already parsed servers directly instead of parsing the same fetched text again.
  - Fetch status copy shows the candidate being tried, successful source notes only appear for parseable candidates, and stale source notes are cleared on parse failures, invalid URLs, archive guidance, local JSON chooses, and clipboard paste.
  - Failed GitHub repository imports now distinguish "nothing fetched" from "fetched a candidate, but no MCP config or install command was found."
- Used three read-only sidecar agents for resolver semantics, focused tests, and UX/copy risks; all three sidecar threads were closed after the batch completed.
- Validation:
  - `swift test --filter ImportParserGitHubURLTests` passed with 9 tests.
  - `swift test --filter ImportParser` passed with 30 tests.
  - `swift test` passed with 161 tests at 2026-05-23 04:19 IST.
  - `swift build` passed at 2026-05-23 04:20 IST.

## 2026-05-23 04:11 IST

- Upgraded GitHub MCP repository imports:
  - `ImportParser.githubContentFetch(from:)` now returns an ordered GitHub candidate plan instead of one README URL.
  - GitHub repo URLs try `server.json`, `mcp.json`, `mcp-fetch.json`, `.mcp.json`, Claude Desktop config names, `README.md`, and `README.markdown` in archive-priority order under `HEAD`.
  - GitHub tree URLs preserve the selected ref and subtree prefix before trying the same candidate list.
  - GitHub blob URLs still produce exactly one raw-file candidate and do not fallback to repo probing.
  - `.git` suffixes are stripped from repository URLs, while unsupported GitHub paths and release/archive URLs keep their existing guidance paths.
- Updated URL import UX:
  - The URL tab now describes GitHub repo candidate probing instead of README-only fetches.
  - The fetch flow tries each GitHub candidate, parses fetched text immediately, stops on the first importable config, and shows the exact candidate path that succeeded.
  - Remote archive URL copy now states that Project Hub only inspects archives after local download.
- Re-verified official MCP Registry docs for `server.json` as standardized MCP server metadata with `remotes` and `packages`, supporting the decision to prefer `server.json` before README snippets.
- Used three read-only sidecar agents for implementation shape, tests, and UX/copy review; all three sidecar threads were closed after the batch completed.
- Validation:
  - `swift test --filter ImportParserGitHubURLTests` passed with 6 tests.
  - `swift test --filter ImportParser` passed with 27 tests.
  - `swift test` passed with 158 tests at 2026-05-23 04:11 IST.
  - `swift build` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.

## 2026-05-23 04:02 IST

- Carried live MCP expired-auth responses into a distinct `Auth expired` state:
  - `MCPHealthStatus` now includes `authExpired`, with UI coloring/icons in Global MCP and Compatibility views.
  - Stdio initialize errors and Streamable HTTP/SSE initialize errors containing expired-token signals now report `authExpired` while still redacting secrets.
  - Compatibility live Verify manual actions and summary tiles now preserve that state instead of flattening it into generic needs-auth.
- Recognized Codex MCP OAuth credential-store settings:
  - Codex auth scanning now reads both `cli_auth_credentials_store` and `mcp_oauth_credentials_store`.
  - If `auth.json` is absent but `mcp_oauth_credentials_store` is `keyring` or `auto`, Project Hub reports MCP OAuth credential-store evidence instead of a missing-auth finding.
- Clarified Compatibility summary UX:
  - The top summary now separates `MCP Server Health` from `Findings by State`, so non-MCP settings/skill findings are visible and MCP issues are not double-counted in copied reports.
  - Verify help copy now states that Verify checks MCP handshakes while settings, skills, auth policy, and instruction fixes are confirmed by Scan plus the owning app/session reload.
- Used three read-only sidecar agents for health/auth gaps, import gaps, and UX summary risks; all three sidecar threads were closed after the batch completed.
- Validation:
  - `swift test --filter MCPHealthCheckerTests` passed with 16 tests.
  - `swift test --filter CompatibilityMCPAuthTests` passed with 2 tests.
  - `swift test` passed with 152 tests at 2026-05-23 04:02 IST.
  - `swift build` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.

## 2026-05-23 03:53 IST

- Matched Codex/OpenAI skill MCP dependencies against compatible MCP inventory:
  - Skill scans now keep `agents/openai.yaml` MCP dependency descriptors instead of reducing them to names only.
  - Dependencies with URLs match configured remote MCP servers by normalized endpoint and compatible transport, even when the configured server name differs from the dependency value.
  - Dependencies without URLs still match by exact server name and compatible transport.
  - Disabled, broken, unsupported-transport, missing-command, and missing-launch-target MCP servers no longer satisfy skill dependencies.
  - Missing dependency copy now names the dependency endpoint/transport when present and points fixes at the MCP config or `agents/openai.yaml` metadata.
- Improved Compatibility UI/report evidence paths:
  - Findings now prefer an absolute `subjectPath` when present, so missing Codex skill dependency evidence points at the owning `agents/openai.yaml` file instead of a broader issue path.
- Used three read-only sidecar agents for metadata model review, edge-case matching rules, and UX evidence/copy review; all three sidecar threads were closed after the batch completed.
- Validation:
  - `swift test --filter CompatibilitySkillSupportTests` passed with 13 tests.
  - `swift test` passed with 149 tests at 2026-05-23 03:52 IST.
  - `swift build` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.

## 2026-05-23 02:46 IST

- Added previewed cleanup for malformed direct Codex web/network values:
  - `CompatibilityView` now offers exact preview/apply removals for malformed `tools.web_search` and `features.network_proxy` assignments when the file can be safely rewritten.
  - Covered top-level assignments, `[tools] web_search`, `[features] network_proxy`, `[profiles.<name>] tools.web_search` / `features.network_proxy`, `[profiles.<name>.tools] web_search`, and `[profiles.<name>.features] network_proxy`.
  - Direct malformed members such as `context_size`, `allowed_domains`, proxy booleans, proxy `mode`, and proxy URL strings can be removed from dotted keys, exact sections, or single-line inline tables when removal leaves other keys.
  - Nested web-search location fields, network proxy domain rules, Unix socket rules, multiline inline tables, and empty-result inline rewrites remain manual.
- Re-verified the official Codex config reference for `tools.web_search` accepted object members and `features.network_proxy` boolean/string/mode/map keys.
- Used three read-only sidecar agents for scanner subject-path mapping, focused test design, and UX copy boundaries; all will be closed after validation.
- Validation:
  - `swift test --filter ConfigWriterSettingsRepairTests/testRemovesMalformedDirectTopLevelAndExactSectionWebNetworkAssignmentsWithoutPrefixMatching` passed.
  - `swift test --filter ConfigWriterSettingsRepairTests/testRemovesMalformedDirectProfileWebNetworkAssignmentsWithoutTouchingSiblings` passed.
  - `swift test --filter CompatibilityContextSettingsTests/testMalformedDirectCodexWebAndNetworkValuesAreReportedInExactAndProfileParentSections` passed.
  - `swift test --filter ConfigWriterSettingsRepairTests` passed with 37 tests.
  - `swift test --filter CompatibilityContextSettingsTests` passed with 37 tests.
  - `swift test` passed with 143 tests at 2026-05-23 03:12 IST.
  - `swift build` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.

- Added previewed cleanup for unknown keys inside single-line Codex web/network inline tables:
  - `tools.web_search = { ... }` and `features.network_proxy = { ... }` can now remove selected unknown members at top level while preserving documented pairs, nested proxy maps, spacing, and trailing comments.
  - Profile-scoped inline tables are covered in both direct profile sections such as `[profiles.fast] tools.web_search = { ... }` / `features.network_proxy = { ... }` and parent sections such as `[profiles.fast.tools] web_search = { ... }` / `[profiles.fast.features] network_proxy = { ... }`.
  - Nested inline `tools.web_search.location`, `features.network_proxy.domains`, and `features.network_proxy.unix_sockets` entries remain manual unless an existing dotted/section-key cleanup path can remove the exact field.
  - The issue-sheet copy now says same-profile and sibling-profile boundaries explicitly instead of implying all profiles are untouched.
- Re-verified the official Codex config reference for documented `tools.web_search` and `features.network_proxy` settings before wiring the fix path.
- Used three read-only sidecar agents for inline repair-target mapping, focused test review, and UX copy review; all will be closed after validation.
- Validation:
  - `swift test --filter ConfigWriterSettingsRepairTests/testRemovesInlineWebSearchKeysWithoutTouchingKnownPairs` passed.
  - `swift test --filter ConfigWriterSettingsRepairTests/testRemovesInlineNetworkProxyKeysWithoutTouchingKnownPairs` passed.
  - `swift test --filter ConfigWriterSettingsRepairTests/testInlineWebAndNetworkCleanupSkipsAmbiguousOrEmptyResults` passed.
  - `swift test --filter CompatibilityContextSettingsTests/testInlineCodexWebAndNetworkUnknownKeysAreReportedAtTopLevelAndProfile` passed.
  - `swift test --filter ConfigWriterSettingsRepairTests` passed with 35 tests.
  - `swift test --filter CompatibilityContextSettingsTests` passed with 36 tests.
  - `swift test` passed with 140 tests at 2026-05-23 03:00 IST.
  - `swift build` passed.
  - `git diff --check` passed.

- Added previewed cleanup for unknown keys inside single-line Codex `sandbox_workspace_write` inline tables:
  - `ConfigWriter` can now remove selected members from `sandbox_workspace_write = { ... }` while preserving documented pairs, arrays, spacing, and trailing line comments.
  - The helper can target top-level inline assignments and profile parent sections such as `[profiles.fast]`.
  - Ambiguous multiline inline tables and edits that would leave an empty inline table are skipped instead of rewritten.
  - Compatibility issue fixes now try the inline-table path for `Unknown Codex sandbox workspace-write key` findings after existing dotted-key/section-key cleanup attempts fail.
  - The issue-sheet copy now avoids overpromising that profile sections are never touched.
- Re-verified the official Codex config reference for documented `sandbox_workspace_write` keys: `network_access`, `writable_roots`, `exclude_slash_tmp`, and `exclude_tmpdir_env_var`.
- Used three read-only sidecar agents for repair-target mapping, TOML writer edge cases, and UX copy review; all will be closed after validation.
- Validation:
  - `swift test --filter ConfigWriterSettingsRepairTests/testRemovesInlineSandboxWorkspaceWriteKeysWithoutTouchingKnownPairs` passed.
  - `swift test --filter ConfigWriterSettingsRepairTests/testInlineSandboxWorkspaceWriteRemovalSkipsAmbiguousOrEmptyResults` passed.
  - `swift test --filter CompatibilityContextSettingsTests/testInlineSandboxWorkspaceWriteAndProfileGranularSectionsAreReported` passed.
  - `swift test --filter ConfigWriterSettingsRepairTests` passed with 32 tests.
  - `swift test --filter CompatibilityContextSettingsTests` passed with 35 tests.
  - `swift test` passed with 136 tests at 2026-05-23 02:50 IST.
  - `swift build` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.

## 2026-05-23 02:39 IST

- Preserved documented Codex MCP timeout metadata:
  - `ServerEntry`, the full Codex TOML reader, the Compatibility scanner, copied Markdown reports, edit-sheet saves, and Codex TOML write previews now retain `startup_timeout_sec`, `startup_timeout_ms`, and `tool_timeout_sec`.
  - Live MCP Verify now uses `startup_timeout_sec`/`startup_timeout_ms` as one bounded startup budget for stdio initialize plus `tools/list`, and as the bounded budget for remote probes.
  - `tool_timeout_sec` is intentionally preserved as metadata only here because the current Verify flow does not execute arbitrary server tools.
  - Codex TOML parsing now accepts decimal numeric values used by timeout settings.
- Incorporated sub-agent review:
  - Health review confirmed startup timeout should drive probes while tool timeout remains per-tool metadata.
  - UI review identified edit-sheet preservation and copied-report metadata gaps; both are now covered.
  - Model/scanner review confirmed the reader/model bridge and focused timeout tests.
- Validation:
  - `swift test --filter FullConfigReaderTests` passed.
  - `swift test --filter CompatibilityMCPAuthTests` passed.
  - `swift test --filter MCPHealthCheckerTests/testVerifyStdioUsesConfiguredStartupTimeout` passed.
  - `swift test --filter ConfigWriterSettingsRepairTests/testCodexPreviewWritePreservesEnvHeadersAndEnvVars` passed.
  - `swift test --filter MCPHealthCheckerTests` passed with 14 tests.
  - `swift test` passed with 134 tests at 2026-05-23 02:39 IST.
  - `swift build` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.

## 2026-05-22 13:28 IST

- Added target-scope UX filtering to the Compatibility tab:
  - Users can now filter the scan view by All, Project, Global, CLI, or Desktop.
  - Summary counts, live verification, settings/project surfaces, findings, and the compatibility matrix now respect the selected target.
  - Verify now runs only against MCP servers visible for the selected target.
- Confirmed the current tree already includes previewed fixes for disabled and stale Codex `[[skills.config]]` overrides, so this slice avoided duplicating that work.
- Validation:
  - `swift package clean` passed.
  - `swift build` passed with the pre-existing warnings in `SkillStore`, `LiveModeWindow`, `ProfileCopier`, and `ClaudeMdView`.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.
  - `swift test` was attempted, but the package has no test target.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the worktree-launched process was stopped afterward while the existing `/Applications/ProjectHub.app` process was left alone.
  - `git diff --check` passed.
  - `git diff --no-index --check /dev/null` produced no whitespace warnings for the edited compatibility/import files.
  - `rg -n "[ \t]+$" Sources/ProjectHub/Core/ImportParser.swift Sources/ProjectHub/Core/CompatibilityScanner.swift Sources/ProjectHub/Views/CompatibilityView.swift agents/WORKLOG.md agents/STATUS.md` found no trailing whitespace.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the smoke-test process was stopped afterward.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.
  - `git diff --no-index --check /dev/null Sources/ProjectHub/Core/CompatibilityScanner.swift` produced no whitespace warnings.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the smoke-test process was stopped afterward.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.
  - `git diff --no-index --check /dev/null Sources/ProjectHub/Core/CompatibilityScanner.swift` produced no whitespace warnings.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the smoke-test process was stopped afterward.
  - `git diff --check` passed.
  - Edited compatibility-file trailing-whitespace scan passed.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the smoke-test process was stopped afterward.
  - `git diff --check` passed.
  - Edited compatibility-file trailing-whitespace scan passed.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the smoke-test process was stopped afterward.
  - `git diff --check` passed.
  - `git diff --no-index --check` reported no whitespace warnings for untracked compatibility files.
  - `rg -n "[ \t]+$" Sources/ProjectHub/Core/CompatibilityScanner.swift Sources/ProjectHub/Views/CompatibilityView.swift Sources/ProjectHub/Core/MCPHealthChecker.swift agents/WORKLOG.md agents/CHANGELOG.md agents/STATUS.md cowork/WORKLOG.md` found no trailing whitespace.
  - `bash build-app.sh` passed.
  - `ProjectHub.app` launched successfully and the worktree-launched process was stopped after verification.
  - `git diff --check` passed.
  - `git diff --no-index --check /dev/null Sources/ProjectHub/Views/CompatibilityView.swift` passed for the untracked compatibility view.
  - `bash build-app.sh` passed.

## 2026-05-22 13:22 IST

- Expanded settings/auth compatibility classification:
  - Codex CLI and Codex Desktop now both expose the shared Codex auth surface in the compatibility matrix.
  - Codex project `.codex/config.toml` files now warn when they contain machine-local provider/auth/profile/telemetry keys that Codex ignores at project scope.
  - Codex `requirements.toml`, admin config, and managed config now surface as inspect-only policy/read-only context.
  - Codex approval/sandbox settings now flag deprecated or unrecognized values.
  - Missing Codex `auth.json` now checks `cli_auth_credentials_store`, `CODEX_ACCESS_TOKEN`, and `OPENAI_API_KEY` before reporting missing authentication.
- Validation:
  - Raw GitHub README fetch probe passed for `https://raw.githubusercontent.com/modelcontextprotocol/servers/HEAD/README.md`.
  - `swift package clean && swift build` passed with the pre-existing warnings in `SkillStore`, `LiveModeWindow`, `ProfileCopier`, and `ClaudeMdView`.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the worktree-launched process was stopped afterward while the existing `/Applications/ProjectHub.app` process was left alone.
  - `git diff --check` passed.
  - `git diff --no-index --check /dev/null Sources/ProjectHub/Core/CompatibilityScanner.swift` passed for the untracked scanner file.

## 2026-05-22 13:08 IST

- Verified current official Codex docs for MCP, skills, auth cache, and managed requirements, plus Claude Code MCP/settings docs.
- Extended compatibility scanning toward official Codex skill behavior:
  - Added repo skill surfaces for `.agents/skills` from selected working directory up to the repository root.
  - Added Codex `[[skills.config]]` parsing so disabled or stale skill overrides surface as compatibility findings.
  - Added `/etc/codex/skills` to the global skill inventory as the admin skill root.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.
  - Untracked `MCPHealthChecker.swift` whitespace check passed.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the worktree-launched process was stopped afterward while the existing `/Applications/ProjectHub.app` process was left alone.
  - `git diff --check` passed.
  - `bash build-app.sh` passed.
  - `ProjectHub.app` launched successfully and was stopped after process verification.
  - `bash build-app.sh` passed.
  - `ProjectHub.app` launched successfully and was stopped after process verification.

## 2026-05-22 13:09 IST

- Added previewable compatibility fix actions for writable MCP findings:
  - Disabled servers can be enabled from the finding sheet when the target surface supports safe file writes.
  - Broken servers with missing commands, missing launch targets, or unsupported transports can be removed with a before/after diff preview.
  - ConfigWriter now previews remove/enable changes and applies enable/disable across user and project scopes with backups.
- Validation:
  - `swift build` passed.

## 2026-05-22 13:10 IST

- Expanded MCP import support:
  - README code blocks, direct hosted MCP URLs, array/wrapped configs, `mcp` wrappers, npx/npm, uv/Python, Docker, and tool-specific `mcp add` commands now parse into importable server configs.
  - GitHub repository and archive/download references now produce explicit guidance instead of a generic JSON error.
  - Import sheet copy now reflects supported paste shapes, including `mcp.json` and `mcp-fetch.json` URLs.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.

## 2026-05-22 13:12 IST

- Tightened explicit MCP verification for local stdio servers.
- The Verify action now performs initialize, sends `notifications/initialized`, then requires a parseable `tools/list` response before marking a stdio MCP server as working.
- Updated the MCP verify button help text to describe initialize/tools-list verification.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.

## 2026-05-22 13:15 IST

- Added a previewed file fix for Claude Code settings where the same MCP server appears in both `enabledMcpjsonServers` and `disabledMcpjsonServers`.
- The repair recomputes the current overlap from disk, removes only duplicate disabled approvals, preserves enabled approvals, and writes through `ConfigWriter` backups.
- Updated the compatibility sheet copy to show "Previewed file fix", explicit will-change / will-not-change notes, backup behavior, and clearer restart language.
- Reclassified Claude MCP approval overlaps as conflict findings instead of broken findings.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.

## 2026-05-22 13:15 IST

- Added live MCP verification to the Compatibility tab:
  - The tab now has a Verify action that runs live checks for scanned MCP observations and shows per-server live results separately from static findings.
  - Compatibility observations can now convert back into `ServerEntry` values for the shared health checker.
  - Remote streamable HTTP checks now run initialize, initialized notification, and `tools/list` where the endpoint supports it; SSE endpoints are probed as endpoint availability.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.

## 2026-05-22 13:22 IST

- Added explicit project/settings observations to the compatibility scan:
  - Settings files now surface as first-class scan results with path, scope, write method, restart requirement, detected keys, and a short control summary.
  - Claude project local settings now warn if `.claude/settings.local.json` exists in a git repo without an explicit `.gitignore` entry.
  - Codex global project tables now warn when they overlap with checked-in project `.codex/config.toml` settings for the same project.
  - The Compatibility tab now shows a compact Settings & Project section before findings so users can see which files are controlling tool behavior.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed for tracked files.
  - `rg -n "[ \t]+$" Sources/ProjectHub/Core/CompatibilityScanner.swift Sources/ProjectHub/Views/CompatibilityView.swift` found no trailing whitespace in the edited untracked compatibility files.

## 2026-05-22 13:16 IST

- Refreshed full app validation after the compatibility fix and protocol updates.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.
  - `bash build-app.sh` passed.
  - `ProjectHub.app` launched successfully and was stopped after process verification.

## 2026-05-22 13:16 IST

- Added a previewed Codex settings repair for stale `[[skills.config]]` overrides that point at missing `SKILL.md` files.
- The repair resolves relative and tilde paths from the owning config file, removes only stale array-table sections, and writes through the existing TOML backup path.
- Restored the scanner's settings observation path so Claude/Codex settings files report parsed keys and project-setting overlap findings.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.
  - `bash build-app.sh` passed.
  - `ProjectHub.app` launched successfully and was stopped after process verification.

## 2026-05-22 13:24 IST

- Added a previewed Codex skill enable repair for intentionally disabled installed skills.
- Skill disabled findings now include the exact `SKILL.md` path so the issue sheet can target the matching `[[skills.config]]` entry.
- ConfigWriter can preview and apply a single `enabled = true` update for a Codex skill override through the existing TOML backup path.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.

## 2026-05-22 13:29 IST

- Re-verified official Codex skill docs:
  - Codex reads repo/user/admin/system skill roots.
  - `[[skills.config]]` supports per-skill `path` and `enabled`.
  - Codex should be restarted after changing `~/.codex/config.toml`.
- Hardened disabled-skill fixes:
  - Override paths now normalize both skill folders and `SKILL.md` files to the canonical `SKILL.md` target.
  - `skill.disabled` findings carry a structured subject path instead of relying on issue text.
  - The enable repair now refuses stale, duplicate, already-enabled, or ambiguous override sections.
- Completed the Compatibility tab target filter backing model for all, global, project, CLI, and desktop scopes.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.
  - `bash build-app.sh` passed.
  - `ProjectHub.app` launched successfully and was stopped after process verification.

## 2026-05-22 13:29 IST

- Added explicit project selection to the top-level Compatibility tab so scans no longer silently use the first known project.
- Added an All / Project / Global / CLI / Desktop target filter that scopes summary counts, live verification targets, settings, findings, and the matrix.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.
  - `rg -n "[ \t]+$" Sources/ProjectHub/Core/CompatibilityScanner.swift Sources/ProjectHub/Core/MCPHealthChecker.swift Sources/ProjectHub/Views/CompatibilityView.swift agents/WORKLOG.md cowork/WORKLOG.md` found no trailing whitespace in the edited untracked compatibility files.

## 2026-05-22 13:36 IST

- Expanded MCP import normalization for more real-world distribution examples:
  - `serverUrl`, `server_url`, and endpoint-style remote fields now normalize to `url`.
  - command arrays and single-string launch commands like `docker run ...` normalize to command plus args.
  - `environment`, `arguments`, simple npm package metadata, uvx/python package metadata, and Docker image metadata normalize into installable MCP configs when possible.
- Import still rejects GitHub repository URLs, archives, and wizard-style installers unless the user provides an explicit command or JSON config.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.
  - Parser probe passed for `serverUrl` arrays, single-string Docker commands, and npm package metadata.
  - `rg -n "[ \t]+$" Sources/ProjectHub/Core/ImportParser.swift agents/WORKLOG.md cowork/WORKLOG.md` found no trailing whitespace in the edited files.

## 2026-05-22 13:40 IST

- Added skill version metadata to the compatibility scanner and now flags version conflicts when the same tool sees multiple installed versions of a skill.
- Added a Compatibility tab Skills section that shows target-filtered skill availability, scope, path, version, parse/disabled status, and which supported apps can use each skill.
- Codex skill availability now appears under both CLI and Desktop filters when the same user-authored skill root applies to both surfaces.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.
  - `rg -n "[ \t]+$" Sources/ProjectHub/Core/CompatibilityScanner.swift Sources/ProjectHub/Views/CompatibilityView.swift agents/WORKLOG.md cowork/WORKLOG.md` found no trailing whitespace in the edited files.

## 2026-05-22 13:45 IST

- Normalized existing MCP launch configs during compatibility scanning and live health checks:
  - command arrays are treated as command plus args.
  - single-string launch commands from known runtimes (`docker run ...`, `npx ...`, `uvx ...`, `python3 ...`, etc.) are split before command-existence checks and live process launch.
- This prevents false broken states where Project Hub looked for an executable named the entire launch string.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.
  - Focused health probe for `command = "docker run -i --rm ghcr.io/github/github-mcp-server"` now reports `Command not found: docker`, proving the launch string is normalized before preflight.
  - `rg -n "[ \t]+$" Sources/ProjectHub/Core/CompatibilityScanner.swift Sources/ProjectHub/Core/MCPHealthChecker.swift agents/WORKLOG.md cowork/WORKLOG.md` found no trailing whitespace in the edited files.

## 2026-05-22 13:48 IST

- Added a target-filtered Manual Actions section to the Compatibility tab.
- The section summarizes login/auth, restart, runtime-managed, credential-store, managed-policy, and live verification follow-ups so users can see app-owned work without digging through every finding.
- Manual action rows open the existing issue sheet when the action comes from a scanner finding; live verification follow-ups remain read-only rows with the probe summary and hint.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.
  - `bash build-app.sh` passed.
  - `ProjectHub.app` launched from the worktree build and was stopped after process verification.
  - `rg -n "[ \t]+$" Sources/ProjectHub/Views/CompatibilityView.swift agents/WORKLOG.md cowork/WORKLOG.md` found no trailing whitespace in the edited files.

## 2026-05-22 13:35 IST

- Re-verified official Anthropic docs for Claude Desktop enterprise/device policy:
  - Claude Desktop reads macOS MDM preferences from `com.anthropic.claudefordesktop`.
  - Managed preference locations include per-user and machine-wide plist paths.
  - Relevant controls include local MCP, desktop extensions, extension directory access, Desktop Code, signature requirements, and managed MCP servers.
- Added `plist` as a compatibility config format and registered read-only Claude Desktop policy surfaces for:
  - `/Library/Managed Preferences/<user>/com.anthropic.claudefordesktop.plist`
  - `/Library/Managed Preferences/com.anthropic.claudefordesktop.plist`
  - `~/Library/Preferences/com.anthropic.claudefordesktop.plist`
  - `/Library/Managed Preferences/<user>/com.anthropic.Claude.plist`
  - `/Library/Managed Preferences/com.anthropic.Claude.plist`
- Added plist parsing, settings summaries, and findings for disabled local MCP, disabled extensions, disabled Desktop Code, VM feature policy, signature-required policy, and admin-managed MCP servers.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.
  - `rg -n "[ \t]+$" Sources/ProjectHub/Core/CompatibilityScanner.swift agents/WORKLOG.md agents/STATUS.md` found no trailing whitespace.

## 2026-05-22 13:38 IST

- Added Claude Desktop project launch settings to the compatibility matrix:
  - Scans `.claude/launch.json` for selected projects.
  - Summarizes preview configurations, `autoVerify`, and launch file version keys.
  - Marks it as a project-scoped Desktop settings surface rather than an MCP server surface.
- Added `.claude/launch.json` as a project-root marker so Desktop Code preview/dev-server-only projects are easier to detect.
- Cleaned the existing Swift concurrency warning in `ProjectStore.scan()` by keeping the filesystem discovery work in a detached task and mutating the store from the actor-inherited task.
- Validation:
  - `swift build` passed without warnings.
  - `git diff --check` passed.
  - `rg -n "[ \t]+$" Sources/ProjectHub/Core/CompatibilityScanner.swift Sources/ProjectHub/Stores/ProjectStore.swift agents/WORKLOG.md agents/STATUS.md` found no trailing whitespace.

## 2026-05-22 13:38 IST

- Added experimental read-only Claude Desktop MCPB/DXT extension detection:
  - Scans installed extension directories for `manifest.json` or `manifest.mcpb.json`.
  - Parses `server.mcp_config`, expands only `${__dirname}`, and preserves Claude-owned `${user_config.*}` placeholders.
  - Reads per-extension `Claude Extensions Settings/*.json` to classify disabled extensions and missing required user config.
  - Treats extension runtime, credentials, and health as Claude Desktop-managed, so Project Hub does not launch or edit extension internals.
- Reconfirmed that official docs expose the install UI, manifest semantics, secure storage, logs, and policy controls, but not a stable writeable extension registry path.
- Validation:
  - `swift build` passed.

## 2026-05-22 13:38 IST

- Tightened Compatibility health messaging for Claude Desktop extensions:
  - Cleanly parsed DXT/MCPB extensions now show app-managed health guidance instead of suggesting Project Hub live-launch them.
  - Live MCP verification still skips Claude Desktop extension internals.
- Added a safe settings fix for deprecated Codex approval policy:
  - `settings.deprecated-value` findings for writable Codex TOML configs can now preview replacing top-level `approval_policy = "on-failure"` with `approval_policy = "on-request"`.
  - The writer preserves inline comments, only edits the top-level string assignment, and writes through the existing timestamped TOML backup path.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.
  - `git diff --no-index --check /dev/null` passed for edited untracked compatibility files.
  - `bash build-app.sh` passed and rebuilt `ProjectHub.app`.
  - Launch smoke opened the worktree `ProjectHub.app`; the smoke-test process was stopped afterward.

## 2026-05-22 13:45 IST

- Added a safe repair for `project.local-settings-tracked` findings:
  - Compatibility issue sheets can now preview appending `.claude/settings.local.json` to the selected project's `.gitignore`.
  - The repair writes only `.gitignore`, preserves existing content, and leaves Claude settings, MCP servers, credentials, skills, and project files untouched.
- Verified the current scanner's launch-command helper is present for command arrays and command strings used by health and log diagnostics.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the smoke-test process was stopped afterward.

## 2026-05-22 13:45 IST

- Added read-only Claude Desktop MCP log diagnostics:
  - Matches configured Claude Desktop local MCP servers and MCPB/DXT extensions to recent `~/Library/Logs/Claude/mcp-server-*.log` files.
  - Classifies recent log signals for OAuth/auth-required flows, missing command/module/runtime errors, MCP timeouts, upstream/remote server errors, and initialize/tools-list protocol trouble.
  - Redacts URLs, email addresses, and token-like query fragments before surfacing short log excerpts in Compatibility findings.
  - Leaves successful recent server-start/result lines quiet to avoid noisy findings after a recovered launch.
- Restored and consolidated scanner launch-command parsing for string, array, and shell-style command forms so command previews and health entries stay consistent.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.
  - `rg -n "[ \t]+$" Sources/ProjectHub/Core/CompatibilityScanner.swift agents/WORKLOG.md agents/STATUS.md` found no trailing whitespace.

## 2026-05-22 13:45 IST

- Added MCPB/DXT archive import handoff:
  - Import sheet can choose local `.mcpb`, `.dxt`, and `.zip` desktop-extension archives.
  - Project Hub reads the archive manifest with `/usr/bin/unzip`, previews name/version/author/launch command/tools/required user config, and does not write Claude Desktop extension internals.
  - The handoff button opens the archive with macOS so Claude Desktop's official installer can complete the install.
  - Remote archive URLs now prompt the user to download locally first instead of fetching binary archive data as JSON.
- Validation:
  - `swift build` passed after a transient SwiftPM "file modified during build" rerun.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the worktree-launched process was stopped after process verification.
  - `git diff --check` passed.
  - `git diff --no-index --check /dev/null` reported no whitespace warnings for edited untracked compatibility/import files.
  - `rg -n "[ \t]+$" Sources/ProjectHub/Core/CompatibilityScanner.swift Sources/ProjectHub/Core/ImportParser.swift Sources/ProjectHub/Views/MCPImportSheet.swift Sources/ProjectHub/Views/CompatibilityView.swift Sources/ProjectHub/Core/MCPHealthChecker.swift agents/WORKLOG.md agents/CHANGELOG.md agents/STATUS.md cowork/WORKLOG.md` found no trailing whitespace.
  - `bash build-app.sh` passed.
  - `ProjectHub.app` launched successfully and the worktree-launched process was stopped after verification.

## 2026-05-22 13:56 IST

- Re-verified Codex CLI/Desktop config behavior through official OpenAI docs and local installed evidence:
  - Codex user config is `~/.codex/config.toml`; project config is `.codex/config.toml`.
  - Project config is only loaded for trusted projects.
  - Codex app, CLI, and IDE share the same agent/MCP config file, while app-only UI/runtime preferences remain app-managed.
  - Official Codex skill roots are repo `.agents/skills`, user `~/.agents/skills`, admin `/etc/codex/skills`, plus system/bundled skills.
- Added Codex trust detection for project-local `.codex/config.toml`:
  - Compatibility scans now warn when a selected project has Codex project config but the user-level config does not mark that project trusted.
  - The issue sheet can preview adding/updating `[projects."<path>"] trust_level = "trusted"` in the user-level Codex config.
  - Project files, MCP tables, auth files, skills, and admin/managed policy files remain untouched by that fix.
- Added a previewed repair for Codex project-setting overlap:
  - When user-level `[projects]` settings and checked-in `.codex/config.toml` duplicate the same supported keys, Project Hub can preview removing the duplicate top-level keys from the project file while keeping the user-level override.
- Validation:
  - `swift package clean && swift build` passed, surfacing only pre-existing warnings in unrelated files.
  - `git diff --check` passed.
  - `git diff --no-index --check /dev/null` reported no whitespace warnings for edited untracked compatibility files.
  - `rg -n "[ \t]+$" Sources/ProjectHub/Core/ConfigWriter.swift Sources/ProjectHub/Core/CompatibilityScanner.swift Sources/ProjectHub/Views/CompatibilityView.swift Sources/ProjectHub/Core/ImportParser.swift Sources/ProjectHub/Views/MCPImportSheet.swift agents/WORKLOG.md agents/CHANGELOG.md agents/STATUS.md cowork/WORKLOG.md` found no trailing whitespace.
  - `bash build-app.sh` passed.
  - `ProjectHub.app` launched successfully and the worktree-launched process was stopped after verification.

## 2026-05-22 13:48 IST

- Added a safe repair for `project.settings-ignored` Codex findings:
  - Compatibility issue sheets can now preview removing ignored project-local Codex keys and sections from `.codex/config.toml`.
  - The cleanup removes only known ignored project-local settings such as provider/profile/telemetry routing keys and sections.
  - MCP server tables, valid project settings, global Codex config, auth files, and skills stay untouched.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.
  - Edited compatibility-file trailing-whitespace scan passed.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the smoke-test process was stopped afterward.

## 2026-05-22 13:55 IST

- Replaced the generic manual-fix note in Compatibility issue sheets with issue-specific remediation cards:
  - Auth, expired auth, OAuth, and credential-store findings now guide users to official login/connector flows without asking Project Hub to store secrets.
  - Missing environment variable findings now appear in Manual Actions and explain launch-environment remediation.
  - Restart-required findings now explain app/CLI reload expectations after config writes.
  - Managed-policy/runtime and unknown-health findings now stay read-only while pointing users to the owner surface.
- Added small issue-sheet actions to reveal evidence files, open Claude Desktop for Claude Desktop-owned findings, and copy a checklist for handoff/debugging.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the worktree-launched process was stopped after process verification.
  - The build still reports pre-existing warnings in `SkillStore`, `LiveModeWindow`, `ProfileCopier`, and `ClaudeMdView`.

## 2026-05-22 13:59 IST

- Productized disabled/conflict review in the Compatibility tab:
  - Disabled MCP servers and disabled skills now appear in Manual Actions, with guidance to either keep them intentionally disabled or use a previewed Enable action when available.
  - Duplicate MCP server names, conflicting MCP definitions, duplicate skills, version conflicts, and shadowed project settings now appear as explicit review actions.
  - Conflict guidance tells users to compare paths/scopes and avoid guessing which duplicate should win across CLI, desktop, and project scopes.
- Validation:
  - `swift build` passed after a transient SwiftPM "file modified during build" rerun.

## 2026-05-22 14:00 IST

- Added an Authentication overview to the Compatibility tab:
  - Auth surfaces now show as first-class status rows instead of only appearing as findings.
  - The row distinguishes readable auth evidence, missing/expired auth findings, credential-store hints, and app/runtime-managed login state.
  - Rows with actionable auth findings open the same issue sheet and manual remediation checklist.
- Expanded the Compatibility Matrix row badges:
  - The matrix now exposes Auth coverage, config format, and write ownership such as Preview write, CLI-owned, App-owned, Runtime-only, or Read-only.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.
  - `git diff --no-index --check /dev/null Sources/ProjectHub/Views/CompatibilityView.swift` produced no whitespace warnings.
  - `rg -n "[ \t]+$" Sources/ProjectHub/Views/CompatibilityView.swift agents/WORKLOG.md agents/STATUS.md` found no trailing whitespace.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the smoke-test process was stopped afterward.

## 2026-05-22 13:59 IST

- Improved MCP import coverage for config-file distribution:
  - The import sheet can now choose local JSON config files such as `mcp.json` and `mcp-fetch.json`, read them into preview, and keep the existing preview-before-write flow.
  - The parser now unwraps nested MCP config shapes such as `{ "mcp": { "servers": ... } }`.
  - The parser also accepts common `tools` maps seen in older MCP examples while preserving the existing `mcpServers`, `servers`, and command/URL handling.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the worktree-launched process was stopped after process verification.

## 2026-05-22 13:54 IST

- Productized restart follow-ups after safe fixes:
  - Compatibility now keeps a visible Manual Actions item after applying a previewed fix that requires a Claude/Codex restart or session reload.
  - The follow-up includes the changed path and tells the user to restart/reopen the affected app or session before running Verify.
  - The fix still closes the sheet and rescans immediately, but the restart requirement no longer disappears with the fixed finding.
- Validation:
  - `swift build` passed.

## 2026-05-22 14:03 IST

- Added read-only Codex Desktop App state coverage to the Compatibility scanner:
  - Codex Desktop now has explicit settings surfaces for `~/Library/Preferences/com.openai.codex.plist` and `~/Library/Application Support/Codex`.
  - The scanner distinguishes shared agent config in `~/.codex/config.toml` from Desktop UI/runtime state in macOS preferences and Application Support.
  - Directory settings summaries show app-state evidence such as session storage, browser partitions, sidebar local-server state, and caches without parsing or writing private runtime data.
- Revalidated the current combined scanner after context-file surface changes landed in the same worktree:
  - Markdown/context surfaces for Claude/Codex project instruction files now compile with the current enum cases.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.
  - `git diff --no-index --check /dev/null Sources/ProjectHub/Core/CompatibilityScanner.swift` produced no whitespace warnings.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the smoke-test process was stopped afterward.

## 2026-05-22 14:07 IST

- Added official Claude Code JSON command import support:
  - `claude mcp add-json <name> '{...}'` now parses into the same previewed import flow as pasted JSON and README command blocks.
  - Optional command flags such as `--scope` are skipped while preserving the requested server name and normalized server config.
- Completed read-only project instruction-file compatibility scanning:
  - The matrix now includes `CLAUDE.md` for Claude Code and `AGENTS.md` for Codex CLI/Desktop as context surfaces.
  - Markdown instruction files appear in Settings & Project with heading/line summaries.
  - Scans now warn when only one of `CLAUDE.md` or `AGENTS.md` exists, so users do not assume Claude and Codex share project context automatically.
  - Context surfaces get an explicit Context badge in the compatibility matrix.
- Validation:
  - `swift build` passed.

## 2026-05-22 17:28 IST

- Expanded Codex instruction/context compatibility scanning from the official AGENTS discovery rules:
  - Codex CLI/Desktop now surface global `AGENTS.override.md` and `AGENTS.md` from CODEX_HOME as read-only context files.
  - Project scans now walk from repository root to the selected working directory and expose `AGENTS.override.md`, `AGENTS.md`, and configured `project_doc_fallback_filenames` candidates for each directory.
  - Empty instruction files are called out because Codex skips them.
  - Files above `project_doc_max_bytes` now produce a warning so users know project guidance may be truncated or later guidance skipped.
  - Shadowed same-directory Codex instruction files now appear as explicit findings instead of looking equally active.
  - The Compatibility UI labels the section as Settings & Context and uses a document icon for instruction-file observations.
- Validation:
  - `swift package clean` passed.
  - `swift build` passed with the pre-existing warnings in `SkillStore`, `LiveModeWindow`, `ProfileCopier`, and `ClaudeMdView`.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.
  - `swift test` was attempted, but the package has no test target.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the worktree-launched process was stopped afterward while the existing `/Applications/ProjectHub.app` process was left alone.

## 2026-05-22 17:33 IST

- Added guarded create-file fixes for missing cross-tool project instruction files:
  - A missing Codex project instruction finding now targets `AGENTS.md` by default instead of `AGENTS.override.md`.
  - When `CLAUDE.md` exists but no non-empty Codex project instruction file exists, the issue sheet can preview creating `AGENTS.md` from the current `CLAUDE.md`.
  - When Codex guidance exists but `CLAUDE.md` is missing, the issue sheet can preview creating `CLAUDE.md` from the active Codex instruction file.
  - The writer refuses to overwrite an existing instruction file and only writes UTF-8 text after showing a before/after diff.
  - The preview text now says backups are created before replacing existing files, which avoids implying a backup exists for brand-new instruction files.
- Validation:
  - `swift build` passed.

## 2026-05-22 17:37 IST

- Improved GitHub MCP import handoff without running repository installers:
  - From URL now accepts GitHub repository URLs and fetches their `README.md` through `raw.githubusercontent.com/<owner>/<repo>/HEAD/README.md`.
  - From URL now accepts GitHub `blob` URLs and converts them to raw file URLs before fetching.
  - Fetched GitHub README/raw content is passed through the existing README code-block, command, JSON, and URL parser.
  - Archive URLs still prompt users to download locally and choose the MCPB/DXT archive for manifest validation.
  - Paste-mode GitHub repository errors now point users to the From URL README fetch path.
  - Verified the raw README fetch path against `modelcontextprotocol/servers`.
- Validation:
  - `swift build` passed.

## 2026-05-22 17:41 IST

- Improved live MCP Verify auth classification:
  - JSON-RPC initialize and tools/list errors that mention OAuth, unauthorized/forbidden, login, missing/invalid token, or API key failures now report `Needs auth` instead of generic broken runtime state.
  - Stdio startup stderr with auth signals now reports `Needs auth` when no initialize response arrives.
  - Expired-token style messages get a refresh-specific hint.
  - Stderr/error excerpts shown in health summaries redact common bearer token, token, API key, secret, and password patterns.
- Validation:
  - `swift build` passed.

## 2026-05-22 17:44 IST

- Added a concrete Compatibility report artifact:
  - The Compatibility toolbar now has a copy-report button.
  - The copied Markdown includes generation time, target filter, project root, counts, health summary, live Verify results when present, the target-filtered compatibility matrix, findings, and MCP server inventory.
  - Matrix export rows include tool, surface, scope, kind, format, write ownership, restart requirement, and path.
  - The export uses the current target filter so users can produce All, Project, Global, CLI, or Desktop reports.
- Validation:
  - `git diff --check` passed.
  - Focused trailing-whitespace scan passed for `CompatibilityView.swift`, `agents/STATUS.md`, `agents/WORKLOG.md`, and `cowork/WORKLOG.md`.
  - `swift build` passed.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the worktree-launched process was stopped afterward while the existing `/Applications/ProjectHub.app` process was left alone.

## 2026-05-23 02:23 IST

- Tightened Codex MCP auth/environment classification:
  - Static Compatibility scans now treat `mcp_servers.<id>.env_http_headers` values as environment-backed header credentials.
  - Static Compatibility scans now treat local Codex `env_vars` entries as required local environment variables while ignoring `source = "remote"` entries.
  - Live MCP health checks now apply missing local `env_vars` to remote MCP servers as well as stdio servers.
  - The lightweight Compatibility TOML MCP reader now accepts multi-line collection values while parsing Codex MCP server tables.
  - Added focused coverage for Codex `env_http_headers` plus local/remote `env_vars` auth classification and remote-server `env_vars` health classification.
- Research/coordination:
  - Rechecked the official Codex config reference for `mcp_servers.<id>.env_http_headers` and `mcp_servers.<id>.env_vars`.
  - Used three read-only sidecar agents for model/reader, health/auth, and UI/report touch-point review; all are closed after this batch.
- Validation:
  - `swift test --filter MCPHealthCheckerTests` passed with 13 tests.
  - `swift test --filter CompatibilityMCPAuthTests` passed with 1 test.
  - `swift test --filter FullConfigReaderTests` passed with 1 test.
  - `swift test` passed with 133 tests.

## 2026-05-22 17:54 IST

- Expanded downloaded MCP archive import support:
  - Local `.zip` archives without MCPB/DXT manifests now fall back to safe source-archive inspection.
  - Local `.tar.gz` and `.tgz` archives can be inspected for `mcp.json`, `mcp-fetch.json`, Claude Desktop config examples, README files, docs, examples, and install snippets.
  - The scanner reads allowlisted text/config entries only, skips common noisy folders/lockfiles, samples large text files, and never executes archive contents.
  - Import preview now shows which archive file/config snippet produced the candidate server list before the user chooses target apps and scope.
  - Added a SwiftPM test target with focused archive parser tests for `.zip` README snippets and `.tar.gz` `mcp.json`.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.
  - Focused trailing-whitespace scan passed for `ImportParser.swift` and `MCPImportSheet.swift`.
  - `swift test` passed with 2 tests.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the worktree-launched process was stopped afterward while the existing `/Applications/ProjectHub.app` process was left alone.

## 2026-05-22 18:02 IST

- Hardened project-root detection for Claude/Codex compatibility:
  - `Project.canonicalize` now runs through a shared detector instead of returning only a symlink-resolved path.
  - The detector treats Git worktree `.git` files as project boundaries.
  - Selected file paths resolve through their containing directory before root detection.
  - Codex `[projects]` and Claude `~/.claude.json` configured project keys can anchor selected subdirectories when they are the nearest meaningful tool root.
  - Broad configured roots such as `/`, home, Desktop, Documents, Downloads, and Library are ignored.
  - Parent Codex trust entries no longer mask a nearer nested Git project.
  - Codex project discovery now respects `CODEX_HOME` for config and state database lookup.
  - Added SwiftPM tests for worktree `.git` files, Codex configured subdirectories, selected files, ignored broad roots, and parent-trust/nested-repo precedence.
- Validation:
  - `swift test` passed with 7 tests.
  - `swift build` passed.
  - `git diff --check` passed.
  - Focused trailing-whitespace scan passed for root-detector/test/canon files.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the worktree-launched process was stopped afterward while the existing `/Applications/ProjectHub.app` process was left alone.

## 2026-05-22 18:07 IST

- Added repeatable MCP health-check fixture coverage:
  - Healthy stdio fixture verifies initialize plus tools/list.
  - Stdio initialize auth errors classify as `Needs auth` and redact credential-looking diagnostics.
  - Placeholder launch credentials classify as `Needs auth` before execution.
  - Missing commands classify as `Broken`.
  - In-process remote HTTP fixture verifies initialize plus tools/list without internet access.
  - Remote HTTP 401 classifies as `Needs auth`.
- Validation:
  - `swift test --filter MCPHealthCheckerTests` passed with 6 tests.
  - `swift test` passed with 13 tests.
  - `swift build` passed.
  - `git diff --check` passed.
  - Focused trailing-whitespace scan passed for the health-check test and canon files.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the worktree-launched process was stopped afterward while the existing `/Applications/ProjectHub.app` process was left alone.

## 2026-05-22 18:16 IST

- Added explicit skill availability compatibility:
  - Compatibility scans now include per-tool skill support rows for Claude Code, Claude Desktop, Codex CLI, and Codex Desktop.
  - Claude Code reports filesystem skill support through `.claude/skills`.
  - Claude Desktop reports app/account-managed skill availability and no verified local filesystem write root.
  - Codex CLI reports user/admin/repository filesystem skill support and `[[skills.config]]` override awareness.
  - Codex Desktop now explicitly shares Codex filesystem skill roots, including `~/.agents/skills` and project `.agents/skills`.
  - The Compatibility tab shows a Skill Availability section and includes those rows in copied Markdown reports.
  - Added SwiftPM coverage proving all four primary tools produce explicit skill-support observations.
- Validation:
  - `swift test` passed with 14 tests.
  - `swift build` passed.
  - `git diff --check` passed.
  - Focused trailing-whitespace scan passed for the skill-support scanner/view/test files.
  - `bash build-app.sh` passed.
  - Launch smoke opened the worktree `ProjectHub.app`; the worktree-launched process was stopped afterward while the existing `/Applications/ProjectHub.app` process was left alone.

## 2026-05-23 03:24 IST

- Added previewed cleanup for malformed scalar Codex `permissions.<name>.network` values:
  - New Compatibility fix-plan branch removes whole invalid `permissions.<name>.network` assignments and invalid scalar child keys for `enabled`, `mode`, `proxy_url`/`socks_url`, and other documented boolean/string network fields.
  - Supported write shapes include top-level dotted keys, exact `[permissions.<name>.network]` sections, `[permissions.<name>]` dotted keys, `[permissions.<name>] network = ...` whole assignments, and safe single-line inline tables.
  - Repair copy explicitly avoids promising a generated replacement policy and leaves documented domain/socket rule maps, table-shape repairs, sibling permission profiles, MCP servers, auth files, skills, and managed policy files untouched.
  - Tightened the existing unknown permission-network key copy to call out documented domain and Unix socket rules as out of scope.
- Research/coordination:
  - Rechecked the official OpenAI Codex config reference for `permissions.<name>.network.*` typed keys.
  - Used three read-only sidecar agents for scanner/writer boundary review, test-shape review, and UX copy review; all three were closed after the batch completed.
- Validation:
  - `swift test --filter ConfigWriterSettingsRepairTests` passed with 39 tests.
  - `swift test --filter CompatibilityContextSettingsTests` passed with 37 tests.
  - `swift test` passed with 145 tests.
  - `swift build` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.

## 2026-05-23 03:36 IST

- Preserved registry remote header credentials for Codex imports:
  - Codex TOML writing now infers `env_http_headers` from exact `${ENV_VAR}` HTTP header placeholders, matching MCP Registry `server.json` remote headers that describe required secret header values.
  - Literal/static headers, bearer-template values such as `Bearer ${TOKEN}`, and app-owned prompt placeholders such as `${input:token}` remain ordinary `http_headers`.
  - Registry import parsing stays tool-neutral and does not add Codex-only metadata to parsed server configs, so JSON-target clients continue to receive normal `headers`.
- Tightened Compatibility follow-up UX:
  - Restart-required post-fix actions now tell users to restart/reopen, run Scan, and only run Verify for MCP server fixes.
- Research/coordination:
  - Rechecked the MCP Registry remote-server docs for `remotes[]`, URL variables, and secret HTTP headers.
  - Used a fresh read-only sidecar batch for broad gap audit, MCP import/auth audit, and UX workflow audit; all sidecar agents were closed after their task batch completed.
- Validation:
  - `swift test --filter ConfigWriterSettingsRepairTests` passed with 40 tests.
  - `swift test --filter ImportParserRegistryManifestTests` passed with 5 tests.
  - `swift test --filter ConfigWriterSettingsRepairTests/testCodexPreviewWriteInfersEnvHTTPHeadersFromPlaceholders` passed.
  - `swift test` passed with 146 tests.
  - `swift build` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.

## 2026-05-23 07:34 IST

- Expanded instruction/context compatibility surfaces:
  - Claude Code scans now preserve the selected file/subdirectory when walking project instruction surfaces, including active `CLAUDE.md` files, root `.claude/CLAUDE.md`, and `CLAUDE.local.md`.
  - Codex instruction surfaces now preserve the selected subdirectory instead of collapsing to the detected project root.
  - Cross-tool guidance drift now compares active same-directory Claude/Codex instruction files, including `AGENTS.override.md` and configured fallback filenames, and suppresses drift when Claude imports the active Codex file.
  - Same-directory import previews now reference the real source filename, such as `@AGENTS.override.md` or `@CONTRIBUTING.md`, instead of hardcoding `@AGENTS.md`.
- Research/coordination:
  - Rechecked the official Claude Code memory docs for `CLAUDE.md`, `.claude/CLAUDE.md`, `CLAUDE.local.md`, imports, and rules surfaces.
  - Rechecked the official Codex config docs for root-to-cwd project `.codex/config.toml` layering and configured fallback instruction filenames.
  - Used a read-only sidecar batch for code/status and docs/local gap review; both agents were closed after that batch completed.
  - Used a follow-up read-only verifier agent for this instruction/context slice; it found nested Codex-only guidance and same-directory source-scope gaps, which were patched, tested, and then the agent was closed.
- Validation:
  - `swift test --filter CompatibilityContextSettingsTests` passed with 44 tests before the verifier patch and 47 tests after it.
  - `swift test --filter 'CompatibilityContextSettingsTests|CompatibilitySkillSupportTests|ProjectRootDetectorTests'` passed with 71 tests.
  - `swift build` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace scan passed.
  - `swift test` passed with 228 tests.

## 2026-05-23 08:06 IST

- Added Claude Code rules and import diagnostics:
  - Compatibility now discovers user `~/.claude/rules/**/*.md` and project `.claude/rules/**/*.md` files as Claude Code context surfaces.
  - Rule summaries distinguish unconditional rules from path-scoped rules using `paths` frontmatter, including simple scalar, array, and YAML-list forms.
  - Claude Markdown context scans now extract inline and line-leading `@...` imports, resolve relative imports from the importing file, recurse through imported files up to Claude Code's documented five-hop limit, and report missing targets, directory imports, unreadable imports, import cycles, and over-depth chains.
  - Import-cycle tracking now uses canonical file paths rather than project-root canonicalization so different files in the same repo are not mistaken for cycles.
- Research/coordination:
  - Rechecked official Claude Code memory docs for `.claude/rules`, user rules, path-scoped rules, symlinked rules, `@` import resolution, recursive import limits, additional-directory loading, and `claudeMdExcludes`.
  - Used two read-only subagents for official-docs research and code insertion/test-shape review; both agents were closed after this batch completed.
- Validation:
  - `swift test --filter CompatibilityContextSettingsTests/testClaude` passed with 7 tests.
  - `swift test --filter CompatibilityContextSettingsTests` passed with 51 tests.
  - `swift build` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace/debug scan passed.
  - `swift test` passed with 232 tests.

## 2026-05-23 08:19 IST

- Added Claude Code memory exclusion and additional-directory context semantics:
  - `claudeMdExcludes` arrays are now read from Claude Code settings layers and applied to project/user Claude context surfaces by absolute-path glob, including `CLAUDE.md`, `CLAUDE.local.md`, `.claude/CLAUDE.md`, and `.claude/rules/**/*.md`.
  - Compatibility now recognizes documented `permissions.additionalDirectories` while preserving the older direct `additionalDirectories` reader for existing local configs.
  - Additional-directory Claude memory surfaces are only shown when `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` is observable; otherwise settings report that extra directory file access does not prove CLAUDE.md loading.
  - Additional-directory context surfaces include `CLAUDE.md`, `.claude/CLAUDE.md`, `.claude/rules/**/*.md`, and `CLAUDE.local.md` when the documented env gate is active.
  - External `@` imports outside the selected project and Claude user home now produce an approval-state-unknown finding and are not recursively read before user approval is verified.
- Research/coordination:
  - Rechecked official Claude Code memory/settings docs for `claudeMdExcludes`, `permissions.additionalDirectories`, `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD`, recursive imports, and external-import approval behavior.
  - Used two read-only subagents for official-docs research and code insertion/test-shape review; both agents were closed after this batch completed.
- Validation:
  - `swift test --filter CompatibilityContextSettingsTests/testClaude` passed with 11 tests.
  - `swift test --filter 'CompatibilityContextSettingsTests|CompatibilitySkillSupportTests'` passed with 68 tests.
  - `swift build` passed.
  - `swift test` passed with 236 tests.

## 2026-05-23 08:44 IST

- Resolved effective Codex instruction config for trusted project layers:
  - Codex instruction discovery now applies effective `project_doc_fallback_filenames` from user config plus trusted project `.codex/config.toml` layers from the detected root down to the selected directory, with closest project layer winning.
  - Untrusted project `.codex/config.toml` files still scan as settings and report trust-required findings, but they no longer silently alter effective fallback filenames or byte limits.
  - `project_doc_max_bytes` now uses the effective trusted layer value for oversized-instruction checks, and `project_doc_max_bytes = 0` is treated as disabled project-doc loading rather than a malformed value.
  - Configured `model_instructions_file` surfaces are shown for Codex CLI/Desktop, resolve relative paths from the config file's containing directory, report missing referenced files, and warn when the deprecated `experimental_instructions_file` key is present.
- Research/coordination:
  - Rechecked official OpenAI Codex docs for config precedence, trusted project config loading, AGENTS.md discovery order, fallback filenames, byte limits, `model_instructions_file`, and `experimental_instructions_file` deprecation.
  - Used two read-only subagents for official Codex docs verification and local code/test insertion review; both agents were closed after this batch completed.
- Validation:
  - `swift test --filter CompatibilityContextSettingsTests` passed with 63 tests.
  - `swift build` passed.
  - `swift test` passed with 244 tests.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace/debug scan passed, with only existing intentional fixture/helper-name matches.

## 2026-05-23 08:59 IST

- Added conservative Claude Code runtime evidence handling:
  - Compatibility now treats `~/.claude.json` as private local project state for the selected Claude Code project and surfaces its keys/settings as runtime evidence only, not as a write target.
  - Local project-state `additionalDirectories` records can contribute additional-directory skill roots while preserving file-controlled `permissions.additionalDirectories` precedence for duplicate context and skill roots.
  - Local project-state external-import approval flags refine the finding title to distinguish recorded approval, shown-but-unapproved warning evidence, and unknown state; the issue remains `.contextExternalImportApprovalUnknown` and external imports are still not recursively read before approval is verified.
  - Claude settings now detect `hooks.InstructionsLoaded` and report it as live-context observability that static scanning cannot prove has fired.
  - `CLAUDE_CONFIG_DIR` is now honored for Claude Code user settings/rules paths when `PROJECTHUB_CLAUDE_HOME` is not overriding test isolation.
- Research/coordination:
  - Used read-only subagents for official Claude docs verification, local code-shape review, and final compile/semantics review; all known sidecars were closed after the batch completed.
  - Verified the implementation remains read-only for private Claude project state and does not add a ConfigWriter path.
- Validation:
  - `swift test --filter CompatibilityContextSettingsTests/testClaudeLocalProjectStateAdditionalDirectoryIsRuntimeEvidence` passed.
  - `swift test --filter CompatibilityContextSettingsTests/testClaudeSettingsAdditionalDirectoryWinsOverRuntimeStateEvidence` passed.
  - `swift test --filter CompatibilityContextSettingsTests/testClaudeExternalImportLocalApprovalEvidenceIsReportedButNotReadRecursively` passed.
  - `swift test --filter CompatibilityContextSettingsTests/testClaudeExternalImportApprovalStateIsUnknownAndNotReadRecursively` passed.
  - `swift test --filter CompatibilityContextSettingsTests/testClaudeInstructionsLoadedHookIsReportedAsRuntimeVisibility` passed.
  - `swift build` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace/debug scan passed, with only the existing `fingerprint` helper-name match.
  - A broad `swift test --filter CompatibilityContextSettingsTests` run was stopped after it kept consuming CPU for minutes after source changed; re-run the broader suite before landing.

## 2026-05-23 09:10 IST

- Clarified Compatibility scan scope and result lenses:
  - The top-level Compatibility tab now has an explicit scan target control for `Global` tool state versus `Project` plus global tool state, while project-embedded Compatibility remains fixed to its project.
  - The previous single target picker is split into two smaller controls: scope lens (`All supported`, `Project`, `Global`) and runtime lens (`All`, `CLI`, `Desktop`).
  - The result strip now states what is being scanned and which scope/runtime lens is active, and copied Markdown reports include the scan target plus scope/runtime lens.
  - Skill availability rows now obey real scope filtering instead of showing every support row for both Project and Global lenses.
  - Added focused XCTest coverage for scope and runtime filter semantics.
- Research/coordination:
  - Used three read-only subagents for backend gap review, UX workflow review, and validation-risk review; all agents were closed after the batch completed.
  - The backend and validation reviews identified target-aware MCP restart/runtime evidence and scanner test-environment isolation as the next high-value backend slices.
- Validation:
  - `swift build` passed.
  - `swift test --filter CompatibilityFilterTests` passed with 2 tests.
  - `swift test --filter 'CompatibilityMCPAuthTests|MCPHealthCheckerTests|CompatibilityProjectMCPTests'` passed with 27 tests before the UI patch and remains the latest focused MCP/auth/project-health validation.
  - `bash build-app.sh` passed and rebuilt `ProjectHub.app`.
  - `plutil -lint ProjectHub.app/Contents/Info.plist` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace/debug scan passed.

## 2026-05-23 09:17 IST

- Added target-runtime restart evidence for MCP Verify:
  - `MCPHealthChecker.evaluate` and `verify` now accept an optional verification context with runtime states for loaded-at, not-running, or unknown owner runtime.
  - Restart checks compare config modification time against the target runtime launch/load date when evidence exists instead of only comparing against Project Hub process start time.
  - Desktop-owned Verify calls now pass runtime evidence for Claude Desktop and Codex Desktop from `NSWorkspace.runningApplications`; stopped desktop apps are treated as loading config on next launch, and unknown launch dates remain conservative.
  - Unknown runtime state still allows live MCP handshakes to run, then keeps the result in `needsRestart` so the user sees that the server is reachable but the owning app reload state remains unresolved.
  - `CompatibilityMCPAuthTests` now restores env vars it temporarily unsets for missing-credential assertions.
- Research/coordination:
  - Used a read-only subagent for MCP restart API/test-shape review; it confirmed the optional-context shape and flagged the unknown-runtime handshake trap, which is now covered by a regression test.
- Validation:
  - `swift test --filter 'MCPHealthCheckerTests|CompatibilityMCPAuthTests'` passed with 22 tests.
  - `swift build` passed.
  - `swift test --filter CompatibilityFilterTests` passed with 2 tests.
  - `bash build-app.sh` passed and rebuilt `ProjectHub.app`.
  - `plutil -lint ProjectHub.app/Contents/Info.plist` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace/debug scan passed.

## 2026-05-23 09:23 IST

- Added Claude Desktop MCP log diagnostics coverage and isolation:
  - `PROJECTHUB_CLAUDE_DESKTOP_LOGS_DIR` now lets tests and dogfood runs isolate Claude Desktop log evidence from the real `~/Library/Logs/Claude` directory.
  - Claude Desktop extension tests now isolate Codex home, Claude home/state, managed policy paths, Codex requirements, Desktop support, and Desktop logs so real local machine surfaces do not leak into fixture scans.
  - Added fixture coverage for recent Claude Desktop MCP log auth findings with URL/email/secret redaction, missing-runtime findings, timeout findings, success-line suppression of older errors, and stale log ignore behavior.
  - The isolated extension/log test suite dropped from roughly one minute to under five seconds locally after the broader scanner-path isolation.
- Research/coordination:
  - Used a read-only subagent for scanner/log test-shape review; it recommended the log-dir override and focused log fixtures, which are now implemented.
- Validation:
  - `swift test --filter CompatibilityClaudeDesktopExtensionTests` passed with 7 tests.
  - `swift build` passed.
  - `bash build-app.sh` passed and rebuilt `ProjectHub.app`.
  - `plutil -lint ProjectHub.app/Contents/Info.plist` passed.
  - `swift test --filter 'CompatibilityClaudeDesktopExtensionTests|MCPHealthCheckerTests|CompatibilityMCPAuthTests|CompatibilityFilterTests'` passed with 31 tests.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace/debug scan passed, with only the existing `fingerprint` helper-name match.

## 2026-05-23 09:28 IST

- Aligned the non-Compatibility project MCP reader with disabled-entry semantics:
  - `MCPReader` now uses `ConfigWriter.readAllServerEntries` for project MCP sources instead of the active-only dictionary reader.
  - `MCPServerInfo` now carries `isDisabled` so project inventory callers can distinguish configured-but-disabled servers.
  - Claude Code project inventory now also marks enabled-map entries disabled when their name appears in `disabledMcpjsonServers`, preserving approval-list disabled state outside the Compatibility scanner.
  - Added regression coverage for VS Code `servers_disabled`, Claude Code `mcpServers_disabled`, and Claude Code `disabledMcpjsonServers` in `MCPReader.servers(for:)`.
- Research/coordination:
  - Used one read-only subagent for the reader/model/test-shape review; it confirmed the entry-reader approach and was closed after the batch completed.
- Validation:
  - `swift test --filter ProjectMCPReaderTests` passed with 9 tests.
  - `swift build` passed.
  - `bash build-app.sh` passed and rebuilt `ProjectHub.app`.
  - `plutil -lint ProjectHub.app/Contents/Info.plist` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace/debug scan passed.

## 2026-05-23 09:35 IST

- Added project MCP enable/disable management:
  - Project MCP rows now include an enable/disable icon action, matching the global MCP management affordance while staying scoped to the selected project.
  - The action opens a confirmation dialog that names the server and exact project config file before writing.
  - Project scoped writes now flow through an `MCPStore.toggleServerDisabled` overload that calls `ConfigWriter.setServerEnabled` with `.project` scope and avoids refreshing unrelated global inventory.
  - Claude Code approval-list disabled state remains separate from `_disabled` config storage: enabling an approval-disabled active row removes the server from `disabledMcpjsonServers`, while ordinary disables still move the server to `mcpServers_disabled`.
  - Added focused writer tests for Claude Code/Cursor/VS Code/Roo project JSON toggles, Codex project TOML `enabled = false` toggles, and clearing Claude approval-list disabled state without moving active config.
- Research/coordination:
  - Used one read-only subagent for project MCP management semantics; it confirmed the scoped writer shape and the Claude approval-list caveat.
- Validation:
  - `swift test --filter ConfigWriterProjectScopeTests` passed with 3 tests.
  - `swift test --filter ProjectMCPReaderTests` passed with 9 tests.
  - `swift test --filter CompatibilityProjectMCPTests` passed with 9 tests.
  - `swift build` passed.
  - `bash build-app.sh` passed and rebuilt `ProjectHub.app`.
  - `plutil -lint ProjectHub.app/Contents/Info.plist` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace/debug scan passed.

## 2026-05-23 09:43 IST

- Dogfooded Supabase hosted MCP auth behavior:
  - Verified official Supabase docs describe the hosted MCP server as OAuth/dynamic-client-registration by default, with Authorization bearer headers reserved for manual/CI use.
  - Verified the official MCP authorization spec requires `WWW-Authenticate` on `401` responses to advertise protected-resource metadata.
  - Live-probed `https://mcp.supabase.com/mcp` without credentials and confirmed it returns `401` plus `WWW-Authenticate: Bearer ... resource_metadata="https://mcp.supabase.com/.well-known/oauth-protected-resource/mcp"`.
- Tightened hosted MCP auth classification:
  - `MCPHealthChecker` now treats embedded header env templates like `Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}` as missing auth when the env var is absent, while respecting `${VAR:-fallback}` defaults.
  - Live remote Verify now parses `WWW-Authenticate` bearer challenges and reports OAuth/browser-login-required copy with the protected-resource metadata URL when present.
  - Compatibility scans now classify clean `https://mcp.supabase.com/mcp` configs with no PAT/header as hosted MCP OAuth required instead of leaving them as generic health unknown.
  - Added parser coverage for the official Claude remote command shape for Supabase hosted MCP.
- Research/coordination:
  - Used one read-only subagent for Supabase/vendor MCP gap review; it identified the OAuth-first hosted config and `WWW-Authenticate` metadata path as the highest-value vendor dogfood gap.
- Validation:
  - `swift test --filter MCPHealthCheckerTests` passed with 23 tests.
  - `swift test --filter CompatibilityMCPAuthTests` passed with 4 tests.
  - `swift test --filter ImportParserCommandTests` passed with 12 tests.
  - Live unauthenticated Supabase MCP probe returned the expected OAuth protected-resource challenge.
  - `swift build` passed.
  - `bash build-app.sh` passed and rebuilt `ProjectHub.app`.
  - `plutil -lint ProjectHub.app/Contents/Info.plist` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace/debug scan passed, with only the existing `fingerprint` helper-name match.

## 2026-05-23 09:51 IST

- Tightened MCPB/DXT archive import classification:
  - Verified current Claude docs describe `.mcpb` as a zip archive with required `manifest.json`, local stdio behavior, and user install through double-click, drag/drop, or Claude Desktop Settings > Extensions.
  - `ImportParser.previewDesktopExtensionArchive` now validates extension identity and required manifest shape before returning a Claude Desktop handoff preview.
  - Broken `.mcpb`/`.dxt` manifests now fail as invalid desktop-extension manifests instead of producing a partial handoff preview.
  - Ordinary `.zip` source archives with unrelated or malformed `manifest.json` files now fall through to source-archive import discovery instead of being misclassified as desktop extensions.
  - The archive handoff button now says "Open archive" and the help copy explains that users should open it with Claude Desktop's installer, avoiding an overpromise about local file associations.
- Research/coordination:
  - Used one read-only subagent for MCPB/DXT parser and handoff review; it identified the false-positive `.zip` manifest path and missing desktop-extension preview tests as the highest-value gap.
- Validation:
  - `swift test --filter ImportParserArchiveTests` passed with 11 tests.
  - `swift test --filter CompatibilityClaudeDesktopExtensionTests` passed with 7 tests.
  - `swift test --filter ImportParserRegistryManifestTests` passed with 8 tests.
  - `swift build` passed.
  - `bash build-app.sh` passed and rebuilt `ProjectHub.app`.
  - `plutil -lint ProjectHub.app/Contents/Info.plist` passed.
  - `git diff --check` passed.

## 2026-05-23 10:04 IST

- Dogfooded Claude Code local project-state path mapping:
  - Inspected the real `~/.claude.json`, which currently has 84 project records, many Claude worktree paths, case-variant project paths, and local project records with `mcpServers`, `disabledMcpServers`, external-import flags, and `mcpContextUris`.
  - `CompatibilityScanner` now resolves local Claude project state through one canonical project-record fallback instead of requiring exact `projects[projectRoot]` matches for local MCP discovery.
  - Local Claude MCP health rereads now use the same fallback, so a symlink/case-normalized project state record can be discovered and verified consistently.
  - Claude's runtime `disabledMcpServers` list now marks private per-project `mcpServers` entries disabled without moving or hiding the underlying launch config.
  - Added symlinked-project fixtures proving local MCP discovery, disabled runtime state, health reread, runtime additional-directory summary, and skill-root evidence survive canonical path fallback.
- Research/coordination:
  - Used one read-only subagent for Claude local project-state review; it independently identified the exact mismatch between settings-state canonical fallback and local MCP exact-key lookup.
- Validation:
  - `swift test --filter testClaudeLocalMCPUsesCanonicalProjectStateFallbackAndDisabledRuntimeList` passed.
  - `swift test --filter testClaudeLocalProjectStateUsesCanonicalPathFallbackForRuntimeEvidence` passed.
  - `swift test --filter CompatibilityProjectMCPTests` passed with 10 tests.
  - `swift test --filter CompatibilityContextSettingsTests` was manually interrupted after 31 individual tests had passed and no failures had appeared because the full suite stayed long-running.
  - `swift build` passed.
  - `bash build-app.sh` passed and rebuilt `ProjectHub.app`.
  - `plutil -lint ProjectHub.app/Contents/Info.plist` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace/debug scan passed, with only the existing `fingerprint` helper-name match.

## 2026-05-23 20:25 IST

- Expanded Claude Code local project-state diagnostics:
  - Real `~/.claude.json` records showed project-scoped `enabledMcpjsonServers` / `disabledMcpjsonServers`, trust prompt state, deprecated `ignorePatterns`, crawl preferences, and session metrics in local project records.
  - `claudeCodeProjectMCPDisabledNames` now also reads `projects[...].disabledMcpjsonServers` from the selected project's private `~/.claude.json` record, using the same canonical/symlink-aware project-state lookup as other local evidence.
  - Project `.mcp.json` servers disabled from Claude local approval state now remain visible but report Disabled health and disabled health-entry state.
  - Local project-state summaries now include project MCP approval choices, deprecated ignore patterns, directory crawl disabled, and session metrics categories without exposing raw metric values.
  - `inspectClaudeSettings` now reports local `hasTrustDialogAccepted == false` as project trust required, `ignorePatterns` as deprecated in favor of `permissions.deny`, and `dontCrawlDirectory == true` as runtime-only crawl evidence.
- Research/coordination:
  - Used one read-only subagent for hidden/runtime Claude state review; it prioritized project `.mcp.json` approval state in `~/.claude.json` and recommended keeping all related handling read-only.
  - Verified current Claude docs still describe `permissions.deny` as the replacement for deprecated `ignorePatterns`.
- Validation:
  - `swift test --filter testClaudeLocalProjectStateHiddenRuntimeFieldsAreReported` passed.
  - `swift test --filter testClaudeProjectMCPDisabledByLocalProjectStateIsReportedDisabled` passed.
  - `swift test --filter testClaudeLocalProjectStateUsesCanonicalPathFallbackForRuntimeEvidence` passed.
  - `swift test --filter CompatibilityProjectMCPTests` passed with 11 tests.
  - `swift build` passed.
  - `bash build-app.sh` passed and rebuilt `ProjectHub.app`.
  - `plutil -lint ProjectHub.app/Contents/Info.plist` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace/debug scan passed, with only the existing `fingerprint` helper-name match.

## 2026-05-23 20:32 IST

- Completed Claude project MCP approval-state handling:
  - Verified current Claude Code docs list `enableAllProjectMcpServers`, `enabledMcpjsonServers`, and `disabledMcpjsonServers` as project `.mcp.json` approval controls.
  - Replaced the disabled-name-only helper with a merged project MCP approval-state helper that reads Claude settings files plus the matching private `~/.claude.json.projects[...]` record.
  - Project `.mcp.json` servers now remain Disabled when rejected from settings or private project state, Approved when listed or all-project MCP servers are approved, and Unknown with a specific approval-not-recorded finding when no approval evidence exists.
  - Added focused regression coverage for missing approval and recorded approval, plus full project MCP suite coverage.
- Research/coordination:
  - Used one read-only subagent for the Claude project MCP approval-state question; it confirmed that not-yet-recorded approval should be surfaced as user-reviewed runtime evidence and not as a direct write target.
- Validation:
  - `swift test --filter testClaudeProjectMCPApprovalMissingIsReportedUnknown` passed.
  - `swift test --filter testClaudeProjectMCPApprovalRecordedSuppressesApprovalUnknown` passed.
  - `swift test --filter CompatibilityProjectMCPTests` passed with 13 tests.
  - `swift build` passed.
  - `bash build-app.sh` passed and rebuilt `ProjectHub.app`.
  - `plutil -lint ProjectHub.app/Contents/Info.plist` passed.
  - `git diff --check` passed.
  - Edited-file trailing-whitespace/debug scan passed, with only the existing `fingerprint` helper-name match.

## 2026-05-23 20:45 IST

- Added effective Claude Code MCP policy evaluation:
  - Re-verified official Claude Code managed MCP docs for `managed-mcp.json`, `allowedMcpServers`, `deniedMcpServers`, matcher object shape, exact command matching, URL wildcard matching, denylist precedence, and `allowManagedMcpServersOnly` managed-source semantics.
  - `CompatibilityScanner` now builds an effective Claude Code MCP policy from user, project, local, managed, and managed drop-in settings surfaces.
  - Claude Code server inspection now marks matching `deniedMcpServers` rows Disabled with a server-specific denylist finding.
  - Claude Code server inspection now treats active `managed-mcp.json` as exclusive control and marks non-managed Claude MCP rows Disabled instead of leaving them as generic unknown health.
  - Effective allowlists now distinguish remote URL rules, exact stdio command rules, and name-only fallback rules; servers that do not match the applicable rule family are Disabled with an allowlist finding.
  - Managed `allowManagedMcpServersOnly` now ignores project/user/local allowlist expansions while still allowing denylist entries to merge from all readable settings surfaces.
  - Added managed-policy regression coverage for denylist blocking, exact command allowlist blocking, and managed-only allowlist filtering.
- Research/coordination:
  - Used two read-only subagents: one for official/current Claude MCP policy semantics, and one for the existing Project Hub implementation hook points.
  - Closed both subagents after the batch so the next task can start with fresh agents.
- Validation:
  - `swift test --filter ClaudeCodeManagedPolicyTests` passed with 5 tests.
  - `swift test --filter CompatibilityProjectMCPTests` passed with 13 tests.
  - `swift build` passed.
  - `bash build-app.sh` passed and rebuilt `ProjectHub.app`.
  - `plutil -lint ProjectHub.app/Contents/Info.plist` passed.
  - `git diff --check` passed.

## 2026-05-23 21:14 IST

- Added Claude Code macOS MDM managed-preferences coverage:
  - Re-verified current Claude Code docs for managed settings surfaces, including `com.anthropic.claudecode` macOS MDM preferences, file-based managed settings, server-managed settings, and `managed-settings.d` merge order.
  - Added Claude Code user and machine managed-preferences matrix surfaces for `com.anthropic.claudecode.plist`.
  - Routed Claude Code managed-preferences plist parsing through the same Claude settings diagnostics as JSON settings so `allowedMcpServers`, `deniedMcpServers`, and `allowManagedMcpServersOnly` are visible as Claude Code policy findings.
  - Updated effective MCP policy computation to read JSON, JSONC, plist, and private local-project-state settings dictionaries through a shared helper.
  - Gave active MDM managed-preferences policy precedence over file-based managed settings for the managed allowlist when computing `allowManagedMcpServersOnly`.
  - Kept denylist merging across all readable Claude settings surfaces.
  - Optimized effective MCP policy computation to run once per scan instead of once per server inspection after the first validation pass exposed a major slowdown.
  - Added a plist fixture proving `com.anthropic.claudecode` MDM policy is shown as a Claude Code settings surface and controls effective server health.
- Research/coordination:
  - Used two read-only subagents: one checked official/current Claude managed settings docs, and one inspected local implementation gaps.
  - Closed both subagents after the batch.
- Validation:
  - `swift test --filter testMacOSManagedPreferencesPolicyIsScannedAsClaudeCodePolicy` passed.
  - `swift test --filter ClaudeCodeManagedPolicyTests` passed with 6 tests after policy computation was optimized.
  - `swift test --filter CompatibilityProjectMCPTests` passed with 13 tests.
  - `swift build` passed.
  - `bash build-app.sh` passed and rebuilt `ProjectHub.app`.
  - `plutil -lint ProjectHub.app/Contents/Info.plist` passed.
  - `git diff --check` passed.
  - Edited-file whitespace/debug scans passed; the debug scan only matched the existing `fingerprint` helper name.

- 2026-05-25 09:20 · Codex bulk-finished compatibility UX/profile-copy edges:
  - Profile Copier now resolves source/target project roots before copying skills, agents, rules, and MCP configs.
  - Profile Copier preserves nested and quoted Codex MCP TOML sections during project copy and warns when copied skills depend on additional-directory or disabled/limited policy state.
  - Live Mode skill toggles now use canonical skill paths safely and no-op for non-Claude filesystem skill origins instead of constructing invalid `.claude/skills/<full path>` moves.
  - Import and compatibility UX now use preview-first and scope-specific copy, avoid global credential writes for project imports, and correct stale Claude/Codex skill path labels.
  - Cheap validation: `swift build` and `git diff --check` passed; longer tests were intentionally deferred for bulk completion speed.

- 2026-05-25 09:25 · Codex added direct remote archive import support:
  - From URL now downloads direct `.zip`, `.tar.gz`, `.tgz`, `.mcpb`, `.dxt`, GitHub `/archive/...`, and GitHub `/releases/download/...` archive assets into a unique temp file, then reuses the existing local archive preview path.
  - GitHub release listing pages remain guided instead of being treated as archive bytes.
  - Paste-mode archive URL guidance now points users to From URL for direct archive links.
  - Cheap validation: `swift build` and `git diff --check` passed.

- 2026-05-25 09:32 · Codex clarified app-owned MCP health/auth states:
  - Added dedicated Compatibility issue codes for target-tool-managed authentication and app/runtime-managed MCP surfaces.
  - headersHelper and OAuth metadata now surface as app-managed auth follow-ups instead of generic handshake unknowns.
  - Claude Desktop MCPB/DXT extension runtime/configuration now surfaces as app-managed runtime follow-up instead of generic health unknown.
  - Live Verify summaries now say auth/runtime is managed by the target app while still refusing to execute helpers, read secrets, or impersonate OAuth.
  - Cheap validation: `swift build` and `git diff --check` passed.

## 2026-05-23 23:05 IST

- Wired Codex plugin MCP server policy fixes into Compatibility:
  - Added scanner metadata for disabled Codex plugin MCP server policy findings so the issue subject path points at the exact Codex config file that set `enabled = false`.
  - Changed plugin-server policy state resolution from unioned disabled names to layer-aware state, so a trusted project `enabled = true` can override a global `enabled = false`, and a trusted project `enabled = false` becomes the precise fix target.
  - Added a dedicated Compatibility issue-sheet fix plan for disabled Codex plugin MCP servers that previews and applies `ConfigWriter.setCodexPluginMCPServerEnabled` against Codex config, while leaving plugin-owned MCP JSON, installed plugin files, credentials, and unrelated settings untouched.
  - Kept whole-plugin disabled findings manual because removing a server-level policy cannot re-enable a disabled plugin.
  - Added regression coverage for policy issue subject paths and trusted project/global precedence.
- Research/coordination:
  - Used two read-only subagents: one inspected the Compatibility UI fix-plan path and one audited scanner metadata/policy-layer edge cases.
  - Closed both subagents after the batch.
- Validation:
  - `swift test --filter CompatibilityPluginMCPTests` passed with 11 tests.
  - `swift test --filter ConfigWriterCodexPluginPolicyTests` passed with 3 tests.
  - `swift build` passed.
  - `bash build-app.sh` passed and rebuilt `ProjectHub.app`.
  - `plutil -lint ProjectHub.app/Contents/Info.plist` passed.
  - `git diff --check` passed.
  - Edited-file whitespace/debug scans passed; the debug scan only matched an existing test string and the existing `fingerprint` helper name.

## 2026-05-23 22:56 IST

- Added Codex plugin MCP policy validation and writer support:
  - Re-verified official OpenAI Codex plugin MCP policy syntax and key types: `plugins.<plugin>.mcp_servers.<server>`, optional per-tool `tools.<tool>`, boolean `enabled`, approval modes `auto` / `prompt` / `approve`, and string-array `enabled_tools` / `disabled_tools`.
  - Added Compatibility scanner warnings for malformed plugin MCP policy sections, non-boolean `enabled`, invalid approval modes, non-string tool arrays, unknown server-policy keys, unknown tool-policy keys, and invalid section shapes.
  - Kept policy-only reload semantics conservative because official docs prove restart for plugin enable/disable and marketplace changes, but do not explicitly prove restart for plugin MCP policy-only edits.
  - Added `ConfigWriter.previewSetCodexPluginMCPServerEnabled` and `setCodexPluginMCPServerEnabled` to safely upsert or update Codex config policy sections without writing into plugin-owned MCP files.
  - Writer support preserves existing policy keys and tool overrides, creates backups through the normal TOML write path, and supports quoted plugin IDs/server names.
- Research/coordination:
  - Used two read-only subagents: one verified official OpenAI Codex docs and one inspected local implementation/test gaps.
  - Closed both subagents after the batch.
- Validation:
  - `swift test --filter CompatibilityPluginMCPTests` passed with 10 tests.
  - `swift test --filter ConfigWriterCodexPluginPolicyTests` passed with 3 tests.
  - `swift build` passed.
  - `bash build-app.sh` passed and rebuilt `ProjectHub.app`.
  - `plutil -lint ProjectHub.app/Contents/Info.plist` passed.
  - `git diff --check` passed.
  - Edited-file whitespace/debug scans passed; the debug scan only matched an existing test string and the existing `fingerprint` helper name.

## 2026-05-23 21:31 IST

- Tightened Claude private project-state policy boundaries:
  - Re-verified current Claude Code docs: `~/.claude.json` is documented as private OAuth/MCP/local project state and cache data, while policy settings live in settings/managed settings surfaces.
  - Added read-only diagnostics for policy-shaped keys observed inside `~/.claude.json.projects[...]`, collecting key paths only and avoiding value leakage.
  - Local project-state summaries now call out “policy-shaped private state” when those fields exist.
  - Suppressed normal `allowedMcpServers`, `deniedMcpServers`, and `allowManagedMcpServersOnly` effective-policy wording for local project-state surfaces.
  - Updated effective Claude MCP policy computation to skip `claude-code-local-project-state` dictionaries entirely, so private project state cannot silently disable project `.mcp.json` servers as enterprise policy.
  - Added regression coverage proving a local private `deniedMcpServers` field is diagnostic only and does not mark the project MCP server disabled.
- Research/coordination:
  - Used two read-only subagents: one checked official Claude docs for `~/.claude.json` / private project-state boundaries, and one inspected the local implementation/test hook points.
  - Closed both subagents after the batch.
- Validation:
  - `swift test --filter testClaudeLocalProjectStatePolicyShapedFieldsAreReadOnlyEvidence` passed.
  - `swift test --filter testClaudePrivateProjectStateDenylistDoesNotActAsEffectiveMCPPolicy` passed.
  - `swift test --filter CompatibilityProjectMCPTests` passed with 14 tests.
  - `swift test --filter CompatibilityContextSettingsTests` passed with 70 tests.
  - `swift build` passed.
  - `bash build-app.sh` passed and rebuilt `ProjectHub.app`.
  - `plutil -lint ProjectHub.app/Contents/Info.plist` passed.
  - `git diff --check` passed.
  - Edited-file whitespace/debug scans passed; the debug scan only matched the existing `fingerprint` helper name.

## 2026-05-23 21:47 IST

- Added Claude Code server-managed settings coverage:
  - Re-verified the official Claude Code managed settings model with subagents: server-managed settings are delivered from Claude.ai Admin Settings, cached locally, visible in Claude Code `/status`, and use normal `settings.json` shape except OS-level-only settings are not honored there.
  - Added a read-only Compatibility matrix surface for Claude Code server-managed settings. Initial docs evidence was treated conservatively until the follow-up pass below confirmed the documented `remote-settings.json` cache path.
  - Added an explicit opt-in cache path hook for verified fixtures/local evidence, so Project Hub can parse a known server-managed settings JSON file when one is provided without claiming broad filesystem discovery.
  - Updated effective Claude MCP policy precedence so non-empty server-managed settings take priority over MDM managed preferences, file-based managed settings, and `managed-settings.d` sources for MCP allowlist/managed-only policy.
  - Preserved denylist/allowlist diagnostics and added `forceRemoteSettingsRefresh` summary wording for remote settings fail-closed policy evidence.
  - Added focused tests for the runtime-only server-managed surface and server-managed precedence over endpoint MDM/file managed settings.
- Research/coordination:
  - Used two read-only subagents: one checked official/current Claude Code server-managed settings docs and one audited Project Hub implementation/test gaps.
  - Closed both subagents after the batch so the next task can start with fresh agents.
- Validation:
  - `swift test --filter ClaudeCodeManagedPolicyTests` passed with 8 tests.
  - `swift test --filter CompatibilityProjectMCPTests` passed with 14 tests.
  - `swift build` passed.
  - `bash build-app.sh` passed and rebuilt `ProjectHub.app`.
  - `plutil -lint ProjectHub.app/Contents/Info.plist` passed.
  - `git diff --check` passed.
  - Edited-file whitespace/debug scans passed; the debug scan only matched the existing `fingerprint` helper name.

## 2026-05-23 21:59 IST

- Corrected Claude Code server-managed settings cache discovery and remote transport support:
  - Re-checked current official Claude Code `.claude` directory docs and found that `remote-settings.json` is now documented as the cached copy of server-managed settings under the active Claude home.
  - Updated Project Hub to scan `remote-settings.json` by default instead of requiring an explicit override, while keeping the surface read-only and administrator/runtime-owned.
  - Preserved the explicit `PROJECTHUB_CLAUDE_CODE_SERVER_MANAGED_SETTINGS_PATH` override for fixtures or local evidence when needed.
  - Added/updated regression coverage proving the documented cache path is surfaced read-only and still participates in server-managed-over-endpoint MCP policy precedence.
  - Accepted the official hyphenated `streamable-http` MCP transport spelling in Compatibility scans and Claude MCP allowlist remote classification, so valid registry/Claude/Codex remote configs are no longer marked unsupported.
  - Added Claude project `.mcp.json` and Codex project `.codex/config.toml` regression coverage for `streamable-http`.
- Research/coordination:
  - Used two read-only subagents. One found the `streamable-http` scanner inconsistency, and one identified the larger next gap: Codex plugin-bundled MCP servers and `plugins.<plugin>.mcp_servers.<server>` policy are not yet scanned.
  - Closed both subagents after the batch.
- Validation:
  - `swift test --filter ClaudeCodeManagedPolicyTests` passed with 8 tests.
  - `swift test --filter CompatibilityProjectMCPTests` passed with 16 tests.
  - `swift test --filter ImportParserRegistryManifestTests` passed with 8 tests.
  - `swift test --filter MCPHealthCheckerTests` passed with 23 tests.
  - `swift build` passed.
  - `bash build-app.sh` passed and rebuilt `ProjectHub.app`.
  - `plutil -lint ProjectHub.app/Contents/Info.plist` passed.
  - `git diff --check` passed.
  - Edited-file whitespace/debug scans passed; the debug scan only matched the existing `fingerprint` helper name.

## 2026-05-25 09:37 IST

- Added explicit Compatibility target presets:
  - The Compatibility scan controls now expose All Supported, Project, Global, CLI, Desktop, and Custom target choices.
  - Presets reuse the existing project/global scan target plus scope/runtime filters, so users can quickly choose supported scopes without losing advanced filtering.
  - Copied Markdown reports now include the selected target preset.
- Coordination:
  - Used and closed a focused read-only UX subagent before the patch.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.

## 2026-05-25 09:42 IST

- Added a visible four-tool coverage rollup to the Compatibility workflow:
  - The main Compatibility tab now shows per-tool counts for MCP, skills, settings/auth/context, safe writes, app/CLI/runtime-owned surfaces, read-only surfaces, restart surfaces, and findings.
  - Copied Markdown reports now include a `Tool Coverage Matrix` before the detailed findings.
  - The detailed Markdown matrix now includes file-controlled, safe-write, disable, OAuth/auth, env expansion, restart, precedence, and notes columns.
  - Detailed in-app matrix rows now show the owning tool explicitly and include read, disable, env, and precedence badges.
- Coordination:
  - Used two read-only subagents to audit the remaining matrix/report gap.
  - Closed both subagents after receiving their recommendations.
- Validation:
  - `swift build` passed.
  - `git diff --check` passed.

## 2026-05-25 09:48 IST

- Added a safe user-driven handoff for prompt-driven MCP installers:
  - Wizard-style commands such as `npx @vendor/wizard mcp add` are now detected before they can be parsed as ordinary bare launch commands.
  - The MCP import sheet shows a dedicated prompt-driven installer panel with the command, why Project Hub will not run it, a copy-command action, and a refresh-after-run action.
  - Project Hub still supports normal parseable `claude mcp add`, `claude mcp add-json`, npx/uvx/python/docker launch commands, and config snippets.
- Coordination:
  - Used two read-only subagents: one reviewed import/wizard flows, and one reviewed safe-fix/manual-action UX as the next candidate.
  - Closed both subagents after receiving their recommendations.
- Validation:
  - `swift test --filter ImportParserCommandTests` passed with 15 tests.
  - `swift build` passed.
  - `git diff --check` passed.

## 2026-05-25 09:53 IST

- Made safe fixes visible before manual work in Compatibility:
  - Added a Previewable Fixes overview before Manual Actions.
  - Finding rows now show whether the item has a previewed file fix or needs manual review.
  - Manual Actions now excludes issue-derived items that already have a previewable safe fix, while preserving post-apply follow-ups.
  - Copied Markdown reports now include a Previewable Fixes section before Manual Actions.
- Coordination:
  - Used one read-only subagent for UX/compile pitfall review and closed it after completion.
- Validation:
  - `swift build` passed.
  - `swift test --filter CompatibilityReportMarkdownTests` passed with 2 tests.
  - `git diff --check` passed.

## 2026-05-25 09:58 IST

- Extended prompt-driven MCP installer handoff through fetched content:
  - GitHub repository/README resolution now returns a side-channel handoff when config candidates miss and the README only contains a wizard command such as `npx @vendor/wizard mcp add`.
  - Direct fetched README/raw URLs now show the same copy-and-refresh handoff immediately when no safe import choices exist.
  - New URL fetches clear stale handoff/archive state before starting.
- Coordination:
  - Used one read-only subagent for import-flow sanity review.
  - Closed the subagent after receiving its recommendations.
- Validation:
  - `swift test --filter ImportParserGitHubURLTests` passed with 43 tests.
  - `git diff --check` passed.
  - Skipped a redundant standalone `swift build` because the focused test run compiled the `ProjectHub` target.

## 2026-05-25 10:02 IST

- Extended prompt-driven MCP installer handoff through source archives:
  - Local and downloaded source archives now keep scanning safe config/import choices first.
  - If an archive README only contains a wizard installer, the archive preview returns a prompt-driven handoff instead of `archiveNoImportableConfig`.
  - The MCP import sheet shows the same copy-and-refresh handoff for archive README wizard installers.
- Validation:
  - `swift test --filter ImportParserArchiveTests` passed with 14 tests.
  - `git diff --check` passed.

## 2026-05-25 10:04 IST

- Completed the direct fetched URL import-choice path:
  - Non-GitHub README/raw URLs now immediately enter the multiple-choice preview flow when more than one safe snippet is found.
  - A single safe fetched choice is previewed immediately instead of only filling the raw text box and requiring another Next click.
- Coordination:
  - Used one read-only subagent to find cheap remaining compatibility gaps.
  - Closed the subagent after receiving its recommendations.
- Validation:
  - `swift test --filter 'ImportParserCommandTests|ImportParserGitHubURLTests|ImportParserArchiveTests'` passed with 72 tests.
  - `git diff --check` passed.

## 2026-05-25 10:11 IST

- Hardened Compatibility fix application against stale previews:
  - Converted previewed Codex settings repairs to write the exact approved before/after preview instead of recomputing writer output during apply.
  - Covered invalid Codex top-level/profile/project settings, `project_doc_max_bytes` repairs, fallback filename cleanup, project-root marker cleanup, project trust, ignored project settings, project overlap cleanup, disabled/stale Codex skill overrides, deprecated/unknown approval and sandbox fixes, and Claude approval conflict cleanup.
  - Project overlap cleanup still rechecks that the overlap set is the same before applying the approved preview.
- Coordination:
  - Used one read-only subagent to audit remaining preview/apply consistency candidates.
  - Closed the subagent after receiving its recommendations.
- Validation:
  - `swift build` passed.
  - `swift test --filter 'CompatibilityContextSettingsTests|ConfigWriterSettingsRepairTests|CompatibilitySkillSupportTests'` passed with 147 tests.
  - `git diff --check` passed.

## 2026-05-25 10:17 IST

- Kept prompt-driven installers visible when safe import options coexist:
  - GitHub README resolution now carries a secondary prompt-driven installer handoff alongside safe README choices.
  - Direct fetched README/raw URLs and pasted READMEs now preserve that secondary handoff through choice selection and preview.
  - Local/downloaded source archive previews now keep the installer handoff when an archive README has both safe snippets and a wizard installer.
  - Safe import choices remain preferred; Project Hub still does not execute prompt-driven installers.
- Validation:
  - `swift test --filter 'ImportParserCommandTests|ImportParserGitHubURLTests|ImportParserArchiveTests'` passed with 74 tests.
  - `git diff --check` passed.

## 2026-05-25 10:24 IST

- Broadened prompt-driven MCP installer detection:
  - Added handoff coverage for `px mcp add`, `npm exec ... mcp add`, `pnpm dlx ... mcp add`, `bun ... mcp add`, `bunx ... mcp add`, `uvx ... mcp add`, and `pipx run ... mcp add`.
  - Unconfigured direct `mcp add` now goes to the user-driven installer handoff instead of becoming a vague parse failure.
  - Parseable direct/tool-owned MCP add commands still import as safe config choices.
- Coordination:
  - Used one read-only subagent for installer-shape coverage review.
  - Closed the subagent after receiving its recommendations.
- Validation:
  - `swift test --filter ImportParserCommandTests` passed with 17 tests.
  - `git diff --check` passed.

## 2026-05-25 12:38 IST

- Added MCP Registry MCPB package import support:
  - `server.json` packages with `registryType: "mcpb"` now create a Registry MCPB package choice instead of being dropped as unsupported.
  - The choice preserves the artifact URL and `fileSha256` metadata and routes through the existing Claude Desktop extension archive handoff.
  - The UI verifies SHA-256 before previewing a downloaded registry MCPB artifact.
  - Source archives that contain a Registry `server.json` with an MCPB package surface the same handoff choice.
- Research:
  - Re-checked official MCP Registry package-type docs for `registryType: "mcpb"` and `fileSha256`.
  - Re-checked official remote-server docs that `remotes` and `packages` may coexist in one `server.json`.
- Coordination:
  - Used one read-only subagent for remaining-gap selection.
  - Closed the subagent after receiving its recommendation.
- Validation:
  - `swift test --filter 'ImportParserRegistryManifestTests|ImportParserArchiveTests'` passed with 26 tests.
  - `git diff --check` passed.

## 2026-05-25 12:50 IST

- Exposed skill conflict state outside Compatibility:
  - Installed Skills rows now carry duplicate-name and version-conflict diagnostics from the Compatibility skill observations.
  - The Skills tab shows those diagnostics as compact badges beside the existing tool/scope/state badges.
- Fixed quoted Codex project-section parity:
  - Project root detection now recognizes `[projects."/path"]`, `["projects"."/path"]`, and single-quoted TOML section forms.
  - Compatibility trust/settings scans and summaries now treat quoted-root project tables as Codex project sections.
  - Codex project trust previews/writes update the existing quoted-root table instead of appending a duplicate `[projects."..."]` table.
- Coordination:
  - Used one read-only subagent to audit the next high-value non-import gap.
  - Closed the subagent after applying the recommendation.
- Validation:
  - `swift test --filter 'SkillInventoryReaderTests|ProjectRootDetectorTests|ConfigWriterSettingsRepairTests/testPreviewSetCodexProjectTrustUpdatesQuotedRootProjectTable|CompatibilityContextSettingsTests/testCodexQuotedRootProjectSectionTrustIsReported'` passed with 23 tests.
  - `git diff --check` passed.

## 2026-05-25 17:38 IST

- Added VS Code MCP prompt/env-file compatibility:
  - `${input:...}` placeholders are now treated as prompt-backed input/auth needs in static Compatibility scans and MCP health preflight.
  - `envFile` / `env_file` is preserved through `ServerEntry`, global/project JSON readers, Codex TOML readers, Codex plugin read-only MCP rows, Compatibility health entries, and import normalization.
  - Compatibility now warns when a server depends on an app-specific env file, distinguishing missing env files from conversion/setup follow-up.
  - Codex TOML writes preserve copied env-file dependency as `env_file`.
- Research:
  - Re-checked official VS Code MCP config docs for `inputs` and `envFile`.
  - Re-checked official Claude Code MCP docs for `.mcp.json` environment expansion semantics.
- Coordination:
  - Used one read-only subagent to audit `envFile` propagation and initializer churn.
  - Closed the subagent after applying the recommendation.
- Validation:
  - `swift test --filter 'MCPHealthCheckerTests/testEvaluateEnvFileNeedsAuthAndReportsMissingFile|CompatibilityMCPAuthTests/testEnvFileIsReportedAsAppSpecificMCPAuthSetup|ConfigWriterProjectScopeTests/testVSCodeProjectInventoryPreservesEnvFile|ImportParserJSONTests/testVSCodeEnvFileIsPreservedAndNormalized'` passed with 4 tests.
  - `git diff --check` passed.

## 2026-05-25 17:49 IST

- Added MCP working-directory compatibility:
  - `cwd`, `workingDirectory`, and `working_directory` are preserved through inventory/import/scan/health paths.
  - Missing working directories now report as broken setup rather than fake missing auth.
  - Workspace placeholders such as `${workspaceFolder}` no longer become missing environment-variable findings.
  - Static command checks and live stdio Verify resolve relative executable paths against the configured cwd.
- Coordination:
  - Used one read-only subagent to audit `cwd` propagation and command lookup gaps.
  - Closed the subagent after applying the recommendation.
- Validation:
  - `swift test --filter 'MCPHealthCheckerTests/testVerifyStdioUsesConfiguredCWDForRelativeCommand|MCPHealthCheckerTests/testEvaluateMissingCWDIsBroken|CompatibilityMCPAuthTests/testMissingMCPWorkingDirectoryIsReportedBroken|ConfigWriterProjectScopeTests/testVSCodeProjectInventoryPreservesEnvFile|ImportParserJSONTests/testVSCodeEnvFileIsPreservedAndNormalized|FullConfigReaderTests/testCodexGlobalInventoryIncludesConfiguredPluginMCPServersAsReadOnly'` passed with 6 tests.
  - `git diff --check` passed.

## 2026-05-25 18:00 IST

- Added VS Code MCP sandbox/dev compatibility:
  - `sandboxEnabled`, `sandbox`, and `dev` are preserved for VS Code inventory/import paths.
  - Compatibility reports sandbox/dev as app-specific runtime/security behavior instead of letting it silently blend into Claude/Codex MCP config.
  - Claude/Codex writes strip VS Code sandbox/dev fields so copied servers do not imply VS Code sandbox enforcement or debug/watch behavior carries across tools.
- Research:
  - Re-checked official VS Code MCP docs for `sandboxEnabled`, `sandbox`, sandbox semantics, and `dev` mode.
- Coordination:
  - Used one read-only subagent to audit next high-value MCP config metadata gaps.
  - Closed the subagent after applying the target-write recommendation.
- Validation:
  - `swift test --filter 'ConfigWriterProjectScopeTests/testVSCodeSandboxDevMetadataIsOnlyWrittenBackToVSCodeTargets|ConfigWriterProjectScopeTests/testVSCodeProjectInventoryPreservesEnvFile|ImportParserJSONTests/testVSCodeEnvFileIsPreservedAndNormalized|CompatibilityMCPAuthTests/testVSCodeSandboxAndDevModeAreReportedAsAppSpecificRuntime'` passed with 4 tests.
  - `git diff --check` passed.

## 2026-05-28 21:11 IST

- Added Roo Code MCP tool-control/runtime compatibility:
  - `alwaysAllow`, `disabledTools`, `watchPaths`, `timeout`, and inline `disabled` are preserved for Roo inventory/imports.
  - Compatibility reports Roo tool-control/runtime fields as app-specific behavior instead of silently blending them into Claude/Codex config.
  - Roo writes keep native inline `disabled`; Codex copies map disabled state to `enabled = false`; Claude copies strip unsupported Roo-only fields.
  - Roo `timeout` stays visible as metadata and feeds Roo live Verify probe timeout.
- Research:
  - Re-checked official Roo Code MCP docs for global/project config precedence and per-server fields.
- Coordination:
  - Used one read-only subagent to audit Roo MCP field handling and disabled/timeout risks.
  - Closed the subagent after applying the recommendation.
- Validation:
  - `swift test --filter 'ConfigWriterProjectScopeTests/testRooToolControlMetadataIsOnlyWrittenBackToRooTargets|ImportParserJSONTests/testVSCodeEnvFileIsPreservedAndNormalized|CompatibilityMCPAuthTests/testRooToolControlMetadataIsReportedAsAppSpecificRuntime'` passed with 3 tests.
  - `git diff --check` passed.

## 2026-05-28 21:19 IST

- Added editor-style MCP env-template compatibility:
  - `${env:VAR}` now participates in missing-env detection and expansion alongside `${VAR}`.
  - MCP health checks detect missing command/argument env templates before command lookup or launch.
  - Compatibility scans report `${env:VAR}` in commands, args, env maps, URLs, and headers as missing auth/env state when unset.
  - Empty environment values now count as missing in Compatibility, matching MCP Health behavior.
- Research:
  - Re-checked official VS Code MCP docs for input/env-file config and VS Code variable syntax for `${env:Name}`.
- Coordination:
  - Used one read-only subagent to audit env-template gaps.
  - Closed the subagent after applying and validating the slice.
- Validation:
  - `swift test --filter 'MCPHealthCheckerTests/testEvaluateStdioLaunchArgEditorEnvTemplateNeedsAuth|MCPHealthCheckerTests/testEvaluateStdioCommandEditorEnvTemplateNeedsAuthBeforeCommandLookup|CompatibilityMCPAuthTests/testEditorEnvTemplatesAreReportedMissing'` passed with 3 tests.
  - `git diff --check` passed.

## 2026-05-28 21:28 IST

- Added Codex literal env/header template compatibility:
  - Compatibility now warns when Codex `env` or `http_headers` literal values contain `${VAR}` / `${env:VAR}` templates, even if Project Hub's process environment has those variables set.
  - Guidance points users to `env_vars`, `env_http_headers`, `bearer_token_env_var`, explicit values, or wrapper scripts depending on the target server shape.
- Tightened env-file path handling:
  - MCP Health reports missing `envFile` path variables before file lookup.
  - Compatibility suppresses generic missing/conversion env-file warnings when the env-file path itself depends on an unresolved variable.
- Research:
  - Re-checked official OpenAI Codex configuration reference for `mcp_servers.<id>.env`, `env_http_headers`, and `env_vars` semantics.
- Coordination:
  - Used one read-only subagent to audit env-file behavior and safety.
  - Kept env-file content parsing out of scope because reading/parsing secret values is app-specific and higher risk.
- Validation:
  - `swift test --filter 'MCPHealthCheckerTests/testEvaluateEnvFilePathEditorEnvTemplateNeedsAuthBeforeFileLookup|CompatibilityMCPAuthTests/testEnvFilePathEnvTemplateIsReportedWithoutGenericEnvFileNoise|CompatibilityMCPAuthTests/testCodexLiteralEnvTemplatesAreReportedEvenWhenEnvironmentIsSet'` passed with 3 tests.
  - `git diff --check` passed.

## 2026-05-28 21:42 IST

- Added direct Codex MCP tool-control compatibility:
  - `enabled_tools`, `disabled_tools`, `default_tools_approval_mode`, and per-tool `tools.<tool>.approval_mode` now preserve through Codex TOML inventory and project writes.
  - FullConfigReader preserves arbitrary nested Codex MCP TOML subtables, including `[mcp_servers.<server>.tools.<tool>]`.
  - Compatibility health entries carry Codex-native enabled/disabled/default/per-tool approval metadata.
  - Codex-native `disabled_tools` no longer triggers the Roo-specific app-runtime warning.
- Research:
  - Used a read-only subagent to verify current official Codex MCP tool-control keys and audit parser/writer gaps.
- Coordination:
  - Closed subagent Newton after implementing and validating the slice.
- Validation:
  - `swift test --filter 'FullConfigReaderTests/testCodexTOMLMCPReaderPreservesDirectToolControls|ConfigWriterProjectScopeTests/testCodexProjectWritePreservesDirectToolControls|CompatibilityMCPAuthTests/testCodexDirectToolControlsAreNotReportedAsRooSpecific'` passed with 3 tests.
  - `git diff --check` passed.

## 2026-05-28 21:48 IST

- Added Docker MCP env-flag auth detection:
  - `docker run --env NAME`, `--env=NAME`, `-e NAME`, and compact `-eNAME` launch args now require the host environment variable in MCP Health and Compatibility scans.
  - Docker env-flag values that reference `${VAR}` still use the existing env-template path.
- Validation:
  - `swift test --filter 'MCPHealthCheckerTests/testEvaluateDockerEnvFlagNeedsHostEnv|CompatibilityMCPAuthTests/testDockerEnvFlagsAreReportedMissing'` passed with 2 tests.

## 2026-05-28 21:51 IST

- Added connector-aware Claude Desktop remote MCP import/write handling:
  - Remote/hosted MCP imports now mark Claude Desktop ineligible and show a Settings > Connectors handoff instead of offering `claude_desktop_config.json`.
  - `ConfigWriter` defensively rejects remote Claude Desktop writes and previews, including batch previews, while preserving stdio writes.
- Coordination:
  - Used read-only subagent Gibbs to identify this high-impact remaining gap from current source and official Anthropic guidance.
- Validation:
  - `swift test --filter 'MCPImportScopePlannerTests|ConfigWriterProjectScopeTests/testClaudeDesktopRemoteMCPIsRejectedBeforeWrite|ConfigWriterProjectScopeTests/testClaudeDesktopStdioMCPIsNotConnectorBlocked'` passed with 4 tests.

## 2026-05-28 21:57 IST

- Tightened copy-to-apps UX for blocked MCP writes:
  - Global and project copy target rows now call `ConfigWriter.nativeWriteBlocker` with the source server config before selection.
  - Blocked targets are disabled and show the same reason the backend would throw, including the Claude Desktop Settings > Connectors boundary for hosted/remote MCPs.
  - Copy execution filters out blocked targets as a final guard.
  - Import diff previews now pass each server config into the same blocker check, so remote/write blockers remain visible in previews.
- Coordination:
  - Closed read-only subagent Archimedes before continuing; it was still running and no longer needed for the current slice.
- Validation:
  - Initial sandboxed `swift test --filter ConfigWriterProjectScopeTests/testClaudeDesktopRemoteMCPIsRejectedBeforeWrite` failed because SwiftPM could not write the user module cache.
  - Escalated rerun of the same focused test passed with 1 test and compiled the touched SwiftUI files.
  - `git diff --check` passed.

## 2026-05-28 22:09 IST

- Added broader hosted OAuth MCP detection:
  - MCP Health and Compatibility static auth scans now recognize GitHub Copilot remote MCP (`api.githubcopilot.com`), Notion MCP (`mcp.notion.com`), and Atlassian Rovo MCP (`mcp.atlassian.com`) as hosted OAuth/login-backed endpoints when no bearer/header/OAuth metadata is present.
  - Supabase hosted OAuth detection remains unchanged.
- Added Docker MCP filesystem preflight:
  - `docker run --env-file PATH` and `--env-file=PATH` now report missing env files before a server is treated as runnable.
  - `docker run -v HOST:CONTAINER`, `--volume HOST:CONTAINER`, and bind-style `--mount type=bind,source=HOST,target=...` now report missing host paths as broken setup.
  - Relative Docker paths resolve from configured MCP `cwd` when present, otherwise from the owning config workspace.
- Research:
  - Re-checked official GitHub, Notion, and Atlassian docs for remote MCP OAuth behavior and endpoint hosts before adding the provider map.
- Coordination:
  - Used read-only subagent Mill to identify Docker `--env-file` and bind mount preflight as the next high-impact gap, then closed it after receiving the audit.
- Validation:
  - Initial Docker focused test run failed because the combined env-file plus mount case expected broken health while health priority remains needs-auth when both auth/setup and path issues are present.
  - `swift test --filter 'MCPHealthCheckerTests/testEvaluateDockerEnvFileNeedsExistingFile|MCPHealthCheckerTests/testEvaluateDockerBindMountNeedsExistingHostPath|CompatibilityMCPAuthTests/testDockerEnvFileAndMountPathsAreReportedMissing|MCPHealthCheckerTests/testEvaluateKnownHostedOAuthProvidersNeedLogin|CompatibilityMCPAuthTests/testKnownHostedOAuthProvidersAreReportedNeedsAuthWithoutPATHeader'` passed with 5 tests.
  - `git diff --check` passed.

## 2026-05-28 22:13 IST

- Preserved Docker env-file metadata during MCP command imports:
  - Safe Docker command imports now copy `docker run --env-file PATH` and `--env-file=PATH` into parsed `envFile` metadata.
  - The original Docker args remain intact, so target tools still launch the same command while Project Hub can surface env-file dependencies in previews, writes, health, and Compatibility.
  - Command-string normalization also carries detected Docker env-file metadata when a JSON/server manifest stores the full Docker command as one string.
- Coordination:
  - Spawned read-only subagent Poincare for an import-path sanity audit, then closed it once the local parser slice was validated.
- Validation:
  - Initial sandboxed parser test hit the recurring SwiftPM module-cache permission issue.
  - Escalated `swift test --filter 'ImportParserCommandTests/testDockerEnvFileAddsLaunchEnvFileHint|ImportParserCommandTests/testDockerEnvFileInlineFlagAddsLaunchEnvFileHint|ImportParserCommandTests/testDockerEnvFlagAddsLaunchEnvHint'` passed with 3 tests.
  - `git diff --check` passed.

## 2026-05-28 22:23 IST

- Extended Docker and prompt-backed MCP compatibility in bulk:
  - JSON/server-manifest imports with `command` arrays or `command: "docker"` plus `args` now preserve Docker `--env-file` metadata and `--env` credential hints during normalization, matching README command-import behavior.
  - Docker structured `--mount` parsing in MCP Health and Compatibility no longer traps on duplicate fields; repeated fields now resolve deterministically with the last value used for path diagnostics.
  - MCP Health now treats `${input:...}` placeholders in `envFile` and `cwd` as prompt-backed input requirements before missing-file or missing-directory checks.
- Coordination:
  - Spawned read-only subagent Popper for a fresh gap audit, used its health/input finding, and closed it immediately after the batch completed.
- Validation:
  - Initial sandboxed SwiftPM runs hit the recurring module-cache permission issue and were rerun with escalation.
  - `swift test --filter 'ImportParserJSONTests/testDockerCommandArrayEnvFileIsPreservedAndNormalized|ImportParserJSONTests/testDockerCommandWithArgsEnvFileIsPreservedAndNormalized|MCPHealthCheckerTests/testEvaluateDockerMountDuplicateFieldsDoesNotCrash|CompatibilityMCPAuthTests/testDockerMountDuplicateFieldsAreReportedWithoutCrashing'` passed with 4 tests.
  - `swift test --filter 'MCPHealthCheckerTests/testEvaluateEnvFileInputVariableNeedsAuthBeforeFileLookup|MCPHealthCheckerTests/testEvaluateCWDInputVariableNeedsAuthBeforeLaunch|MCPHealthCheckerTests/testEvaluateEnvFilePathEditorEnvTemplateNeedsAuthBeforeFileLookup|MCPHealthCheckerTests/testEvaluateInputVariablePromptNeedsAuthBeforeLaunch'` passed with 4 tests.
  - `git diff --check` passed.

## 2026-05-28 22:33 IST

- Added normal MCP inventory command-array parity and Docker path-placeholder preflight:
  - Global/project MCP inventory readers now normalize JSON `command` arrays and safe command strings into `ServerEntry.command` plus `args`, matching Compatibility launch parsing.
  - Claude local project-state detail rows now display command arrays correctly.
  - Docker `--env-file` and bind/volume mount paths now detect missing `${env:...}` variables before missing-file/path checks in both MCP Health and Compatibility.
  - Docker mount paths containing `${input:...}` now surface prompt-backed input requirements without also producing misleading missing-path findings.
- Coordination:
  - Spawned read-only subagent Euler for a nearby gap audit, used its Docker path-placeholder finding, and closed it immediately after the command-array batch completed.
- Validation:
  - Initial sandboxed SwiftPM run hit the recurring module-cache permission issue.
  - First escalated focused run found MCP Health ordering still preferred a generic launch env-var issue over Docker path-variable auth; reordered Docker path preflight ahead of generic arg env checks.
  - `swift test --filter 'ProjectMCPReaderTests/testProjectServerEntriesNormalizeCommandArrays|ProjectMCPReaderTests/testProjectMCPReaderShowsCommandArrayDetailsFromClaudeLocalState|FullConfigReaderTests/testCodexPluginInventoryNormalizesCommandArrays|MCPHealthCheckerTests/testEvaluateDockerEnvFilePathVariableNeedsAuthBeforeFileLookup|MCPHealthCheckerTests/testEvaluateDockerMountInputVariableNeedsAuthBeforePathLookup|CompatibilityMCPAuthTests/testDockerPathVariablesAreReportedBeforePathLookup'` passed with 6 tests.
  - `git diff --check` passed.

## 2026-05-28 22:39 IST

- Improved package-runner import naming and hosted OAuth health classification:
  - `npm exec`, `npm x`, `pnpm dlx`, and `uv run --with` command imports now keep the wrapper command/args exactly as pasted while inferring cleaner server names from the package.
  - Prompt-driven package-runner `mcp add` commands remain blocked behind the user-driven wizard handoff.
  - MCP Health filters empty/placeholder OAuth metadata before treating a remote server as app-owned OAuth, so hosted endpoints with example values such as `your-client-id` still report needs-auth.
- Coordination:
  - Spawned read-only subagent Euclid for a nearby gap audit, used its OAuth placeholder finding, and closed it after validation.
- Validation:
  - Initial sandboxed SwiftPM run hit the recurring module-cache permission issue.
  - `swift test --filter 'ImportParserCommandTests/testNpmExecCommandKeepsWrapperAndInfersPackageName|ImportParserCommandTests/testNpmXCommandKeepsWrapperAndInfersPackageName|ImportParserCommandTests/testPnpmDlxCommandKeepsWrapperAndInfersPackageName|ImportParserCommandTests/testUVRunWithCommandKeepsWrapperAndInfersPackageName|ImportParserCommandTests/testPackageRunnerMCPAddInstallersUseWizardHandoff|MCPHealthCheckerTests/testEvaluateKnownHostedOAuthProvidersNeedLogin|MCPHealthCheckerTests/testEvaluateRemotePlaceholderOAuthMetadataDoesNotSuppressHostedOAuth'` passed with 7 tests.
  - `git diff --check` passed.

## 2026-05-28 23:22 IST

- Tightened OAuth metadata and `${userHome}` path semantics:
  - Inventory readers, writer metadata extraction, MCP Health, and Compatibility now treat callback/scopes-only OAuth keys as hints, not proof of configured app-managed OAuth.
  - Real OAuth metadata still preserves callback/scopes hints in surfaced metadata.
  - MCP Health and Compatibility now expand `${userHome}` in cwd, envFile, Docker env-file, and Docker bind paths before missing file/directory checks.
- Coordination:
  - Used read-only subagents Nietzsche and Hooke for OAuth hint semantics and `${userHome}` parity audits.
- Validation:
  - `swift test --filter 'CompatibilityMCPAuthTests/testClaudeCodePlaceholderOAuthWithCallbackPortDoesNotSuppressHostedOAuthMissingAuth|CompatibilityMCPAuthTests/testPlaceholderOAuthMetadataDoesNotSuppressHostedOAuthMissingAuth|CompatibilityMCPAuthTests/testRealOAuthMetadataSuppressesHostedOAuthMissingAuth|CompatibilityMCPAuthTests/testUserHomeEnvFilePlaceholderReportsMissingFile|CompatibilityMCPAuthTests/testUserHomeCWDPlaceholderReportsMissingDirectory|MCPHealthCheckerTests/testVerifyRemoteOAuthConfigIsUnknownAndDoesNotProbe|MCPHealthCheckerTests/testEvaluateUserHomeEnvFilePlaceholderChecksResolvedFile|MCPHealthCheckerTests/testEvaluateUserHomeCWDPlaceholderChecksResolvedDirectory|FullConfigReaderTests/testGlobalInventoryIgnoresPlaceholderOnlyOAuthMetadata|ConfigWriterProjectScopeTests/testProjectInventoryIgnoresPlaceholderOnlyOAuthMetadata'` passed with 10 tests.
  - `git diff --check` passed.

## 2026-05-28 23:36 IST

- Hardened generic MCP fixes and env-wrapper launch normalization:
  - Compatibility MCP enable/remove fixes now apply the exact approved before/after file preview and refuse to overwrite files changed after preview.
  - The shared preview apply path now uses neutral text backup/write behavior for JSON and TOML previews.
  - Import parsing, MCP Health, and Compatibility scans now unwrap `/usr/bin/env` command wrappers to the actual launcher while preserving wrapper environment hints.
  - Env-wrapped Docker configs now still surface Docker `--env-file` and bind-mount diagnostics instead of stopping at the wrapper command.
- Coordination:
  - Used read-only subagents Lovelace and Averroes for stale-preview and env-wrapper gap audits.
- Validation:
  - First focused env-wrapper validation caught a test fixture using bare `docker` on a machine without Docker; the test now wraps the fixture Docker executable.
  - `swift test --filter 'ImportParserCommandTests/testBareCommandParsesAbsoluteEnvWrapperAssignment|ImportParserJSONTests/testEnvWrappedDockerCommandArrayIsUnwrappedAndPreservesMetadata|ImportParserJSONTests/testEnvWrappedCommandWithArgsIsUnwrapped|MCPHealthCheckerTests/testEvaluateEnvWrappedDockerEnvFileNeedsExistingFile|CompatibilityMCPAuthTests/testEnvWrappedDockerEnvFileAndMountPathsAreReportedMissing|ConfigWriterSettingsRepairTests/testApplyTextPreviewWritesExactJSONMCPEnablePreview|ConfigWriterSettingsRepairTests/testApplyTextPreviewRefusesJSONMCPRemovalWhenFileChangedAfterPreview|ConfigWriterSettingsRepairTests/testApplyTextPreviewWritesExactCodexMCPEnablePreview|ConfigWriterSettingsRepairTests/testApplyTextPreviewRefusesCodexMCPRemovalWhenFileChangedAfterPreview'` passed with 9 tests.
  - `git diff --check` passed.

## 2026-05-30 18:25 IST

- Tightened project discovery/root detection parity:
  - Codex config-backed project discovery now uses the same structural TOML section parser as `ProjectRootDetector`, so `[projects."/repo"]`, `["projects"."/repo.with.dot"]`, and single-quoted variants do not split dotted paths or disappear from the project picker.
  - Claude `.claude/skills` and Codex `.agents/skills` folders are now built-in root markers in both ProjectStore and Compatibility project-root inference.
- Coordination:
  - Used read-only subagents Bernoulli, Goodall, and Archimedes for import/project/skills gap scouting.
  - Implemented Goodall's Codex project-table discovery gap and recorded Bernoulli/Archimedes findings as next work: Registry remote credential inputs and Codex plugin-bundled skills.
- Validation:
  - Initial sandboxed SwiftPM run hit the recurring module-cache permission issue.
  - `swift test --filter 'ProjectRootDetectorTests/testParsesCodexProjectRootsFromBothProjectTableSpellings|ProjectRootDetectorTests/testDetectsClaudeSkillsOnlyFolderAsProjectRoot|ProjectRootDetectorTests/testDetectsCodexSkillsOnlyFolderAsProjectRoot|ProjectRootDetectorTests/testDetectsCodexConfiguredProjectFromQuotedRootProjectTable'` passed with 4 tests.
  - `git diff --check` passed.

## 2026-05-30 18:33 IST

- Added Codex plugin-bundled skill visibility:
  - Installed Codex plugins with `.codex-plugin/plugin.json` `skills` roots now produce read-only `.skills` matrix surfaces for both Codex CLI and Codex Desktop.
  - Compatibility skill scans now namespace plugin-provided skill names, keep disabled plugin skills visible, and emit a `Codex plugin skill disabled` finding when plugin config disables the source plugin.
  - Codex plugin manifest inspection now reports invalid, out-of-root, or missing `skills` paths instead of silently dropping those skills.
  - The normal Skills inventory now picks these plugin-owned skill surfaces up through the shared Compatibility-backed inventory path and marks them read-only/plugin-owned.
- Coordination:
  - Used read-only subagents Hegel and James. Hegel confirmed the Codex plugin skill surface design; James scoped the next Registry remote credential-input batch.
- Validation:
  - Initial sandboxed SwiftPM run hit the recurring module-cache permission issue.
  - `swift test --filter 'CompatibilitySkillSupportTests/testCodexPluginSkillsAreDiscoveredFromInstalledPluginInventory|CompatibilitySkillSupportTests/testDisabledCodexPluginSkillsAreReported|SkillInventoryReaderTests/testInventoryIncludesReadOnlyCodexPluginSkills'` passed with 3 tests.
  - `git diff --check` passed.

## 2026-05-30 18:39 IST

- Preserved MCP Registry credential requirements through import:
  - `ParsedServer` now carries import-only `ImportCredentialRequirement` metadata for env, header, and URL-variable inputs without adding unknown keys to target config payloads.
  - Registry remote and package import parsing preserves required/secret/description metadata for headers, URL variables, and package environment variables while keeping the existing `url`, `headers`, and `env` output shapes.
  - Added `ImportCredentialPlanner` to merge parser metadata with fallback discovery from `env`, header placeholders, and URL placeholders.
  - The import next-step credential prompt now uses planner env hints, so Registry header and URL-variable placeholders can appear in the same paste-key flow as ordinary env vars.
- Coordination:
  - Used James's read-only scout output from the prior batch as the design guide; no subagents remained open after the batch.
- Validation:
  - Initial sandboxed SwiftPM run hit the recurring module-cache permission issue.
  - `swift test --filter 'ImportParserRegistryManifestTests/testRegistryRemoteManifestParsesHeadersAndURLVariables|ImportCredentialPlannerTests/testPlannerMergesMetadataEnvHeadersAndURLPlaceholders'` passed with 2 tests.
  - `git diff --check` passed.
[18:57] fixed: Added typed import credential save session note and validation outcome to project status files.
[18:59] fixed: Recorded MCP import credential preview visibility update in agents status.
[19:06] fixed: Recorded Claude Desktop expired-auth MCP log compatibility support in agents status.
[19:07] fixed: Recorded Codex auth JSON placeholder credential detection and focused regression result in project status files.
[19:12] fixed: Recorded OAuth expires_in duration auth-scan semantics and focused validation result in project status files.
[13:06] fixed: Recorded MCP Registry object-map credential input parser support and focused validation result in project status files.
[13:13] fixed: Recorded MCP Registry scalar URL-variable parser support, focused validation, and closed Noether after the read-only scout completed.
[13:21] fixed: Recorded nested MCP Registry input-variable support, literal env prompt filtering, templated header credential saves, and focused validation.
[13:29] fixed: Recorded VS Code input-backed import credential metadata, vendor MCP settings filename discovery, MCP Health unsupported-transport parity, focused validation, and subagent lifecycle.
[13:44] decided: Parked non-primary vendor/editor compatibility and resumed Claude/Codex-only completion path.
[13:44] fixed: Recorded Claude Code WebSocket MCP support, Codex Desktop admin skill root visibility, focused validation, and closed Claude/Codex scouts.
[13:54] fixed: Recorded Claude Desktop UV MCPB/no-mcp_config support, Codex admin skill UX copy, focused validation, and closed Claude/Codex scouts.
[13:58] fixed: Recorded Claude Desktop account-managed Skills as an explicit Compatibility matrix surface.
[13:59] fixed: Recorded Claude Code live-watched filesystem skill reload semantics in Compatibility support and matrix rows.
[14:02] fixed: Recorded Claude additionalDirectories skill-root correction and Codex apps_mcp_product_sku project ignored-setting detection.
[14:04] fixed: Recorded focused validation result and closed Claude/Codex scout subagents.
[14:12] fixed: Recorded Codex CLI profile-file discovery, selected/default profile surfaces, top-level profile-file plugin MCP policy, and focused validation.
[14:25] fixed: Recorded Codex CLI profile-file instruction, skill, plugin inventory, top-level writer behavior, and focused validation.
[14:30] fixed: Recorded Global MCP Codex default profile-file inventory readback and focused validation.
[14:33] fixed: Recorded Claude Code ~/.claude.json global config surface, focused validation, and transient test compile fix.
[14:40] fixed: Recorded Global MCP Claude Desktop extension inventory readback and focused validation.
[14:48] fixed: Recorded Compatibility-backed MCP inventory adapter overlay, focused validation, and transient compile/id fixes.
[14:54] fixed: Recorded source-aware Global MCP health for read-only Compatibility rows, writable-row path preservation, conservative Claude Desktop extension verify, and focused validation.
[15:00] fixed: Recorded Compatibility next-step UX routing for scan, preview fix, manual action, live Verify, and rescan.
[15:00] fixed: Recorded Compatibility next-step UX build validation.
[15:02] fixed: Recorded live Verify stale-handshake replacement and Codex Desktop manual app handoff.
[15:02] fixed: Recorded Compatibility next-step/live Verify UX build validation.
[15:06] fixed: Recorded MCP import Claude/Codex quick target presets for All, CLI, Desktop, and Project write preview flows.
[15:06] fixed: Recorded MCP import quick target preset build validation.
[15:09] fixed: Recorded MCP import approved-preview apply path with stale-file guard.
[15:10] fixed: Recorded MCP import approved-preview apply build validation.
[15:14] fixed: Recorded Copy MCP preview/stale-guard apply path and per-destination failure messages.
[15:15] fixed: Recorded Copy MCP approved-preview apply build validation.
[15:17] fixed: Recorded Copy MCP source fallback from scanned non-read-only ServerEntry for disabled global rows.
[15:19] fixed: Recorded ConfigWriter raw JSON disabled-map read fallback and focused coverage.
[15:19] fixed: Recorded focused ConfigWriter disabled-map read validation.
[15:28] fixed: Recorded Claude/Codex-only active UX scope across MCP discovery, project detection, project tabs, profile copy, Settings, and Hooks.
[15:28] fixed: Recorded Claude Code global MCP write handoff, Claude path override alignment, Codex SQLite non-git marker discovery, and focused validation.
[15:40] fixed: Recorded Claude Code CLI-first auth status, runtime-managed credential-store handling, legacy ~/.claude.json redacted evidence, Claude Desktop runtime auth, focused validation, and subagent lifecycle.
[15:46] fixed: Recorded Claude Code environment auth-source precedence detection, redaction/isolation tests, focused validation, and subagent lifecycle.
[15:52] fixed: Recorded Codex auth env redaction, credentialless auth.json needs-auth classification, MCP OAuth store/main-login separation, focused validation, and subagent lifecycle.
[15:59] fixed: Recorded centralized CODEX_HOME normalization across scanner, reader, writer, project discovery, skill scan, Compatibility fix plans, focused coverage, validation, and subagent lifecycle.
[16:01] fixed: Recorded Project MCP tab shared-scope cleanup so visible project MCP sections follow ToolSpecs.projectScopedTools and validation passed.
[16:02] fixed: Recorded Global MCP empty-state wording cleanup for Claude/Codex-only active scope and validation passed.
[16:03] fixed: Recorded Hooks reader Claude/Codex-only scope cleanup, validation, and stale Cursor hook removal.
[16:11] fixed: Recorded Codex Hooks CODEX_HOME/global-inline/trusted-project layer support, Hooks footer wording update, focused validation, and pending path-drift scout.
[19:09] decided: Recorded hard scope reset to Claude Code, Claude Desktop, Codex CLI, and Codex Desktop only; legacy tool code is ignored unless it leaks into those four active surfaces.
[19:09] fixed: Recorded MCP import CLI preset wording alignment with Claude Code global MCP handoff policy and focused validation.
[19:17] fixed: Recorded Profile Copy cleanup: active copy UI/API now carries Claude/Codex skills, Claude agents, Claude `.mcp.json`, and Codex `.codex/config.toml` only; stale Cursor Rules copy state and result handling were removed.
[19:17] fixed: Recorded focused profile-copy validation: ProjectMCPReader profile-copy slice, ProfileCopierSkillTests, swift build, and git diff --check passed.
[19:19] fixed: Recorded active-view fallback cleanup in Project MCP, Copy MCP, and Projects helper switches plus build/whitespace validation.
[23:44] fixed: Compatibility scan now runs off the SwiftUI main path with a busy state and deterministic XCTest auth probing when no fake Claude command is supplied.
[23:48] fixed: Added Claude Code additional-directory skill roots to compatibility skill-support surfaces and aligned the support detail copy.
[23:55] fixed: Corrected additional-directory skill-root dedupe to use file-path canonicalization so symlinked local project state surfaces retain distinct runtime skill roots.
[16:18] tried_failed: Full swift test was stopped after repeatedly spending minutes in scanner project-root canonicalization during plugin/managed-policy tests; optimizing the hotspot before rerun.
[16:19] fixed: Replaced project-root canonicalization with file-path canonicalization in compatibility skill override/read paths to remove scanner test and UI scan hotspot.
[16:24] fixed: Replaced project-root canonicalization with file-path canonicalization for Codex project-section matching in ConfigWriter trust helpers.
[16:26] fixed: Updated user-scope Codex MCP header writer test to expect established bearer_token_env_var normalization for Bearer ${ENV} Authorization headers.
[16:35] found_bug: Full swift test exposed stubbed adjacent project MCP detection returning no visibility findings — Sources/ProjectHub/Core/CompatibilityScanner.swift — P1
[16:42] fixed: Restored adjacent editor project MCP visibility findings for Cursor, VS Code, and Roo project MCP files.
[16:43] fixed: Focused adjacent project MCP visibility tests passed after detector restoration.
[16:45] fixed: CompatibilityProjectMCPTests passed all 21 tests after adjacent MCP detector restoration.
[16:50] found_bug: Full swift test still fails 14 assertions across health checker copy, Project MCP reader/root detection for VS Code/Roo project configs, and skill inventory additional-directory expectations.
[16:58] fixed: Restored read-only Cursor/VS Code/Roo project MCP discovery and aligned stale headersHelper/additional-directory skill expectations.
[17:02] fixed: Focused full-failure cluster passed after reader/root/expectation fixes.
[17:11] fixed: Full Project Hub test suite passed after recovered compatibility and reader fixes.
[17:12] fixed: Final recovered-branch build and whitespace checks passed.
