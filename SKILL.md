---
name: buyingunits
description: "Automated buying-unit mapping for enterprise software sales. Discovers subsidiaries, brands, divisions, acquisitions, and other buying units for any company and persists to local JSON files. Use when user wants to find buying units, map org structure, or analyze enterprise account opportunity."
---

# Buying Units Mapper

Map the full buying-unit landscape for any enterprise company — subsidiaries, brands, business units, geographies, acquisitions, joint ventures, divisions, and regional entities — to understand total addressable opportunity.

## Triggers

Activate this skill when the user says any of:
- "buyingunits" followed by one or more company names
- "find buying units for X"
- "how many buying units does X have"
- "map X's org structure"
- "buying unit analysis for X"
- Questions about previously saved buying unit data (triggers Query/Dashboard mode)

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `FMP_API_KEY` | Optional | Financial Modeling Prep API key for M&A data |

## Local File Storage

All data is stored as local JSON files — no database required.

**Data directory:** `~/claude-skills-data/buyingunits/`

### Directory Structure

```
~/claude-skills-data/buyingunits/
  companies/
    nike.json              # Full company record with buying units
    unilever.json
  runs/
    2026-10-11_nike.json   # Research run log
  index.json               # Master index of all companies
```

### File Formats

**index.json** — Master index:
```json
{
  "nike": {
    "file": "companies/nike.json",
    "bu_count": 46,
    "last_analyzed": "2026-10-11T14:30:00Z",
    "legal_name": "Nike, Inc.",
    "ticker": "NKE"
  }
}
```

**companies/{company}.json** — Full company record:
```json
{
  "company": {
    "name": "Nike, Inc.",
    "ticker": "NKE",
    "hq_location": "Beaverton, OR",
    "industry": "Apparel & Footwear",
    "analyzed_at": "2026-10-11T14:30:00Z"
  },
  "buying_units": [
    {
      "name": "Nike North America",
      "type": "geography",
      "parent": "Nike Brand",
      "confidence": "high",
      "source_name": "SEC EDGAR",
      "source_url": "https://...",
      "tax_types": ["SUT"],
      "tax_complexity_notes": "Nexus in 50 US states",
      "revenue_estimate": "$19B",
      "employee_count": null,
      "hq_location": "Beaverton, OR",
      "industry_vertical": "Apparel & Footwear",
      "customer_status": null
    }
  ],
  "review_actions": [
    {
      "buying_unit_name": "Example Unit",
      "action": "removed",
      "previous_values": { "type": "subsidiary" },
      "timestamp": "2026-10-11T14:35:00Z"
    }
  ]
}
```

**runs/{date}_{company}.json** — Research run log:
```json
{
  "company": "Nike, Inc.",
  "date": "2026-10-11",
  "sources_queried": ["SEC EDGAR", "GLEIF", "Web Search"],
  "buying_units_found": 46
}
```

### Storage Rules

- Use the **Read** tool to load existing JSON files
- Use the **Write** tool to save updated JSON files
- Always read the existing file before writing to ensure additive merges
- Create the `~/claude-skills-data/buyingunits/companies/` and `runs/` directories as needed using Bash `mkdir -p`
- Key names in index.json are lowercase company names with spaces replaced by underscores

## Mode Detection

Determine which mode to run based on user input:

- **Research mode**: User provides company name(s) to analyze → discover and save buying units
- **Query/Dashboard mode**: User asks about previously saved data → read files and generate reports

---

## Research Mode Workflow

### Input
One or more company names (e.g., "buyingunits Nike, Unilever, P&G")

### Step 1 — Confirm Company Identity

For **each** company name provided:

1. **WebSearch** for "{company name} company" to find official info
2. Present to user via **AskUserQuestion**:
   - Legal name
   - Ticker symbol (if public)
   - HQ location
   - Industry
   - Ask: "Is this the right company?"
3. **Confirm ALL companies** before starting any research

### Step 2 — Check Local Data

For each confirmed company, check if data already exists:

1. **Read** `~/claude-skills-data/buyingunits/index.json`
2. Look up the company key (lowercase, underscores for spaces)
3. If found, **Read** the company file at the path in `index.json`

