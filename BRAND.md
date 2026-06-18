# BRAND.md — Project Hub
> What every agent must know before touching this project.

## Product

- **Name:** Project Hub
- **One sentence:** A native macOS menu bar app for managing all your AI coding tool configurations — skills, agents, MCP servers, hooks, and CLAUDE.md — across every project in one place.
- **Live Mode:** Floating context monitor that shows real-time Claude Code token usage and lets you toggle skills/MCPs on the fly.

## User

- **Who it's for:** Developers actively using Claude Code (and/or Cursor, Codex) across multiple projects who are tired of manually managing per-project configs
- **Problem it solves:** Each project needs its own set of skills, agents, MCP servers, and CLAUDE.md — managing this manually is error-prone and time-consuming
- **What it is NOT:** An MCP installer for end-users (that's mcpbolt), a team tool, a cloud service, or a chat app

## Personality

- **Tone:** Fast and opinionated — native macOS, minimal, premium. Feels like a pro tool built for power users.
- **Values:** Speed, privacy, local-only, native macOS feel, zero cloud dependencies
- **Feel:** Deep integration with Claude Code's internals. Knows your projects better than any other tool.

## What NOT to build

- No cloud sync / remote storage / accounts of any kind
- No team features, SSO, enterprise pricing, multi-seat licenses
- No chat interface or LLM calls inside the app
- No feature creep into generic launcher territory (not Raycast, not Alfred)
- No subscription pricing — lifetime only if paid
- No web app or Windows version
