# WORKLOG.md

[12:43] decided: bootstrapped missing project-protocol canon from README.md, ROADMAP.md, and source inspection because required session files were absent
[12:57] fixed: implemented first compatibility health surface and patched Codex skill path assumptions
[12:55] fixed: added read-only compatibility matrix UI for Claude Code, Claude Desktop, Codex CLI, and Codex Desktop using the existing scanner/health models; swift build passes
[13:09] fixed: compatibility findings now offer safe preview/apply actions for writable MCP enable/remove fixes, backed by ConfigWriter previews and backups; swift build passes
[13:15] fixed: added Compatibility tab live MCP Verify action with per-server results and remote initialize/tools-list probing; swift build and diff-check pass
[13:24] fixed: disabled installed Codex skills now offer a previewed enable repair that updates only the matching `[[skills.config]]` TOML entry; swift build and diff-check pass
[13:29] fixed: top-level Compatibility scans now expose project selection plus All/Project/Global/CLI/Desktop target filtering; swift build and diff-check pass
[13:36] fixed: MCP import parser now normalizes serverUrl/endpoint remotes, command arrays, single-string launch commands, npm/uvx package metadata, and Docker image metadata; swift build and parser probes pass
[13:40] fixed: Compatibility now shows target-filtered skills with app availability, scope, path, disabled/parse status, and version-conflict detection; swift build and diff-check pass
[13:45] fixed: compatibility scanning and live MCP health checks normalize command arrays and single-string launch commands before command lookup/probing; swift build, diff-check, and focused health probe pass
[13:48] fixed: Compatibility now has a target-filtered Manual Actions section for auth, restart, runtime-managed, credential-store, managed-policy, and live verification follow-ups; swift build, diff-check, build-app, and app launch smoke pass
[14:03] fixed: Codex Desktop App now has explicit read-only Compatibility settings surfaces for macOS preferences and Application Support runtime state, and the combined scanner/context-file changes validate; swift build, diff-check, build-app, and launch smoke pass
[17:28] fixed: Codex instruction scanning now follows official global override, project directory walk, fallback filename, max-byte, empty-file, and shadowed-file rules; clean swift build, diff-check, build-app, and launch smoke pass
[17:33] fixed: missing Claude/Codex project instruction findings now offer guarded create-file previews that refuse overwrites; swift build passes
[17:37] fixed: MCP import From URL now fetches GitHub repo READMEs and blob raw files, then parses existing README snippets without executing installers; swift build passes
[17:41] fixed: live MCP Verify now classifies JSON-RPC/stderr auth failures as Needs auth and redacts credential-looking diagnostics; swift build passes
[17:44] fixed: Compatibility toolbar can copy a Markdown report artifact for the active target filter, including counts, health summary, live Verify results, matrix rows, findings, and MCP inventory; swift build passes
[17:54] fixed: MCP import can safely inspect downloaded source `.zip`/`.tar.gz`/`.tgz` archives for README/config snippets without executing installers; added SwiftPM archive parser tests, swift test passes
[18:02] fixed: shared project-root detection now handles Codex/Claude configured roots, Git worktree `.git` files, selected files, broad-root guardrails, and parent-trust/nested-repo precedence; swift test passes with 7 tests
[18:07] fixed: MCP health checker now has repeatable stdio and remote HTTP fixture coverage for working, needs-auth, redaction, placeholder credential, and missing-command states; swift test passes with 13 tests
[18:16] fixed: Compatibility now shows explicit skill availability for Claude Code, Claude Desktop, Codex CLI, and Codex Desktop, including Codex Desktop shared roots and Claude Desktop app/account-managed status; swift test passes with 14 tests
[15:36] fixed: Codex plugin MCP policy now keeps selected user profiles above trusted project policy in Compatibility, and Global MCP plugin rows explain their read-only source more clearly
[15:40] tried_failed: non-escalated focused Swift tests hit sandboxed Xcode module-cache access, then passed with SwiftPM escalation — validation path
[15:44] fixed: Codex plugin MCP enable fixes now remove active-profile disabled policy before clearing remaining top-level disabled policy so previews actually enable the effective server
[15:47] fixed: Codex plugin MCP policy writer now ignores profile sections in project `.codex/config.toml`, matching scanner/runtime semantics
[15:48] tried_failed: focused Swift test compile caught `tilde` helper unavailable in CompatibilityView; switched fix copy to existing `shortPath`
[15:52] fixed: validated Codex plugin MCP policy writer regressions with 26 focused tests plus build, app packaging, plist, diff, and debug scans
[16:06] fixed: Codex plugin MCP policy writer now treats `CODEX_HOME/config.toml` as global even when CODEX_HOME itself is `.codex`, while keeping project `.codex/config.toml` profile policy ignored
[16:09] fixed: Codex plugin MCP policy writer no longer falls back to active-profile edits for project `.codex/config.toml` when the top-level server section has no enabled policy
[16:11] fixed: removed an unnecessary Swift test `try` warning from the Codex plugin policy regression
[16:12] fixed: validated Codex plugin MCP path-gating regressions with 13 focused tests plus build, app packaging, plist, diff, and debug scans
[16:26] fixed: non-default Codex profile plugin MCP disable policy now appears as conditional runtime-profile evidence instead of silently staying settings-only
[16:27] tried_failed: focused Swift test compile caught the new profile-scoped policy issue code missing from state mapping; mapped it to Unknown
[16:31] fixed: conditional Codex profile MCP policy copy now names `codex --profile`, with regression coverage for a non-default selected profile
[16:33] tried_failed: non-default profile regression initially wrote top-level `profile` under a TOML table; rewrote the fixture with `profile` before plugin sections
[16:41] fixed: validated conditional Codex profile MCP policy evidence with 29 focused plugin/profile tests plus build, app packaging, plist, diff, and debug scans
[16:17] fixed: added internal Codex runtime profile selection plumbing for plugin MCP policy scans; validation pending.
[16:18] fixed: added regression coverage for `codex --profile work` applying CLI plugin MCP policy while desktop/default scans remain conditional.
[16:19] tried_failed: focused Swift test compile caught settings inspection still missing runtime profile propagation; patched the TOML settings inspector call.
[16:24] fixed: validated runtime Codex profile plugin MCP behavior with 3 focused tests and 30 broader compatibility/config tests.
[16:25] fixed: validated runtime profile slice with `swift build`, app packaging, plist lint, diff whitespace check, and debug-output scan; status docs updated.
[16:29] fixed: exposed Codex CLI runtime-profile selection in the Compatibility scan UI and copied report metadata; validation pending.
[16:30] fixed: added profile-name discovery coverage for default and nested Codex profile sections that feed the Compatibility profile picker.
[16:31] fixed: removed unnecessary Swift test `try` warning from the Codex profile-name discovery regression.
[16:35] fixed: persisted the Codex runtime profile on each Compatibility report and cached profile names in view state to avoid copied-report drift.
[16:40] fixed: validated Codex runtime-profile Compatibility UI slice with 4 focused tests, 31 broader plugin/config tests, build, app packaging, plist lint, diff whitespace check, debug scan, and worktree app process launch; Computer Use visual inspection timed out.
[16:41] fixed: stopped the worktree ProjectHub.app validation process after launch verification, leaving the installed app untouched.
[17:50] fixed: added Codex plugin MCP policy metadata to Global MCP rows and previewed Global MCP enable/disable policy actions for plugin-bundled Codex servers; validation pending.
[17:51] fixed: focused Global MCP Codex plugin policy tests passed with 10 tests, including policy metadata and preview/apply store coverage.
[17:55] fixed: broader plugin/config regression suite passed with 32 tests after Global MCP plugin policy management changes.
[17:57] fixed: validated Global MCP Codex plugin policy management with swift build, app packaging, plist lint, diff whitespace check, and debug-output scan; status docs updated.
[18:09] fixed: Compatibility now reports source-aware Codex plugin MCP policy conflicts across global, trusted project, and active-profile layers and offers previewed cleanup for shadowed lower-precedence enabled policy; 35 regression tests, swift build, app packaging, plist lint, diff check, and debug scan passed.
[18:23] fixed: Codex plugin MCP policy writes now refuse stale previews and apply the exact approved preview text for Global MCP and Compatibility fixes; profile-scoped disabled findings carry explicit profile metadata; 38 regression tests, swift build, app packaging, plist lint, diff check, and debug scan passed.
[18:36] fixed: Codex plugin MCP policy writer now parses single-quoted TOML dotted section segments and edits global/profile plugin-server policy in place; scan/fix/rescan plus 42 related regression tests, build, app packaging, plist lint, diff, and debug scans passed
[18:50] fixed: direct Codex MCP TOML handling now parses quoted dotted server IDs, writes dotted IDs as quoted keys, toggles/removes quoted sections in place including nested subtables, and scans quoted project MCP names correctly; 8 focused tests, 85 broader MCP/config tests, build, app packaging, plist lint, diff, and debug scans passed
[19:01] fixed: direct Codex MCP enable/disable toggles now line-edit only the parent enabled assignment so nested env/header subtables and comments stay in place; 4 focused tests, 87 broader MCP/config tests, build, app packaging, plist lint, diff, and debug scans passed
[19:25] fixed: previewed Codex TOML settings repairs now refuse stale applies and write only the approved preview text; 3 focused tests, 154 broader settings/plugin tests, build, app packaging, plist lint, diff, and debug scans passed
[19:35] fixed: invalid Codex filesystem permission-rule findings now get previewed conservative repairs for top-level, section, nested workspace-root section, and one-level inline table forms; focused scanner/writer tests pass
[19:50] fixed: validated invalid filesystem rule repair slice with 155 broader settings/plugin tests, swift build, app packaging, plist lint, diff check, and debug scan
[20:10] fixed: nested one-line inline Codex filesystem `:workspace_roots` repairs now remove a bad child only when a valid nested sibling remains; 3 focused tests, 156 broader settings/plugin tests, build, packaging, plist, diff, and debug scans passed
[20:31] fixed: Codex requirements policy findings remain read-only but now get targeted manual guidance, appear in Manual Actions, and copied reports include subject paths; focused test, 156 broader tests, build, packaging, plist, diff, and debug scans passed
[20:52] fixed: invalid Codex network proxy and permission-network domain/Unix-socket rule findings now get previewed cleanup that preserves valid sibling rules; 5 focused tests, 54 writer tests, build, packaging, plist, diff, and debug scans passed; broader settings/plugin rerun was stopped after hanging in an existing scanner-heavy context test
[21:00] fixed: broad compatibility test hang by isolating Claude JSON fixtures and replacing recursive Claude project-state canonicalization with cheap file-path canonicalization; 2 focused tests, 174 broader compatibility/config/root tests, build, packaging, plist, diff, and debug scans passed
[21:07] fixed: Compatibility issue rows and detail sheets now show where a finding applies, including surface, scope, runtime/profile, owner path, write ownership, and restart/rescan expectation; swift build passes
[21:15] fixed: Codex project-instruction disablement now carries the effective `project_doc_max_bytes = 0` config source and offers a stale-preview-guarded repair for writable global/project layers; 2 focused tests, 125 context/settings tests, build, packaging, plist, diff, and debug scans passed
[21:22] fixed: deprecated Codex `experimental_instructions_file` settings now get a stale-preview-guarded repair that renames to `model_instructions_file` or removes the deprecated duplicate; 4 focused tests, 129 context/settings tests, build, packaging, plist, diff, and debug scans passed
[21:33] fixed: missing Codex configured instruction-file findings now carry owning key/config metadata, show targeted Manual Actions guidance, and can preview-remove stale top-level `model_instructions_file` / `experimental_instructions_file` overrides; 5 focused tests, 133 broader context/settings tests, build, packaging, plist, diff, and debug scans passed
[21:41] fixed: MCP health now preflights missing `${VAR}` references in stdio launch args and remote URL templates, and GitHub repo import discovery now finds nested MCP config files beyond `server.json`; 8 focused tests, 91 broader health/import tests, build, packaging, plist, diff, and debug scans passed
[21:48] fixed: GitHub import candidates now include `.roo/mcp.json`, nested discovery accepts Roo project MCP configs, and JSON imports parse snake_case `mcp_servers` wrappers; 66 focused import tests, swift build, app packaging, plist lint, diff check, and debug scans passed
[21:57] fixed: copied Compatibility report findings now include surface, scope, runtime/profile, owner, write method, and restart/rescan columns; 4 focused report/filter tests, swift build, app packaging, plist lint, diff check, and debug scans passed; broader plugin regression run was manually stopped after slow scanner-heavy cases had passed through the runtime-profile plugin policy case
[22:03] fixed: Codex `.codex/config.toml` import discovery now works for GitHub repo/tree candidates, nested GitHub discovery, and source archives; parser accepts quoted-root `["mcp_servers"."name"]` sections and archive scans continue beyond the first 16 invalid config candidates; 70 focused import tests, swift build, app packaging, plist lint, diff check, and debug scans passed
[23:53] fixed: raw GitHub import URLs now preserve the pasted raw URL while adding existing blob fallback candidates for slash-ref branches, with parser regressions for raw config, Codex config, README, and paste guidance — Sources/ProjectHub/Core/ImportParser.swift, Tests/ProjectHubTests/ImportParserGitHubURLTests.swift
[23:54] tried_failed: focused Swift import tests first failed inside the workspace sandbox because SwiftPM could not write the user clang module cache; reran with approved escalation and the focused 76-test import suite passed — swift test --filter ImportParserGitHubURLTests|ImportParserArchiveTests|ImportParserTomlTests|ImportParserCommandTests|ImportParserRegistryManifestTests
[23:54] tried_failed: sandboxed swift build hit the same user clang module-cache permission issue; approved rerun passed — swift build
[23:55] tried_failed: sandboxed app bundle build hit SwiftPM user cache permissions; approved rerun passed and rebuilt ProjectHub.app — bash build-app.sh
[23:55] fixed: status docs updated for raw GitHub import handling and latest focused validation results — cowork/STATUS.md, agents/STATUS.md
[23:59] fixed: paste-mode config document URLs now show From URL guidance instead of becoming fake remote MCP endpoints, while hosted /mcp endpoints still import as remote servers — Sources/ProjectHub/Core/ImportParser.swift, Tests/ProjectHubTests/ImportParserGitHubURLTests.swift
[00:00] tried_failed: sandboxed focused import tests hit SwiftPM user module-cache permissions again; approved rerun passed with 78 import tests — swift test --filter ImportParserGitHubURLTests|ImportParserArchiveTests|ImportParserTomlTests|ImportParserCommandTests|ImportParserRegistryManifestTests
[00:01] tried_failed: sandboxed swift build hit SwiftPM user module-cache permissions again; approved rerun passed — swift build
[00:01] tried_failed: sandboxed app bundle build hit SwiftPM user cache permissions again; approved rerun passed and rebuilt ProjectHub.app — bash build-app.sh
[00:01] fixed: status docs updated for paste-mode remote config document guidance and latest focused validation — cowork/STATUS.md, agents/STATUS.md
[00:07] fixed: Project MCP reader now shares Claude project MCP approval-state reading across .mcp.json, Claude settings, managed paths, and private Claude project state; Project MCP UI blocks enable writes when approval disable is owned outside .mcp.json; added reader/context regressions — Sources/ProjectHub/Core/MCPReader.swift, Sources/ProjectHub/Views/MCPView.swift, Tests/ProjectHubTests/ProjectMCPReaderTests.swift
[00:09] tried_failed: focused ProjectMCPReaderTests compile caught missing returns in new Swift closures plus ambiguous String.init over dictionary keys; patched explicit returns and Array(keys) conversion — MCPReader.swift, MCPView.swift
[00:09] fixed: removed unnecessary try warning from the context-estimator Project MCP reader regression — Tests/ProjectHubTests/ProjectMCPReaderTests.swift
[00:10] fixed: Project MCP reader and Compatibility/project writer regression gate passed with 35 tests after the Claude approval-state bridge — ProjectMCPReaderTests|CompatibilityProjectMCPTests|ConfigWriterProjectScopeTests
[00:11] fixed: validation gates passed for Claude project MCP approval-state bridge — swift build, app bundle, plist lint, diff whitespace, and debug scan
[00:11] fixed: status docs updated for Claude project MCP approval-state bridge and latest validation — cowork/STATUS.md, agents/STATUS.md
[00:17] fixed: Compatibility project MCP approval checks now reuse MCPReader's Claude project approval-state reader instead of a private duplicate — Sources/ProjectHub/Core/CompatibilityScanner.swift
[00:17] fixed: MCPReader managed Claude approval settings now honor PROJECTHUB_CLAUDE_CODE_MANAGED_DIR and boolean NSNumber values, keeping tests and scanner behavior aligned — Sources/ProjectHub/Core/MCPReader.swift
[00:18] tried_failed: broad focused Swift test filter compiled but was manually stopped after the scanner-heavy suite ran long; exact changed tests were rerun cleanly — ProjectMCPReaderTests|CompatibilityProjectMCPTests|ClaudeCodeManagedPolicyTests
[00:20] fixed: exact shared Claude approval-reader regressions passed with 5 tests, including managed disabledMcpjsonServers through Project reader and Compatibility scanner paths
[00:21] fixed: validation gates passed for shared Claude project MCP approval reader — swift build, app bundle, plist lint, diff whitespace, and debug scan
[00:21] fixed: status docs updated for shared Compatibility/Project MCP approval-state reader and latest validation — cowork/STATUS.md, agents/STATUS.md
[00:25] fixed: Project-tab Codex project MCP entries now normalize http_headers/env_http_headers/bearer-token env vars from ConfigWriter.readAllServerEntries, including quoted dotted server IDs and nested header subtables — Sources/ProjectHub/Core/ConfigWriter.swift
[00:26] tried_failed: focused ConfigWriter project-scope tests caught integer TOML timeout values being dropped; added shared Codex numeric timeout coercion for project ServerEntry reads — Sources/ProjectHub/Core/ConfigWriter.swift
[00:27] fixed: Codex project MCP header/env-header parity regressions passed with 4 focused tests, including quoted dotted names, nested subtables, trailing comments, and Compatibility health-entry parity
[00:29] fixed: validation gates passed for Codex project MCP header parity — swift build, app bundle, plist lint, diff whitespace, and debug scan
[00:29] fixed: status docs updated for Codex project MCP header/env-header parity and latest validation — cowork/STATUS.md, agents/STATUS.md
[00:39] fixed: started quoted-root/global Codex MCP reader parity plus Project-tab remote env_vars filtering; subagents confirmed both gaps independently — Sources/ProjectHub/Core/FullConfigReader.swift, Sources/ProjectHub/Core/ConfigWriter.swift
[00:40] tried_failed: sandboxed focused Swift tests hit user clang module-cache permissions, and the first approved focused run caught a missing `try` in the new throwing test closure; patched the test call site — Tests/ProjectHubTests/FullConfigReaderTests.swift
[00:41] tried_failed: focused Project-tab Codex env_vars test exposed that `ConfigWriter` split inline TOML tables inside arrays at internal commas; replaced the array parser with top-level comma splitting that preserves inline table objects — Sources/ProjectHub/Core/ConfigWriter.swift
[00:41] fixed: quoted-root global Codex MCP and Project-tab remote env_vars regressions passed with 2 focused tests; broader FullConfigReader/ConfigWriterProjectScope gate passed with 15 tests
[00:42] fixed: validation gates passed for Codex MCP quoted-root/env_vars parity — swift build, app bundle, plist lint, diff whitespace, and debug scan; status docs updated
[00:45] fixed: Codex skill OpenAI metadata now carries `icon_small`, `icon_large`, `brand_color`, and `default_prompt` through SkillReader and Compatibility skill observations — Sources/ProjectHub/Core/SkillReader.swift, Sources/ProjectHub/Core/CompatibilityScanner.swift
[00:47] tried_failed: sandboxed focused skill tests hit SwiftPM user module-cache permissions; approved rerun passed 2 focused skill metadata tests — swift test --filter SkillReaderTests/testParsesOpenAIMetadata|CompatibilitySkillSupportTests/testScanReportsOpenAIMetadataAndMissingMCPDependency
[00:49] tried_failed: first quoted Codex skill override regression used user CODEX_HOME and exposed real machine skill noise; moved the fixture to project .codex/config.toml for isolated override behavior
[00:51] fixed: quoted `[["skills"."config"]]` Codex skill override tables now scan as `skills.config` and support previewed enable fixes; focused regression passed
[00:54] fixed: broader skill compatibility suite passed with 16 tests; validation gates passed with swift build, app bundle, plist lint, diff whitespace, and debug scan
[00:58] fixed: GitHub `github.com/<owner>/<repo>/raw/<ref>/<path>` import URLs now use GitHub content-fetch candidates instead of falling through as generic URLs — Sources/ProjectHub/Core/ImportParser.swift, Tests/ProjectHubTests/ImportParserGitHubURLTests.swift
[00:59] tried_failed: sandboxed focused raw-route import test hit SwiftPM user module-cache permissions; approved rerun passed the focused regression
[00:59] fixed: broader import parser suite passed with 79 tests after raw-route support
[01:00] fixed: validation gates passed for raw-route import support — swift build, app bundle, plist lint, diff whitespace, and debug scan; status docs updated
[01:03] fixed: Claude Code `headersHelper` is now preserved on ServerEntry, carried through Compatibility health entries, and reported as dynamic auth evidence without false OAuth/missing-auth findings — Models.swift, FullConfigReader.swift, ConfigWriter.swift, CompatibilityScanner.swift
[01:04] fixed: MCP live Verify now returns conservative Unknown for remote `headersHelper` configs and does not execute helper shell commands; focused headersHelper regressions passed
[01:04] fixed: broader MCP reader/writer/auth/health regression gate passed with 48 tests after headersHelper support
[01:05] fixed: validation gates passed for Claude headersHelper support — swift build, app bundle, plist lint, diff whitespace, and debug scan; status docs updated
[01:09] fixed: Codex plugin-bundled MCP inventory rows now preserve `headersHelper` when wrapping read-only plugin servers; focused FullConfigReader regression passed
[01:11] fixed: broader plugin/auth/health gate passed with 62 tests after plugin `headersHelper` preservation
[01:12] fixed: Claude Code MCP server name `workspace` now reports as a reserved-name broken finding, while Codex `workspace` servers remain valid; focused project MCP regressions passed
[01:15] fixed: broader project MCP/skill/report compatibility gate passed with 36 tests after reserved-name handling
[01:16] fixed: validation gates passed for reserved-name and plugin `headersHelper` preservation — swift build, app bundle, plist lint, diff whitespace, and debug scan; status docs updated
[01:19] fixed: Project Hub now refuses preview/import/copy writes that would create a Claude Code MCP server named `workspace`, and the import diff preview shows the reserved-name reason — ConfigWriter.swift, DiffPreviewBlock.swift
[01:21] fixed: broader project writer/import-adjacent gate passed with 42 tests after Claude Code reserved-name write protection
[01:22] fixed: Claude Code nested `oauth` MCP metadata now suppresses hosted-OAuth false positives and appears as app-owned OAuth evidence; official `add-json` OAuth import regression passed
[01:24] fixed: broader auth/import/project-writer gate passed with 49 tests after OAuth metadata and reserved-name write changes
[01:24] fixed: validation gates passed for OAuth metadata and reserved-name write protection — swift build, app bundle, plist lint, diff whitespace, and debug scan; status docs updated
[01:30] fixed: carried Claude Code nested `oauth` MCP metadata into ServerEntry and MCP live Verify so official OAuth-configured remote servers return conservative Unknown instead of unauthenticated Project Hub probe states — Models.swift, FullConfigReader.swift, ConfigWriter.swift, CompatibilityScanner.swift, MCPHealthChecker.swift
[01:32] fixed: broader auth/import/read-write/health gate passed with 86 tests after OAuth live Verify support; swift build, app bundle, plist lint, diff whitespace, and debug/fingerprint scans also passed
[01:38] fixed: Claude Code `.mcp.json` command env templates now expand fallback values before command lookup, missing command env vars report needs-auth/setup instead of broken command, and live stdio Verify honors documented `MCP_TIMEOUT` — MCPHealthChecker.swift, CompatibilityScanner.swift
[01:40] fixed: broader MCP health/auth/project/import/write gate passed with 82 tests after Claude command-env and timeout support; swift build, app bundle, plist lint, diff whitespace, and debug/fingerprint scans also passed
[01:46] fixed: closed completed subagent Locke after it found Codex-to-Claude remote MCP auth copy mismatch; spawned/closed Boyle for a read-only Claude local/private project MCP visibility audit per subagent cleanup rule
[01:50] fixed: cross-tool MCP writes now normalize Codex remote auth keys into Claude/JSON `headers` on JSON targets while preserving Codex-native auth keys on TOML targets — ConfigWriter.swift, ConfigWriterProjectScopeTests.swift
[01:50] fixed: broader MCP config/auth/import/read-write gate passed with 89 tests after cross-tool auth normalization; swift build, app bundle, plist lint, diff whitespace, and debug/fingerprint scans also passed
[01:56] fixed: spawned and closed subagent Ptolemy for Project MCP UI read-only action safety; implemented distinct `claude-code-local` Project-tab/context rows for Claude Code local/private MCP state
[02:01] fixed: Project MCP local/private Claude rows now keep same-name `.mcp.json` rows distinct, show `Private • ~/.claude.json`, and hide toggle/edit/remove; 49 project MCP/config tests plus build/package/plist/diff/debug gates passed
[02:13] fixed: spawned and closed subagent Mencius for read-only remaining-gap audit; implemented shared Compatibility-backed skill inventory for ordinary Skills tab and Live Mode context estimates — SkillInventoryReader.swift, SkillStore.swift, SkillsView.swift, ContextEstimator.swift
[02:15] fixed: skill inventory now preserves selected subdirectory skill discovery for Claude and Codex, shows disabled Codex `[[skills.config]]` state, keeps duplicate same-name origins distinct, and removes only the selected writable skill origin; 4 focused tests and 91 broader skill/context tests passed
[09:20] fixed: bulk-finished Profile Copier and compatibility UX edges: project-root profile copying, nested/quoted Codex MCP TOML copy, Live Mode full-path skill toggles, project-scope import credential safety, preview-first import copy, and stale skill path labels
[09:21] fixed: cheap validation passed after bulk compatibility patch — swift build and git diff --check
[09:22] fixed: status docs updated for bulk Profile Copier/Compatibility UX patch; final git diff --check passed
[09:25] fixed: MCP From URL import now downloads direct remote archive links to a temp file and reuses local archive preview for .zip, .tar.gz, .tgz, .mcpb, .dxt, and direct GitHub archive/release assets while keeping release listing pages guided
[09:26] fixed: cheap validation passed after remote archive import patch — swift build and git diff --check
[09:27] fixed: status docs updated for remote archive import support; final git diff --check passed
[09:32] fixed: app-owned MCP auth/runtime states now use dedicated Compatibility issue codes and manual guidance for headersHelper, OAuth metadata, Desktop connectors, and MCPB/DXT extension runtime without executing helpers or reading secrets; swift build and git diff --check passed
[09:37] fixed: Compatibility now exposes an explicit target preset picker for All Supported, Project, Global, CLI, Desktop, and Custom lenses, backed by the existing scope/runtime filters and included in copied Markdown reports; swift build and git diff --check passed
[09:42] fixed: Compatibility now shows a visible four-tool Tool Coverage rollup for Claude Code, Claude Desktop, Codex CLI, and Codex Desktop, and copied Markdown reports include both a coverage matrix and richer detailed matrix columns; read-only subagents closed; swift build and git diff --check passed
[09:48] fixed: MCP import now detects prompt-driven wizard installers before they can be mistaken for bare npx/uv commands, shows a user-driven handoff card with copy/refresh actions, and keeps Project Hub from executing prompt-driven installers; 15 focused import command tests, swift build, and git diff --check passed
[09:53] fixed: Compatibility now separates previewable safe file fixes from truly manual actions, shows Preview fix/Manual badges in findings, and includes Previewable Fixes in copied reports; swift build, focused report tests, and git diff --check passed
[09:58] fixed: GitHub README-only wizard installers and direct fetched README/raw URLs now surface the same prompt-driven installer handoff instead of falling through to "no importable config"; closed completed subagent Descartes after its read-only sanity pass
[09:58] fixed: focused GitHub import URL regression gate passed with 43 tests, and git diff --check passed; skipped redundant swift build because the focused test run compiled the ProjectHub target
[10:02] fixed: local and downloaded source archives now surface wizard-only README installers through the same prompt-driven handoff instead of archiveNoImportableConfig
[10:02] fixed: focused source archive regression gate passed with 14 tests, including wizard-only README archive coverage; git diff --check passed
[10:04] fixed: direct non-GitHub fetched README/raw URLs now enter the import choice/preview flow immediately for one or multiple safe choices instead of only filling the raw text box
[10:04] fixed: combined import regression gate passed with 72 tests across command, GitHub URL, and archive import behavior; git diff --check passed; closed completed subagent Anscombe
[10:11] fixed: Compatibility previewed Codex/Claude settings fixes now apply the exact approved before/after preview for stale-sensitive TOML/JSON config repairs instead of recomputing writer output at apply time
[10:11] fixed: covered invalid Codex enums, project_doc_max_bytes repairs, fallback filenames, project root markers, project trust, ignored project settings, project overlap cleanup, Codex skill overrides, stale skill overrides, deprecated/unknown approval and sandbox fixes, and Claude approval conflict resolution; closed completed subagent Sartre
[10:11] fixed: focused stale-preview validation passed — swift build, 147 focused settings/context/skill repair tests, and git diff --check
[10:17] fixed: MCP import now keeps prompt-driven installer handoff visible as a secondary path when READMEs/source archives also contain safe import snippets; safe choices remain preferred
[10:17] fixed: mixed installer validation passed with 74 focused import tests across command, GitHub URL, and source archive flows; git diff --check passed
[10:24] fixed: prompt-driven MCP installer detection now catches px, npm exec, pnpm dlx, bun, bunx, uvx, pipx run, and unconfigured direct mcp add flows while preserving parseable direct/tool-owned mcp add imports
[10:24] fixed: focused installer detection validation passed with 17 ImportParserCommandTests plus git diff --check; closed completed subagent Fermat after read-only coverage audit
[12:38] fixed: official MCP Registry server.json entries with registryType mcpb now become Claude Desktop extension archive handoff choices instead of being dropped as unsupported packages
[12:38] fixed: registry MCPB choices preserve artifact URL and fileSha256, UI downloads verify SHA-256 before local archive preview, and source archives carrying MCPB server.json surface the same handoff; closed completed subagent Boyle
[12:38] fixed: focused registry/archive validation passed with 26 tests plus git diff --check
[12:50] fixed: ordinary Skills inventory rows now show duplicate-name and version-conflict diagnostics from the Compatibility skill scanner
[12:50] fixed: Codex project sections now parse quoted-root TOML forms like ["projects"."/repo.with.dot"] for project root detection, trust/settings scans, summaries, and trust previews/writes without duplicate appended sections
[12:50] fixed: focused skill/root/settings validation passed with 23 tests plus git diff --check; closed completed subagent Hubble
[12:57] fixed: MCP health and Compatibility scans now classify VS Code-style ${input:...} placeholders as prompt-backed input/auth needs instead of normal environment variables; focused health/auth tests and git diff --check passed
[17:38] fixed: VS Code MCP envFile is now preserved through inventory/import/health/scan paths, reported as app-specific env-file setup or missing env file, and carried into TOML writes as env_file when copied to Codex; closed completed subagent Tesla
[17:38] fixed: focused envFile validation passed with 4 tests across MCPHealthChecker, CompatibilityMCPAuth, ConfigWriterProjectScope, and ImportParserJSON; git diff --check passed
[17:49] fixed: MCP cwd/working-directory compatibility now preserves cwd aliases through inventory/import/scan/health, reports missing cwd directories as broken setup, ignores workspace placeholders as fake env/auth, and runs live stdio Verify from the configured cwd
[17:49] fixed: focused cwd validation passed with 6 tests across MCPHealthChecker, CompatibilityMCPAuth, ConfigWriterProjectScope, ImportParserJSON, and FullConfigReader; git diff --check passed
[18:00] fixed: VS Code MCP sandbox/dev metadata now stays visible for VS Code imports/inventory, Compatibility warns that sandbox/dev behavior is app-specific, and Claude/Codex writes strip sandbox/dev so copied configs do not imply VS Code sandbox enforcement carries across tools
[18:00] fixed: focused sandbox/dev validation passed with 4 tests across ConfigWriterProjectScope, ImportParserJSON, and CompatibilityMCPAuth; git diff --check passed
[21:11] fixed: Roo MCP tool-control/runtime fields now preserve alwaysAllow, disabledTools, watchPaths, timeout, and inline disabled; Compatibility reports them as app-specific behavior; Roo writes inline disabled while Claude/Codex copies strip or map unsupported Roo-only fields safely
[21:11] fixed: focused Roo validation passed with 3 tests across ConfigWriterProjectScope, ImportParserJSON, and CompatibilityMCPAuth; git diff --check passed
[21:19] fixed: MCP health and Compatibility scans now handle editor-style ${env:VAR} templates in commands, args, env maps, URLs, and headers, expand configured values, and report unset or empty values as needs-auth/missing-env before command lookup or URL parsing
[21:19] fixed: focused editor-env validation passed with 3 tests across MCPHealthChecker and CompatibilityMCPAuth; git diff --check passed; closed completed subagent Kuhn
[21:28] fixed: Compatibility now warns when Codex literal env/http_headers values contain ${VAR}/${env:VAR} templates even if the variable is present, and envFile path variables now preflight before generic missing/conversion env-file warnings
[21:28] fixed: focused Codex literal-template/envFile path validation passed with 3 tests across MCPHealthChecker and CompatibilityMCPAuth; git diff --check passed
[21:42] fixed: direct Codex MCP tool controls now preserve enabled_tools, disabled_tools, default_tools_approval_mode, and tools.<tool>.approval_mode through TOML inventory, project writes, health entries, and Compatibility without mislabeling Codex disabled_tools as Roo metadata
[21:42] fixed: focused Codex tool-control validation passed with 3 tests across FullConfigReader, ConfigWriterProjectScope, and CompatibilityMCPAuth; git diff --check passed; closed completed subagent Newton
[21:48] fixed: Docker MCP --env/-e flags now contribute missing host-env auth findings in MCPHealthChecker and Compatibility scans; focused Docker env-flag tests passed
[21:51] fixed: Claude Desktop remote MCP imports/writes are now connector-aware: import planning disables Claude Desktop for hosted/remote servers, UI shows the Connectors handoff, and ConfigWriter rejects remote writes to claude_desktop_config.json; focused planner/writer tests passed
[21:56] fixed: copy-to-apps previews now reuse ConfigWriter's native write blockers, disabling blocked targets before copy; hosted/remote MCPs show the Claude Desktop Connectors handoff instead of appearing copyable into claude_desktop_config.json
[21:57] fixed: focused copy-to-apps compile validation passed after sandbox cache escalation, and git diff --check passed; stale read-only subagent Archimedes closed
[22:02] fixed: hosted OAuth MCP static auth detection now recognizes official GitHub Copilot, Notion, and Atlassian remote MCP hosts in MCPHealthChecker and Compatibility scans, with focused regression coverage added
[22:08] tried_failed: initial focused Docker env-file/mount validation expected broken health when a server had both missing env-file and missing mount; scan records both issues but health priority remains needs-auth first
[22:09] fixed: Docker MCP preflight now reports missing --env-file paths and missing bind/volume host paths in MCPHealthChecker and Compatibility scans; focused hosted-OAuth plus Docker regression tests and git diff --check passed
[22:12] fixed: Docker MCP safe command imports now preserve --env-file/--env-file= as envFile metadata while keeping original Docker args intact
[22:13] fixed: focused Docker env-file import parser tests passed with 3 tests after sandbox cache escalation, git diff --check passed, and read-only subagent Poincare was closed
[22:17] fixed: Docker MCP JSON imports with command arrays or command+args now preserve envFile metadata and Docker env credential hints during normalization
[22:18] fixed: focused ImportParserJSON validation passed with 3 tests after SwiftPM cache escalation; git diff --check passed
[22:20] fixed: Docker structured --mount parsing in MCP health and Compatibility no longer traps on duplicate fields, and now keeps the last repeated field for path diagnostics
[22:21] fixed: focused Docker parser/health duplicate-mount validation passed with 4 tests after SwiftPM cache escalation; git diff --check passed; read-only subagent Popper closed after gap audit
[22:23] fixed: MCP health now treats ${input:...} in envFile and cwd as prompt-backed input requirements before file or directory lookup
[22:23] fixed: focused MCP input-placeholder health validation passed with 4 tests after SwiftPM cache escalation; git diff --check passed
[22:29] fixed: normal MCP inventory readers now normalize command arrays and split safe command strings into command/args for global plugin rows, project server entries, and Claude local project-state details
[22:29] fixed: focused command-array inventory validation passed with 3 tests after SwiftPM cache escalation; git diff --check passed; read-only subagent Euler closed after queueing follow-up gaps
[22:32] fixed: Docker --env-file and mount paths now preflight missing ${env:...} variables and ${input:...} prompts before missing-file/path checks in MCP health and Compatibility
[22:33] tried_failed: focused Docker path validation showed MCP health still reported generic launch env vars before Docker path variables; reordered Docker path preflight above generic arg env checks
[22:33] fixed: focused inventory plus Docker path preflight validation passed with 6 tests after SwiftPM cache escalation; git diff --check passed
[22:36] fixed: MCP command import inference now gives npm exec, npm x, pnpm dlx, and uv run --with wrappers useful server names while preserving wrapper command/args unchanged
[22:38] fixed: MCP health now ignores placeholder OAuth metadata such as your-client-id when deciding whether hosted OAuth endpoints still need login
[22:39] fixed: focused npm/uv import and hosted OAuth placeholder validation passed with 7 tests after SwiftPM cache escalation; git diff --check passed; read-only subagent Euclid closed
[22:45] fixed: Docker MCP mount semantics now distinguish Docker-managed named volumes from explicit bind host paths in health and Compatibility scans — MCPHealthChecker.swift, CompatibilityScanner.swift
[22:45] tried_failed: sandboxed focused Swift tests hit user module-cache permissions, then passed after approved SwiftPM cache escalation — Docker MCP named-volume/bind regressions
[22:45] fixed: focused Docker named-volume/bind validation passed with 3 tests, and git diff --check passed
[22:45] fixed: status docs updated for Docker named-volume/bind semantics and read-only sidecar Banach was closed before batch end
[22:46] fixed: final git diff --check passed after status/worklog updates
[22:48] fixed: Docker structured mount parsing now treats mount type values case-insensitively and skips empty sources — MCPHealthChecker.swift, CompatibilityScanner.swift
[22:48] fixed: focused Docker structured-mount validation passed with 3 tests after SwiftPM cache escalation, and git diff --check passed
[22:48] fixed: status docs updated for Docker structured-mount hardening, and final git diff --check passed
[22:52] fixed: Compatibility OAuth auth checks now ignore placeholder-only OAuth metadata before suppressing hosted-OAuth findings — CompatibilityScanner.swift
[22:52] tried_failed: focused OAuth test compile caught a missing return in the new `contains(where:)` closure; patched the explicit return — CompatibilityScanner.swift
[22:53] tried_failed: focused OAuth test compile caught unavailable `writeJSON` helper in this test file; switched fixtures to direct string writes — CompatibilityMCPAuthTests.swift
[22:56] tried_failed: focused OAuth regression initially matched live user Claude MCP noise; narrowed assertions to the project MCP surface — CompatibilityMCPAuthTests.swift
[22:56] fixed: focused Compatibility OAuth placeholder validation passed with 3 tests after SwiftPM cache escalation, read-only sidecar Bernoulli was closed, and git diff --check passed
[22:57] fixed: status docs updated for Compatibility OAuth placeholder parity
[22:57] fixed: final git diff --check passed after status/worklog updates
[22:59] fixed: official Homebrew MCP command strings now split `brew mcp-server` across import, inventory, health, and Compatibility command normalization — ImportParser.swift, MCPReader.swift, FullConfigReader.swift, ConfigWriter.swift, CompatibilityScanner.swift, MCPHealthChecker.swift
[22:59] tried_failed: sandboxed focused Homebrew MCP command-string tests hit user module-cache permissions; reran with SwiftPM cache escalation
[22:59] fixed: focused Homebrew command-string tests passed with 2 tests after SwiftPM cache escalation, read-only sidecar Volta was closed, and git diff --check passed
[23:00] fixed: status docs updated for Homebrew command-string normalization
[23:00] fixed: final git diff --check passed after Homebrew status/worklog updates
[23:06] fixed: cargo/go MCP command strings now normalize like other safe launcher commands across import, inventory, health, writer, and Compatibility paths
[23:06] fixed: Codex remote MCP TOML writes now preserve env_file dependencies so remote copied servers keep the same env-file health/setup evidence
[23:06] fixed: copied Compatibility reports now include live Verify rows by server ID and show verified health in the MCP Servers table
[23:06] tried_failed: sandboxed focused Swift tests hit user module-cache permissions; reran with SwiftPM cache escalation
[23:06] fixed: focused cargo/go command-string and remote env_file tests passed with 3 tests after SwiftPM cache escalation, and git diff --check passed
[23:07] fixed: status docs updated for cargo/go command strings, Codex remote env_file writes, and copied Verify reports; subagents Turing and Parfit closed; final git diff --check passed
[23:13] fixed: ordinary global/project MCP inventory now ignores placeholder-only OAuth metadata, matching Health and Compatibility auth behavior
[23:13] fixed: Compatibility Verify button/state now uses directly verifiable MCP servers, so app-managed connector/extension-only lenses explain that verification belongs in the owning app instead of doing nothing
[23:13] fixed: malformed Codex plugin MCP policy key/value findings now carry exact section/key metadata and can preview-remove only the invalid policy key with stale-preview protection
[23:13] tried_failed: sandboxed focused Swift tests hit user module-cache permissions; escalated rerun first caught a throwing test wrapper, then passed after adding `try`
[23:13] fixed: focused OAuth inventory and Codex plugin policy tests passed with 3 tests after SwiftPM cache escalation, and git diff --check passed
[23:14] fixed: status docs updated for OAuth inventory parity, Verify gating, and Codex plugin policy cleanup; subagents Aristotle and Peirce closed; final git diff --check passed
[23:22] fixed: OAuth hint-only fields such as callback ports, callback URLs, redirect URIs, and scopes no longer make placeholder OAuth configs look app-managed across inventory, writer, Health, and Compatibility
[23:22] fixed: MCP Health and Compatibility path resolution now expands `${userHome}` in cwd, envFile, Docker env-file, and Docker bind paths before missing path checks
[23:22] fixed: focused OAuth hint-only and `${userHome}` path-placeholder validation passed with 10 tests after SwiftPM cache escalation, and git diff --check passed
[23:29] fixed: generic Compatibility MCP enable/remove fixes now apply the exact approved file preview with stale-preview refusal instead of recomputing mutations later — ConfigWriter.swift, CompatibilityView.swift, ConfigWriterSettingsRepairTests.swift
[23:29] fixed: generic preview apply now uses a neutral text backup/write helper so JSON and TOML previews share the stale-preview guard without TOML-specific wording — ConfigWriter.swift
[23:30] fixed: focused stale-preview writer validation passed with 6 tests after SwiftPM cache escalation, and git diff --check passed
[23:32] fixed: import normalization now unwraps /usr/bin/env command wrappers into the real MCP launcher while preserving wrapper environment hints — ImportParser.swift
[23:33] fixed: MCP Health now unwraps /usr/bin/env command+args wrappers before command, env, Docker env-file, and mount diagnostics — MCPHealthChecker.swift
[23:33] fixed: Compatibility static MCP launch parsing now unwraps /usr/bin/env command arrays and command+args wrappers before Docker/package-runtime diagnostics — CompatibilityScanner.swift
[23:34] fixed: added parser regressions for absolute /usr/bin/env wrappers, command arrays, and command+args MCP snippets — ImportParserCommandTests.swift, ImportParserJSONTests.swift
[23:34] fixed: added Health and Compatibility regressions for /usr/bin/env-wrapped Docker env-file and bind-mount diagnostics — MCPHealthCheckerTests.swift, CompatibilityMCPAuthTests.swift
[23:35] tried_failed: focused env-wrapper validation showed Health test used bare docker on a machine without docker; patching the regression to wrap the test fixture docker path instead — MCPHealthCheckerTests.swift
[23:36] fixed: focused stale-preview and /usr/bin/env wrapper validation passed with 9 tests after SwiftPM cache escalation, and git diff --check passed
[23:36] fixed: status docs updated for stale-preview MCP fixes and /usr/bin/env wrapper compatibility; final git diff --check pending before closeout
[23:36] fixed: final git diff --check passed after status/worklog updates
[23:41] fixed: ImportParser now expands /usr/bin/env -S split-string wrappers and tolerates env -i/-u flags before MCP launch commands — Sources/ProjectHub/Core/ImportParser.swift
[23:42] fixed: MCP health launch normalization now expands /usr/bin/env -S and tolerates env -i/-u before resolving the actual MCP launcher — Sources/ProjectHub/Core/MCPHealthChecker.swift
[23:42] fixed: Compatibility MCP launch diagnostics now unwrap /usr/bin/env -S split strings and env -i/-u wrappers before Docker/package-runner checks — Sources/ProjectHub/Core/CompatibilityScanner.swift
[23:43] fixed: Project discovery now marks skills/instruction/settings-only Claude and Codex folders as tool projects, not only MCP-config folders — Sources/ProjectHub/Stores/ProjectStore.swift
[23:44] fixed: Added focused regressions for env -S MCP command imports and skills/instructions-only project tool detection — Tests/ProjectHubTests/ImportParserCommandTests.swift, Tests/ProjectHubTests/ImportParserJSONTests.swift, Tests/ProjectHubTests/ProjectMCPReaderTests.swift
[23:45] fixed: Codex TOML writes now convert Claude-style Authorization Bearer env-template headers into bearer_token_env_var instead of creating literal Codex http_headers — Sources/ProjectHub/Core/ConfigWriter.swift
[23:45] fixed: Added regression for Claude-style Bearer env-template remote MCP copies into Codex TOML using bearer_token_env_var — Tests/ProjectHubTests/ConfigWriterProjectScopeTests.swift
[23:48] fixed: Added health and Compatibility regressions for /usr/bin/env -S Docker env-file and mount diagnostics — Tests/ProjectHubTests/MCPHealthCheckerTests.swift, Tests/ProjectHubTests/CompatibilityMCPAuthTests.swift
[23:48] fixed: Created skill fixture directories before writing ProjectStore detection regression files — Tests/ProjectHubTests/ProjectMCPReaderTests.swift
[23:49] tried_failed: Focused Swift tests hit the known sandboxed Swift module-cache permission error before compiling — swift test focused compatibility slice
[23:49] fixed: Focused compatibility regression slice passed: env -S import/health/compat, ProjectStore skills/instructions detection, and Codex bearer-token write normalization — swift test --filter targeted 7 tests
[23:49] fixed: Whitespace validation passed after compatibility batch — git diff --check
[23:50] fixed: Updated cowork status with env -S wrapper, ProjectStore marker detection, Codex bearer-header write normalization, and focused validation result — cowork/STATUS.md
[23:50] fixed: Updated agent status recent sessions with env -S, project marker detection, and Codex bearer-header write normalization batch — agents/STATUS.md
[23:50] fixed: Added agents worklog follow-up for this compatibility batch and subagent lifecycle — agents/WORKLOG.md
[23:50] fixed: Closed all three read-only subagents after integrating this batch so fresh subagents can be used next turn — Maxwell, Carver, Copernicus
[18:12] fixed: Added shared MCP launch readback normalizer for env/env -S wrappers, inline env assignments, and Docker env-file/env hints — Sources/ProjectHub/Core/MCPLaunchNormalizer.swift
[18:13] fixed: FullConfigReader global JSON/TOML MCP inventory now unwraps env/env -S launchers and carries derived env/envFile metadata — Sources/ProjectHub/Core/FullConfigReader.swift
[18:13] fixed: ConfigWriter project/global readback entries now unwrap env/env -S launchers and expose derived Docker env/envFile metadata for copy/edit sources — Sources/ProjectHub/Core/ConfigWriter.swift
[18:14] fixed: MCPReader project row details now use shared launch normalization so env -S rows show the real launcher instead of /usr/bin/env — Sources/ProjectHub/Core/MCPReader.swift
[18:15] fixed: Added readback regressions for Codex global inventory and project MCP rows carrying env -S-derived launcher/env/envFile metadata — Tests/ProjectHubTests/FullConfigReaderTests.swift, Tests/ProjectHubTests/ProjectMCPReaderTests.swift
[18:16] fixed: Removed stale private shell-split helpers now replaced by shared MCPLaunchNormalizer in inventory readback owners — Sources/ProjectHub/Core/FullConfigReader.swift, Sources/ProjectHub/Core/ConfigWriter.swift
[18:17] fixed: Added raw-read regression proving ConfigWriter.readServer keeps authored /usr/bin/env -S wrappers while inventory entries normalize separately — Tests/ProjectHubTests/ConfigWriterProjectScopeTests.swift
[18:18] fixed: Added Claude local-state project MCP detail regression for env -S wrapper readback — Tests/ProjectHubTests/ProjectMCPReaderTests.swift
[18:17] fixed: Focused readback parity tests passed: FullConfigReader env -S inventory, project MCP detail/readAll entries, Claude local-state detail, and raw readServer preservation — swift test targeted 4 tests
[18:17] fixed: Whitespace validation passed after inventory readback parity batch — git diff --check
[18:18] fixed: Updated cowork status with env-wrapper inventory/readback parity and focused validation result — cowork/STATUS.md
[18:18] fixed: Updated agent status with env-wrapper inventory/readback parity batch — agents/STATUS.md
[18:18] fixed: Added agents worklog follow-up for shared launch readback normalizer, raw-read guard, validation, and subagent usage — agents/WORKLOG.md
[18:18] fixed: Closed both read-only subagents after integrating readback parity batch — Aristotle and Pauli
[18:24] fixed: Reused structural Codex TOML project-table parsing for project discovery and added skills-only folders as root markers — Sources/ProjectHub/Stores/ProjectStore.swift, Sources/ProjectHub/Core/CompatibilityScanner.swift
[18:24] fixed: Added project-root regressions for both Codex project table spellings and Claude/Codex skills-only root detection — Tests/ProjectHubTests/ProjectRootDetectorTests.swift
[18:25] fixed: Focused ProjectRootDetector regression slice passed after SwiftPM cache escalation — swift test targeted 4 tests
[18:25] fixed: Whitespace validation passed after project discovery/root-marker parity batch — git diff --check
[18:26] fixed: Updated cowork and agent status/worklog with Codex project-table discovery parity, skills-only root markers, validation, and next scout gaps — cowork/STATUS.md, agents/STATUS.md, agents/WORKLOG.md
[18:33] fixed: Added Codex plugin-bundled skill surfaces, disabled-plugin skill findings, and plugin skill manifest path diagnostics — Sources/ProjectHub/Core/CompatibilityScanner.swift
[18:34] fixed: Added focused Compatibility and Skills inventory regressions for Codex plugin-bundled skills — Tests/ProjectHubTests/CompatibilitySkillSupportTests.swift, Tests/ProjectHubTests/SkillInventoryReaderTests.swift
[18:31] tried_failed: Focused SwiftPM skill regression run hit sandbox module-cache permissions before compiling — swift test targeted Codex plugin skill tests
[18:33] fixed: Focused Codex plugin skill regression slice passed after SwiftPM cache escalation — swift test targeted 3 tests
[18:33] fixed: Whitespace validation passed after Codex plugin skill visibility batch — git diff --check
[18:34] fixed: Updated cowork and agent status/worklog with Codex plugin skill visibility batch, validation, and Registry credential-input next gap — cowork/STATUS.md, agents/STATUS.md, agents/WORKLOG.md
[18:38] fixed: Added import-only credential requirement metadata and planner for env/header/URL placeholders without writing Project Hub metadata into target configs — Sources/ProjectHub/Core/ImportParser.swift, Sources/ProjectHub/Core/ImportCredentialPlanner.swift
[18:39] fixed: Import next-step credential hints now use the planner so Registry header and URL variable placeholders appear with env credential prompts — Sources/ProjectHub/Views/MCPImportSheet.swift
[18:39] fixed: Added Registry credential metadata and planner regressions — Tests/ProjectHubTests/ImportParserRegistryManifestTests.swift, Tests/ProjectHubTests/ImportCredentialPlannerTests.swift
[18:38] tried_failed: Focused SwiftPM Registry credential regression run hit sandbox module-cache permissions before compiling — swift test targeted Registry planner/parser tests
[18:39] fixed: Focused Registry credential parser/planner tests passed after SwiftPM cache escalation — swift test targeted 2 tests
[18:39] fixed: Whitespace validation passed after Registry credential-input metadata batch — git diff --check
[18:40] fixed: Updated cowork and agent status/worklog with Registry credential metadata/planner batch and validation — cowork/STATUS.md, agents/STATUS.md, agents/WORKLOG.md
[18:40] fixed: Whitespace validation passed after status/worklog updates — git diff --check
[18:46] fixed: Added credential-aware ConfigWriter update path for env, header, and URL variable requirements — Sources/ProjectHub/Core/ConfigWriter.swift
[18:47] fixed: Added MCPStore credential update bridge that keeps read-only/plugin-owned safeguards before writing credentials — Sources/ProjectHub/Stores/MCPStore.swift
[18:47] fixed: Added credential prompt items and summary helper preserving env/header/URL kinds for import next-step UI — Sources/ProjectHub/Core/ImportCredentialPlanner.swift
[18:48] fixed: Replaced flattened import env hints with typed credential requirements in NextStepsCard and MCPImportSheet — Sources/ProjectHub/Views/NextStepsCard.swift, Sources/ProjectHub/Views/MCPImportSheet.swift
[18:49] fixed: Reused ImportCredentialPlanner prompt items in NextStepsCard so import credential rows preserve typed header/url/env wording from one planner path.
[18:50] fixed: Added focused ConfigWriter credential update coverage for Codex remote header and URL placeholder writes.
[18:52] fixed: Hardened import credential writes for opencode environment shape, Claude Desktop remote write blocking, header-map merging, and choice summaries using the credential planner.
[18:53] tried_failed: Focused Swift test hit sandbox SwiftPM/clang module-cache permissions before compiling; rerunning with approved swift test escalation.
[18:54] fixed: Added explicit return to NextStepsCard credential field builder after focused compile caught opaque View inference failure.
[18:55] tried_failed: Credential writer regression initially asserted remote Codex env preservation that the existing TOML serializer does not support; narrowed it to URL, literal header, and existing header preservation.
[18:56] fixed: Focused credential/import tests passed after typed credential writer hardening: ConfigWriterCredentialUpdateTests plus Registry parser/planner filters.
[18:57] fixed: Updated cowork and agents status with typed import credential save support plus focused validation results.
[18:59] fixed: Surfaced typed MCP import credential requirements in preview rows and moved choice-card credential summaries onto ImportCredentialPlanner.
[18:58] fixed: Added planner coverage for credential requirement summary dedupe and empty-summary behavior.
[18:58] fixed: Focused ImportCredentialPlannerTests passed with 2 tests after adding typed credential summary coverage.
[18:59] fixed: Updated cowork and agents status with pre-install typed credential preview support and focused validation result.
[19:04] fixed: Classified recent Claude Desktop expired-token MCP log signals as auth-expired compatibility findings with redaction and server health propagation.
[19:05] fixed: Narrowed Claude Desktop expired-auth log classifier to explicit reauth signals or expired lines that also mention token/auth/session context.
[19:06] fixed: Focused Claude Desktop expired-auth log compatibility test passed after classifier tightening.
[19:06] fixed: Updated cowork and agents status with Claude Desktop expired-auth log diagnostic support.
[19:14] fixed: Reported existing auth JSON files with empty or placeholder credential-looking fields as needs-auth without leaking secret values.
[19:07] tried_failed: Focused SwiftPM auth-placeholder regression hit sandbox module-cache permissions before compiling — swift test targeted CompatibilityMCPAuthTests/testExistingCodexAuthFileWithPlaceholderTokenIsNeedsAuth
[19:07] fixed: Focused auth-placeholder regression passed after SwiftPM cache escalation — swift test targeted 1 test
[19:07] fixed: Whitespace validation passed after auth-placeholder status updates — git diff --check
[19:11] fixed: Treated OAuth expires_in-style auth fields as relative lifetimes instead of past Unix timestamps — Sources/ProjectHub/Core/CompatibilityScanner.swift
[19:11] fixed: Added Codex auth.json expires_in regression so valid duration metadata does not produce auth-expired/missing findings — Tests/ProjectHubTests/CompatibilityMCPAuthTests.swift
[19:12] tried_failed: Focused SwiftPM auth-expiry regression slice hit sandbox module-cache permissions before compiling — swift test targeted 2 CompatibilityMCPAuthTests
[19:12] fixed: Focused auth-expiry/auth-placeholder regression slice passed after SwiftPM cache escalation — swift test targeted 2 tests
[19:12] fixed: Whitespace validation passed after auth-expiry duration semantics patch — git diff --check
[19:13] fixed: Updated cowork and agent status/worklog with OAuth expires_in auth-scan semantics and validation result — cowork/STATUS.md, agents/STATUS.md, agents/WORKLOG.md
[19:13] fixed: Whitespace validation passed after status/worklog updates — git diff --check
[13:05] fixed: Added MCP Registry object-map header/env input normalization behind existing Registry credential parser helpers — Sources/ProjectHub/Core/ImportParser.swift
[13:05] fixed: Added focused Registry manifest regressions for object-map remote headers and package environmentVariables — Tests/ProjectHubTests/ImportParserRegistryManifestTests.swift
[13:05] tried_failed: Focused SwiftPM Registry object-map regression slice hit sandbox module-cache permissions before compiling — swift test targeted 4 ImportParserRegistryManifestTests
[13:06] fixed: Focused Registry object-map regression slice passed after SwiftPM cache escalation — swift test targeted 4 tests
[13:06] fixed: Whitespace validation passed after Registry object-map input parser batch — git diff --check
[13:06] fixed: Updated cowork and agent status/worklog with Registry object-map credential input support and validation result — cowork/STATUS.md, agents/STATUS.md, agents/WORKLOG.md
[13:06] fixed: Whitespace validation passed after Registry object-map status updates — git diff --check
[13:12] fixed: Added MCP Registry scalar URL-variable normalization for remote and package HTTP transport imports — Sources/ProjectHub/Core/ImportParser.swift
[13:12] fixed: Added focused Registry manifest regressions for scalar remote and package HTTP URL variables — Tests/ProjectHubTests/ImportParserRegistryManifestTests.swift
[13:12] tried_failed: Focused SwiftPM Registry scalar URL-variable regression slice hit sandbox module-cache permissions before compiling — swift test targeted 4 ImportParserRegistryManifestTests
[13:12] fixed: Focused Registry scalar URL-variable regression slice passed after SwiftPM cache escalation — swift test targeted 4 tests
[13:12] fixed: Whitespace validation passed after Registry scalar URL-variable parser batch — git diff --check
[13:13] fixed: Updated cowork and agent status/worklog with Registry scalar URL-variable support and validation result — cowork/STATUS.md, agents/STATUS.md, agents/WORKLOG.md
[13:13] fixed: Whitespace validation passed after Registry scalar URL-variable status updates — git diff --check
[13:19] fixed: Added MCP Registry nested input-variable resolution and skipped literal env defaults in import credential prompts — Sources/ProjectHub/Core/ImportParser.swift, Sources/ProjectHub/Core/ImportCredentialPlanner.swift
[13:19] fixed: Preserved remote header templates when saving imported credential values — Sources/ProjectHub/Core/ConfigWriter.swift
[13:19] fixed: Added focused regressions for nested Registry env/argument variables, literal env prompt filtering, and templated header credential saves — Tests/ProjectHubTests
[13:20] tried_failed: Focused SwiftPM nested Registry variable regression slice hit sandbox module-cache permissions before compiling — swift test targeted 6 tests
[13:20] fixed: Focused nested Registry variable and credential prompt/save regression slice passed after SwiftPM cache escalation — swift test targeted 6 tests
[13:20] fixed: Whitespace validation passed after nested Registry input-variable batch — git diff --check
[13:21] fixed: Updated cowork and agent status with nested Registry input-variable support and validation result — cowork/STATUS.md, agents/STATUS.md
[13:21] fixed: Whitespace validation passed after nested Registry status/worklog updates — git diff --check
[13:25] fixed: Added VS Code mcp.json input metadata as import credential requirements and preserved input-backed header templates on credential save — Sources/ProjectHub/Core/ImportParser.swift, Sources/ProjectHub/Core/ConfigWriter.swift
[13:25] fixed: Added focused regressions for VS Code input-backed env/header/url import prompts and input-backed header credential saves — Tests/ProjectHubTests/ImportParserJSONTests.swift, Tests/ProjectHubTests/ConfigWriterCredentialUpdateTests.swift
[13:27] fixed: Added MCP Health unsupported-transport preflight parity with Compatibility — Sources/ProjectHub/Core/MCPHealthChecker.swift
[13:27] fixed: Added vendor MCP config filename discovery for mcp_settings.json and cline_mcp_settings.json across URL/GitHub/archive import paths — Sources/ProjectHub/Core/ImportParser.swift
[13:27] fixed: Added focused regressions for unsupported transport Health preflight and vendor MCP settings config discovery — Tests/ProjectHubTests
[13:28] tried_failed: Focused SwiftPM input/import/health/vendor filename regression slice hit sandbox module-cache permissions before compiling — swift test targeted 8 tests
[13:28] tried_failed: Focused SwiftPM slice caught Swift compactMap inference issue in new array parser helper — Sources/ProjectHub/Core/ImportParser.swift
[13:28] fixed: Added explicit ParsedServer array type for VS Code input-aware array parsing — Sources/ProjectHub/Core/ImportParser.swift
[13:28] fixed: Focused VS Code input/import/health/vendor filename regression slice passed after SwiftPM cache escalation — swift test targeted 8 tests
[13:28] fixed: Whitespace validation passed after VS Code input, vendor config filename, and Health transport batch — git diff --check
[13:29] fixed: Updated cowork and agent status with VS Code input metadata import, vendor config filename discovery, MCP Health unsupported transport parity, and validation result — cowork/STATUS.md, agents/STATUS.md
[13:29] fixed: Whitespace validation passed after VS Code input/vendor/Health status updates — git diff --check
[13:44] decided: Narrowed active compatibility work to Claude Code, Claude Desktop, Codex CLI, and Codex Desktop; parked Roo/Cline/vendor scout findings per user direction.
[13:44] fixed: Added Claude Code WebSocket MCP transport support with conservative /mcp verification and preserved unsupported WebSocket behavior for Codex/non-Claude targets — Sources/ProjectHub/Core/MCPHealthChecker.swift, Sources/ProjectHub/Core/CompatibilityScanner.swift
[13:44] fixed: Added Codex Desktop admin skill surface for /etc/codex/skills and updated Codex Desktop skill support wording — Sources/ProjectHub/Core/CompatibilityScanner.swift
[13:44] fixed: Added focused regressions for Claude Code ws MCP health/Compatibility and Codex Desktop admin skills — Tests/ProjectHubTests
[13:44] fixed: Focused Claude/Codex regression slice passed with 6 tests and whitespace validation passed — swift test targeted 6 tests, git diff --check
[13:44] fixed: Closed Claude/Codex scout subagents after integrating their findings — Lovelace, Cicero
[13:54] fixed: Updated Codex skill path UX copy to include /etc/codex/skills as admin read-only in Settings and Skills empty states — Sources/ProjectHub/Views/SettingsView.swift, Sources/ProjectHub/Views/SkillsView.swift
[13:54] fixed: Added Claude Desktop host-managed UV MCPB support for installed extension scans and local archive previews without requiring server.mcp_config — Sources/ProjectHub/Core/CompatibilityScanner.swift, Sources/ProjectHub/Core/ImportParser.swift
[13:54] fixed: Added focused regressions for Claude Desktop UV MCPB/no-mcp_config scan and archive preview while preserving Node missing-mcp_config rejection — Tests/ProjectHubTests
[13:54] fixed: Focused Claude Desktop UV MCPB regression slice passed with 5 tests and whitespace validation passed — swift test targeted 5 tests, git diff --check
[13:54] fixed: Closed Claude/Codex scout subagents after integrating their findings — Copernicus, Zeno
[13:58] fixed: Added Claude Desktop account-managed Skills as an explicit Compatibility matrix surface without inventing a local filesystem root — Sources/ProjectHub/Core/CompatibilityScanner.swift, Tests/ProjectHubTests/CompatibilitySkillSupportTests.swift
[13:59] fixed: Updated Claude Code filesystem skill reload semantics to live-watched existing directories with restart only for newly created top-level roots — Sources/ProjectHub/Core/CompatibilityScanner.swift, Tests/ProjectHubTests/CompatibilitySkillSupportTests.swift
[14:02] fixed: Stopped treating Claude settings permissions.additionalDirectories as skill roots and added Codex project-local apps_mcp_product_sku ignored-setting detection — Sources/ProjectHub/Core/CompatibilityScanner.swift, Tests/ProjectHubTests
[14:04] fixed: Focused Claude/Codex skill and ignored-settings regression slice passed with 4 tests and whitespace validation passed — swift test targeted skill/context tests, git diff --check
[14:04] fixed: Closed Claude/Codex scout subagents after integrating their findings — Avicenna, Popper
[14:12] fixed: Added Codex CLI profile-file discovery, selected/default profile MCP/settings matrix surfaces, and active profile-file plugin MCP policy layering without affecting Codex Desktop — Sources/ProjectHub/Core/CompatibilityScanner.swift, Tests/ProjectHubTests/CompatibilityPluginMCPTests.swift
[14:12] fixed: Focused Codex profile-file/plugin MCP regression slice passed with 3 tests and touched-file trailing-whitespace scan passed — swift test targeted CompatibilityPluginMCPTests, rg trailing-whitespace scan
[14:25] fixed: Layered active Codex CLI profile files into instruction fallback/model-instruction settings, plugin discovery, and skill overrides without leaking into Codex Desktop — Sources/ProjectHub/Core/CompatibilityScanner.swift, Tests/ProjectHubTests
[14:25] fixed: Made Codex plugin MCP policy writes target top-level policy when editing a profile config file and added focused writer coverage — Sources/ProjectHub/Core/ConfigWriter.swift, Tests/ProjectHubTests/ConfigWriterCodexPluginPolicyTests.swift
[14:25] fixed: Focused Codex profile-file instruction/skill/plugin/writer regression slice passed with 5 tests and touched-file trailing-whitespace scan passed — swift test targeted profile-file tests, rg trailing-whitespace scan
[14:30] fixed: Added default Codex profile-file readback to normal Global MCP inventory for direct MCP servers and plugin install/policy rows — Sources/ProjectHub/Core/FullConfigReader.swift, Tests/ProjectHubTests/FullConfigReaderTests.swift
[14:30] fixed: Focused FullConfigReader Codex default profile-file inventory regression passed and touched-file trailing-whitespace scan passed — swift test targeted FullConfigReaderTests, rg trailing-whitespace scan
[14:33] fixed: Added read-only Claude Code ~/.claude.json user global config/runtime surface distinct from user MCP and local project state — Sources/ProjectHub/Core/CompatibilityScanner.swift, Tests/ProjectHubTests/CompatibilityContextSettingsTests.swift
[14:33] tried_failed: First focused Claude/Codex inventory test run hit a test compile error from optional-chaining a non-optional surfaceID; fixed assertion and reran successfully — Tests/ProjectHubTests/CompatibilityContextSettingsTests.swift — P3
[14:33] fixed: Focused FullConfigReader default profile-file and Claude Code ~/.claude.json global-config regression slice passed with 2 tests and touched-file trailing-whitespace scan passed — swift test targeted 2 tests, rg trailing-whitespace scan
[14:40] fixed: Added read-only Claude Desktop extension MCP rows to normal Global MCP inventory with manifest/settings placeholder resolution — Sources/ProjectHub/Core/FullConfigReader.swift, Tests/ProjectHubTests/FullConfigReaderTests.swift
[14:40] fixed: Focused Claude Desktop extension Global MCP inventory regression passed and touched-file trailing-whitespace scan passed — swift test targeted FullConfigReaderTests, rg trailing-whitespace scan
[14:48] fixed: Added parser-only Compatibility MCP inventory rows and overlaid them onto Global MCP, Project MCP, and project MCP context estimation while keeping direct ConfigWriter rows writable — Sources/ProjectHub/Core/CompatibilityScanner.swift, Sources/ProjectHub/Core/FullConfigReader.swift, Sources/ProjectHub/Core/MCPReader.swift, Sources/ProjectHub/Views/MCPView.swift, Sources/ProjectHub/Models.swift
[14:48] tried_failed: First focused MCP inventory adapter validation failed on missing return, launch metadata access, and MCPServerInfo id compatibility; fixed and reran successfully — Sources/ProjectHub/Core/FullConfigReader.swift, Sources/ProjectHub/Core/CompatibilityScanner.swift, Sources/ProjectHub/Models.swift — P3
[14:48] fixed: Focused MCP inventory adapter validation passed with 3 tests, swift build passed, and touched-file trailing-whitespace scan passed — swift test targeted FullConfigReader/ProjectMCPReader, swift build, rg trailing-whitespace scan
[14:54] fixed: Made Global MCP health checks use read-only row sourcePath for Compatibility-owned MCP rows while keeping writable rows on canonical tool config paths and skipping direct live launch for Claude Desktop extensions — Sources/ProjectHub/Stores/MCPStore.swift, Tests/ProjectHubTests/FullConfigReaderTests.swift
[14:54] fixed: Focused MCPStore source-path health regression slice passed with 2 tests and touched-file trailing-whitespace scan passed — swift test targeted FullConfigReaderTests, rg trailing-whitespace scan
[15:00] fixed: Added a Compatibility next-step card that routes each scan lens to previewable fixes, manual app-owned follow-ups, live MCP Verify, or rescan — Sources/ProjectHub/Views/CompatibilityView.swift
[15:00] fixed: Compatibility next-step UX build validation passed and touched-file trailing-whitespace scan passed — swift build, rg trailing-whitespace scan
[15:02] fixed: Replaced stale static handshake findings with any live Verify result and added Codex Desktop app-opening handoff for manual fixes — Sources/ProjectHub/Views/CompatibilityView.swift
[15:02] fixed: Compatibility next-step/live Verify UX build validation passed and touched-file trailing-whitespace scan passed — swift build, rg trailing-whitespace scan
[15:06] fixed: Added Claude/Codex quick target presets to MCP import so users can choose All, CLI, Desktop, or Project targets before previewing writes — Sources/ProjectHub/Views/MCPImportSheet.swift
[15:06] fixed: MCP import quick target preset build validation passed and touched-file trailing-whitespace scan passed — swift build, rg trailing-whitespace scan
[15:09] fixed: Changed MCP import apply to write the approved batch preview with stale-file guarding instead of recomputing writes after preview — Sources/ProjectHub/Views/MCPImportSheet.swift
[15:10] fixed: MCP import approved-preview apply build validation passed and touched-file trailing-whitespace scan passed — swift build, rg trailing-whitespace scan
[15:14] fixed: Added Copy MCP diff preview and changed copy apply to use approved preview text with stale-file guarding for global and project destinations — Sources/ProjectHub/Views/MCPCopyToAppsSheet.swift
[15:14] fixed: Added per-destination Copy MCP failure messages for preview/stale-guard failures — Sources/ProjectHub/Views/MCPCopyToAppsSheet.swift
[15:15] fixed: Copy MCP approved-preview apply build validation passed and touched-file trailing-whitespace scan passed — swift build, rg trailing-whitespace scan
[15:17] fixed: Let Copy MCP fall back from active config read to the scanned non-read-only ServerEntry so disabled global rows can still be copied safely as active destinations — Sources/ProjectHub/Views/MCPCopyToAppsSheet.swift
[15:19] fixed: Made ConfigWriter single-server reads fall back to JSON disabled maps before scanned copy fallback and added focused coverage — Sources/ProjectHub/Core/ConfigWriter.swift, Tests/ProjectHubTests/ConfigWriterProjectScopeTests.swift
[15:19] fixed: Focused ConfigWriter disabled-map read regression passed with 1 test and touched-file trailing-whitespace scan passed — swift test targeted ConfigWriterProjectScopeTests, rg trailing-whitespace scan
[15:28] fixed: Narrowed active Global MCP, project detection, project MCP, skill scanning, profile copy, Settings, Hooks, and Project Detail UX to Claude Desktop, Claude Code, and Codex only — Sources/ProjectHub
[15:28] fixed: Blocked Claude Code global MCP writes to private ~/.claude.json while preserving project .mcp.json writes, and made import presets/eligibility surface the CLI handoff — Sources/ProjectHub/Core/ConfigWriter.swift, Sources/ProjectHub/Core/MCPImportScopePlanner.swift
[15:28] fixed: Aligned writer Claude path overrides with scanner overrides and kept Codex SQLite project discovery for non-git Claude/Codex-marked folders — Sources/ProjectHub/Core/ConfigWriter.swift, Sources/ProjectHub/Stores/ProjectStore.swift
[15:28] fixed: Focused Claude/Codex scope and write-policy validation passed — swift build, MCPImportScopePlannerTests, ConfigWriterProjectScopeTests/testClaudeCodeUserScopeIsCliOnlyForWrites, ConfigWriterProjectScopeTests/testToolSpecsUseClaudePathOverrides
[15:40] fixed: Made Claude Code auth use official CLI status first, treat OS credential storage as runtime-managed, and keep ~/.claude.json auth-shaped fields as legacy/inferred redacted evidence — Sources/ProjectHub/Core/CompatibilityScanner.swift
[15:40] fixed: Added Claude Desktop account auth runtime coverage and isolated Claude auth tests from the user's real Claude login/state — Tests/ProjectHubTests/CompatibilityMCPAuthTests.swift
[15:40] fixed: Focused auth validation passed with 37 CompatibilityMCPAuthTests after a stale headersHelper assertion was aligned to runtime-managed auth semantics — swift test --filter CompatibilityMCPAuthTests
[15:46] fixed: Added Claude Code CLI-unavailable auth-source detection for cloud-provider flags, ANTHROPIC_AUTH_TOKEN, ANTHROPIC_API_KEY, apiKeyHelper, and CLAUDE_CODE_OAUTH_TOKEN with redacted source-only findings — Sources/ProjectHub/Core/CompatibilityScanner.swift
[15:46] fixed: Added Claude auth env precedence/redaction coverage and isolated Claude auth env vars from the user's shell during tests — Tests/ProjectHubTests/CompatibilityMCPAuthTests.swift
[15:46] fixed: Focused auth validation passed with 41 CompatibilityMCPAuthTests and whitespace validation passed — swift test --filter CompatibilityMCPAuthTests, git diff --check
[15:52] fixed: Hardened Codex auth classification so env credentials are redacted login inputs, placeholder env values are needs-auth, empty auth.json is not treated healthy, and MCP OAuth stores no longer prove main login — Sources/ProjectHub/Core/CompatibilityScanner.swift
[15:52] fixed: Added Codex auth env/redaction, credentialless auth.json, and MCP OAuth/main-login separation coverage while isolating Codex auth env vars in tests — Tests/ProjectHubTests/CompatibilityMCPAuthTests.swift
[15:52] fixed: Focused auth validation passed with 44 CompatibilityMCPAuthTests and whitespace validation passed — swift test --filter CompatibilityMCPAuthTests, git diff --check
[15:59] fixed: Centralized CODEX_HOME normalization through ProjectHubPaths and wired scanner, reader, writer, project discovery, skill scan, and Compatibility fix plans to trim blanks, expand tilde, and standardize paths — Sources/ProjectHub/Core/ProjectHubPaths.swift, Sources/ProjectHub
[15:59] fixed: Added blank/tilde CODEX_HOME regression coverage for ToolSpecs, Compatibility matrix paths, and ConfigReader readback — Tests/ProjectHubTests
[15:59] fixed: Focused CODEX_HOME normalization validation passed with 3 tests and whitespace validation passed — swift test targeted CODEX_HOME tests, git diff --check
[16:01] fixed: Project MCP tab now derives visible project-scoped tools from ToolSpecs.projectScopedTools, keeping active project MCP UX narrowed to Claude Code and Codex instead of stale Cursor/VS Code/Roo sections — Sources/ProjectHub/Views/MCPView.swift
[16:01] fixed: Project MCP tool-scope validation passed — swift build, git diff --check
[16:02] fixed: Global MCP empty state now names the active Claude/Codex target set instead of stale Cursor/other-tool wording — Sources/ProjectHub/Views/GlobalMCPView.swift
[16:02] fixed: Global MCP wording validation passed — swift build, git diff --check
[16:03] fixed: Hooks reader now returns only Claude Code and Codex hooks, preventing hidden Cursor hooks from making the active Hooks tab look non-empty with no rendered section — Sources/ProjectHub/Core/HooksReader.swift
[16:03] fixed: Hooks scope validation passed — swift build, git diff --check, rg cursorHooks
[16:11] fixed: Codex Hooks now use resolved CODEX_HOME, read global hooks.json, read inline [hooks] from config.toml, and include trusted project .codex hooks.json/config.toml layers — Sources/ProjectHub/Core/HooksReader.swift
[16:11] fixed: Hooks footer now names Claude settings plus Codex hooks/config files instead of only settings.json — Sources/ProjectHub/Views/HooksView.swift
[16:11] fixed: Focused Codex hook validation passed with 2 HooksReaderTests and whitespace validation passed — swift test --filter HooksReaderTests, git diff --check
[19:09] decided: Reset active completion mode to Claude Code, Claude Desktop, Codex CLI, and Codex Desktop only; ignore legacy Cursor/Roo/VS Code/Cline/opencode code unless it leaks into these four tools.
[19:09] fixed: MCP import CLI preset copy now matches write policy: Codex global MCP is writable, Claude Code global MCP is a Claude CLI handoff — Sources/ProjectHub/Views/MCPImportSheet.swift
[19:09] fixed: Focused post-reset validation passed — swift test --filter HooksReaderTests, swift build, git diff --check
[19:17] fixed: Removed active Cursor Rules profile-copy state/API/result handling, narrowed profile MCP copy/readback tests to Claude `.mcp.json` and Codex `.codex/config.toml`, and updated Project Detail copy help text — Sources/ProjectHub/Core/ProfileCopier.swift, Sources/ProjectHub/Views/CopyProfileSheet.swift, Sources/ProjectHub/Views/ProjectDetailView.swift
[19:17] fixed: Preserved nested Claude/Codex project skill-copy behavior while removing false non-primary warnings for nested `.claude/skills` and `.agents/skills` roots — Sources/ProjectHub/Core/ProfileCopier.swift
[19:17] fixed: Focused profile-copy validation passed — swift test --filter ProjectMCPReaderTests/testProfileCopier, swift test --filter ProfileCopierSkillTests, swift build, git diff --check
[19:19] fixed: Removed stale editor fallback labels from active Project MCP, Copy MCP, and Projects list helper switches so active UI fallback paths stay Claude/Codex-only — Sources/ProjectHub/Views/MCPView.swift, Sources/ProjectHub/Views/MCPCopyToAppsSheet.swift, Sources/ProjectHub/Views/ProjectsView.swift
[19:19] fixed: Active-surface fallback validation passed — swift build, git diff --check
[23:44] fixed: Compatibility scan now runs off the SwiftUI main path with a busy state and deterministic XCTest auth probing when no fake Claude command is supplied — Sources/ProjectHub/Views/CompatibilityView.swift, Sources/ProjectHub/Core/CompatibilityScanner.swift
[23:48] fixed: Added Claude Code additional-directory skill roots to compatibility skill-support surfaces and aligned the support detail copy — Sources/ProjectHub/Core/CompatibilityScanner.swift
[23:55] fixed: Corrected additional-directory skill-root dedupe to use file-path canonicalization so symlinked local project state surfaces retain distinct runtime skill roots — Sources/ProjectHub/Core/CompatibilityScanner.swift
[16:18] tried_failed: Full swift test was stopped after repeatedly spending minutes in scanner project-root canonicalization during plugin/managed-policy tests; optimizing the hotspot before rerun — swift test
[16:19] fixed: Replaced project-root canonicalization with file-path canonicalization in compatibility skill override/read paths to remove scanner test and UI scan hotspot — Sources/ProjectHub/Core/CompatibilityScanner.swift
[16:24] fixed: Replaced project-root canonicalization with file-path canonicalization for Codex project-section matching in ConfigWriter trust helpers — Sources/ProjectHub/Core/ConfigWriter.swift
[16:26] fixed: Updated user-scope Codex MCP header writer test to expect established bearer_token_env_var normalization for Bearer ${ENV} Authorization headers — Tests/ProjectHubTests/ConfigWriterSettingsRepairTests.swift
[16:35] found_bug: Full swift test exposed stubbed adjacent project MCP detection returning no visibility findings — Sources/ProjectHub/Core/CompatibilityScanner.swift — P1
[16:42] fixed: Restored adjacent editor project MCP visibility findings for Cursor, VS Code, and Roo project MCP files — Sources/ProjectHub/Core/CompatibilityScanner.swift
[16:43] fixed: Focused adjacent project MCP visibility tests passed after detector restoration — swift test --filter CompatibilityProjectMCPTests/testAdjacentEditorProjectMCP*
[16:45] fixed: CompatibilityProjectMCPTests passed all 21 tests after adjacent MCP detector restoration — swift test --filter CompatibilityProjectMCPTests
[16:50] found_bug: Full swift test still fails 14 assertions across health checker copy, Project MCP reader/root detection for VS Code/Roo project configs, and skill inventory additional-directory expectations — swift test
[16:58] fixed: Restored read-only Cursor/VS Code/Roo project MCP discovery and aligned stale headersHelper/additional-directory skill expectations — Sources/ProjectHub/Core/MCPReader.swift, Sources/ProjectHub/Stores/ProjectStore.swift, Tests/ProjectHubTests/MCPHealthCheckerTests.swift, Tests/ProjectHubTests/SkillInventoryReaderTests.swift
[17:02] fixed: Focused full-failure cluster passed after reader/root/expectation fixes — swift test --filter 'ProjectMCPReaderTests|ProjectRootDetectorTests/testDetects(VSCode|Roo)ProjectMCPMarker|MCPHealthCheckerTests/testVerifyRemoteHeadersHelperIsUnknownAndDoesNotExecuteHelper|SkillInventoryReaderTests/testInventoryIncludesClaudeParentNestedAndSettingsAdditionalDirectoryRoots'
[17:11] fixed: Full Project Hub test suite passed after recovered compatibility and reader fixes — swift test
[17:12] fixed: Final recovered-branch build and whitespace checks passed — swift build, git diff --check