If found, use **AskUserQuestion**: "I found {name} with {count} buying units (last analyzed {date}). Would you like to refresh the data or view existing?"
- **Refresh**: Re-research and merge new findings with existing data
- **View existing**: Skip to Step 5 (present existing data)

### Step 3 — Parallel Research

Research **all companies simultaneously** using the **Agent tool** to launch parallel research agents. For each company, query these sources in order of reliability:

#### 3a. SEC EDGAR (Confidence: high)
- **WebFetch** `https://efts.sec.gov/LATEST/search-index?q=%22{company_name}%22&dateRange=custom&startdt={last_year}&enddt={today}&forms=10-K`
- Find the latest 10-K filing
- **WebFetch** the filing index page to locate Exhibit 21 (Subsidiaries of the Registrant)
- Parse subsidiary names and jurisdictions of incorporation
- If no 10-K found (private company), skip gracefully

#### 3b. GLEIF LEI (Confidence: high)
- **WebFetch** `https://api.gleif.org/api/v1/lei-records?filter[entity.legalName]={company_legal_name}&page[size]=1`
- Extract the LEI from the response
- **WebFetch** `https://api.gleif.org/api/v1/lei-records/{LEI}/ultimate-parent-relationship`
- **WebFetch** `https://api.gleif.org/api/v1/lei-records?filter[entity.legalAddress.country]={country}&filter[relationship.managingLOU]={LEI}&page[size]=100`
- Build parent-child hierarchy from relationship data

#### 3c. FMP — Financial Modeling Prep (Confidence: medium)
Only if `FMP_API_KEY` environment variable is set:
- **WebFetch** `https://financialmodelingprep.com/api/v3/mergers-acquisitions/search?name={company_name}&apikey={FMP_API_KEY}`
- Extract acquisition targets, dates, and deal values
- Each acquisition becomes a buying unit with type `acquisition`

#### 3d. Web Search (Confidence: low-medium)
Run multiple **WebSearch** queries:
- "{company} subsidiaries list"
- "{company} brands portfolio"
- "{company} organizational structure divisions"
- "{company} regional offices locations"
- "{company} acquisitions history"
- "{company} business units segments"

#### 3e. WebFetch Follow-up (Confidence: varies)
From search results, **WebFetch** the most promising URLs:
- Investor relations / annual report pages
- Wikipedia organization/subsidiary sections
- Company "about us" / "our brands" / "our businesses" pages
- Press releases about acquisitions or restructuring

### Step 4 — Build Hierarchy

After all sources are queried:

1. **Deduplicate** across sources — match by name similarity (case-insensitive, trim suffixes like "Inc.", "LLC", "Ltd.")
2. **Build parent-child tree** — use GLEIF relationships as primary hierarchy, supplement with SEC/web data
3. **Classify each entity** with:

| Field | How to determine |
|-------|-----------------|
| `type` | `subsidiary` (SEC/GLEIF), `brand` (consumer-facing name), `business_unit` (internal segment), `geography` (regional entity), `acquisition` (FMP/news), `joint_venture` (ownership <100%), `division` (org chart), `regional_entity` (geographic office) |
| `confidence` | `high` (SEC EDGAR, GLEIF), `medium` (FMP, official website), `low` (web search, inferred) |
| `tax_types` | Infer from jurisdiction: US → SUT, EU → VAT, India → GST, etc. |
| `tax_complexity_notes` | E.g., "VAT registered in 12 EU countries", "Nexus in 38 US states" |
| `revenue_estimate` | From annual reports, press releases, or estimates |
| `employee_count` | From company pages, LinkedIn data in search results |
| `hq_location` | From GLEIF address, company website, or search results |
| `industry_vertical` | From company description or parent industry |
| `source_url` | URL where this entity was discovered |
| `source_name` | 'SEC EDGAR', 'GLEIF', 'FMP', 'Web Search', 'Company Website' |

### Step 5 — Present and Review

Present results for **one company at a time**, sequentially:

#### 5a. Hierarchical Tree View
Display an indented text tree showing parent-child relationships:

