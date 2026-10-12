# Buying Units Mapper — Team Version

Automated buying-unit mapping for enterprise software sales. Discovers subsidiaries, brands, divisions, acquisitions, and other buying units for any company using public data sources.

This is the **team version** — uses local JSON file storage instead of a shared database, so anyone can install and run it independently.

## Quick Start

### Option 1: Claude Code (full features)

```bash
git clone https://github.com/RyLoki/buyingunits-team.git
cd buyingunits-team
./install.sh
```

Then in Claude Code:
```
/buyingunits Nike
```

### Option 2: claude.ai Projects

1. Open [claude.ai](https://claude.ai) and create a new Project
2. Copy the contents of [`claude-ai/project-instructions.md`](claude-ai/project-instructions.md) into the Project Instructions
3. Start a conversation:
   ```
   buyingunits Nike
   ```

## Feature Comparison

| Feature | Claude Code (local) | claude.ai Projects |
|---------|--------------------|--------------------|
| Web research | Full (WebSearch + WebFetch) | WebSearch only |
| Parallel research | Yes (Agent tool) | No (sequential) |
| Persistent storage | Local JSON files | Artifacts in project |
| Query/dashboard mode | JSON file reads | Artifact search |
| CSV/HTML export | Auto-save to disk | Copy from artifact |
| SEC EDGAR direct access | Yes (WebFetch) | Search-based |
| GLEIF API access | Yes (WebFetch) | Search-based |
| FMP M&A data | Yes (with API key) | No |

## How It Works

1. **Confirm** company identity with the user
2. **Research** using SEC EDGAR, GLEIF LEI, FMP (optional), and web search
3. **Build** a hierarchical tree of buying units with confidence scoring
4. **Review** with the user — confirm, add, remove, edit, tag customer status
5. **Persist** to local JSON files (Claude Code) or artifacts (claude.ai)

## Data Storage (Claude Code)

All data lives in `~/claude-skills-data/buyingunits/`:

```
~/claude-skills-data/buyingunits/
  companies/
    nike.json              # Full company record with buying units
  runs/
    2026-10-11_nike.json   # Research run log
  index.json               # Master index of all companies
```

No external database, no API keys required (FMP is optional for M&A data).

## Related

- [techstack-team](https://github.com/RyLoki/techstack-team) — Tech stack discovery skill (uses buying unit data from this skill)