```
Nike, Inc. (NYSE: NKE)
├── Nike Brand
│   ├── Nike North America (geography) [high confidence]
│   ├── Nike EMEA (geography) [high confidence]
│   │   ├── Nike European Operations Netherlands BV (subsidiary) [high - SEC]
│   │   └── Nike Retail BV (subsidiary) [high - SEC]
│   └── Nike APLA (geography) [high confidence]
├── Converse (brand) [high - SEC]
│   └── Converse Inc. (subsidiary) [high - SEC]
└── Jordan Brand (brand) [medium - web]
```

#### 5b. Summary Table
Show counts by type and tax complexity highlights in a formatted table.

#### 5c. User Review
Use **AskUserQuestion** to ask the user to review:
- "Review the buying units above. What would you like to do?"
- Options:
  - "Confirm all — looks good"
  - "Remove some — I'll specify which"
  - "Add missing ones — I'll provide details"
  - "Edit classifications — I'll specify changes"
  - "Tag customer status — I'll mark which are customers"

Process each review action:
- **Confirmed**: Set confidence to `confirmed` for all
- **Remove**: Ask which to remove (by number/name), remove from results, log to `review_actions`
- **Add**: Ask for name, type, parent; add to results, log to `review_actions`
- **Edit**: Ask what to change, update, log to `review_actions`
- **Tag status**: Present list, ask user to mark as `customer`, `prospect`, or `not_applicable`

Log every review action to the `review_actions` array in the company JSON file.

### Step 6 — Persist to Local Files

After user confirms:

1. **Read** the existing company file (if any) from `~/claude-skills-data/buyingunits/companies/{company}.json`
2. **Merge** new buying units with existing data:
   - Match by name (case-insensitive)
   - If match found: update fields, but never overwrite user-confirmed data
   - If no match: add as new buying unit
   - Additive only — never remove existing buying units during merge
3. **Write** the updated company JSON file
4. **Read** `index.json`, update the company entry, **Write** back
5. **Write** the research run log to `runs/{date}_{company}.json`

Ensure directories exist before writing:
```bash
mkdir -p ~/claude-skills-data/buyingunits/companies ~/claude-skills-data/buyingunits/runs
```

### Step 7 — Cross-Company Summary

After all companies are reviewed and saved, show an aggregate summary:
- Total buying units across all companies
- Breakdown by type
- Tax complexity overview

---

## Query/Dashboard Mode

Triggered when the user asks questions about previously saved data. Examples:
- "which prospects have the most buying units?"
- "show me all buying units with VAT exposure"
- "coverage gap analysis"

### Capabilities

1. **Read** `~/claude-skills-data/buyingunits/index.json` to get the full list of companies
2. **Read** relevant company files based on the query
3. Filter, aggregate, and analyze the data in-context

#### Common Queries

- **Rank prospects by BU count**: Read index.json, sort by `bu_count` descending
- **Filter by tax regime**: Read all company files, filter buying units where `tax_types` contains the requested regime (e.g., "VAT")
- **Coverage gap analysis**: Read all company files, filter buying units where `customer_status` is not `customer`
- **Custom queries**: Read relevant files and answer the user's question using the data

### Output Formats

Always provide a **chat summary** first with the key findings.

Then ask via **AskUserQuestion**: "Would you like an export?"
- **CSV export**: Generate a CSV file and save to a location the user specifies (default: `~/Downloads/buyingunits_export.csv`)
- **HTML report**: Generate a styled HTML report with tables and save to `~/Downloads/buyingunits_report.html`

#### HTML Report Template
When generating HTML reports, use clean styling with:
- A header with the report title and generation date
- Styled tables with alternating row colors
- Summary statistics at the top
- Responsive layout

#### CSV Export
Use standard CSV format with headers. Include all relevant columns for the query results.

---

## Important Guidelines

1. **Always use AskUserQuestion** for user interactions — never pose questions as plain text
2. **Use Read/Write tools** for local JSON file persistence in `~/claude-skills-data/buyingunits/`
3. **Parallelize research** — Use Agent tool to research multiple companies simultaneously
4. **Be transparent about confidence** — Always show the confidence level and source for each buying unit
5. **Handle errors gracefully** — If a data source is unavailable, skip it and note which sources were used
6. **Respect rate limits** — Space out WebFetch calls; don't hammer APIs
7. **Deduplicate carefully** — The same entity may appear in multiple sources with different names
8. **Preserve user edits** — When refreshing data, merge new findings but never overwrite user-confirmed data
