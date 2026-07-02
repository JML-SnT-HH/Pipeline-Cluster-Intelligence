# Pipeline Cluster Intelligence Dashboard — v1.19

**Status**: Beta · Internal use · Single-file browser tool  
**File**: `Indication_Cluster_v1.19.html`  
**Data source**: GlobalData Pharmaceutical Intelligence (Pipeline export)  
**Last updated**: 02 July 2026

---

## What it does

The Pipeline Cluster Intelligence Dashboard ingests a GlobalData pipeline export and renders an interactive multi-tab analysis environment in the browser — no server, no installation, no data leaving your machine. Drop in an Excel file, set your filters, and the dashboard computes and visualises the full competitive landscape for any cardiometabolic disease cluster: indication counts, stage profiles, MoA diversity, modality trends, company positioning, market forecasts, and a narrative strategic digest.

The tool is designed for analyst work that sits at the intersection of scientific pipeline intelligence and investment decision-making. It is not a BI dashboard with pre-loaded data — it is a processing and visualisation layer on top of GlobalData exports that would otherwise require manual pivot tables.

---

## Data export from GlobalData

### Step 1 — Configure the pipeline search

1. Go to **GlobalData > Pharmaceutical Intelligence > Pipeline**.
2. Set your disease/indication cluster. For cardiometabolic work this typically means selecting conditions across the metabolic–cardiovascular–renal–hepatic axis (e.g. obesity, T2DM, HFpEF, NASH, CKD, dyslipidaemia). Be mightful of disease definition and use quality controls of drugs to ensure you're exporting the annotated indication in GlobalData
3. Be mindful of GlobalData exports (common restriction of 3000 entries). Beyond limits, the export might be compromised without the full list. 

### Step 2 — Export

Select **Export > Advance Export** and click **Select All** for all 12 sheets. The file format GlobalData produces is what the dashboard expects directly — do not re-structure columns before loading.

**The dashboard sorting will be guided by the indication selection when you queried GlobalData.**

The dashboard reads the following GlobalData columns (column names must match exactly):

| Column | Used for |
|---|---|
| `Drug Id` | Deduplication key |
| `Drug Name` | Drug Explorer, labels |
| `Company Name` | Company Intelligence, sponsor charts |
| `Indication` | All per-indication analysis |
| `Development Stage` | Raw stage parsing |
| `Highest_Cluster_Stage` | Stage classification (primary) |
| `Drug Type` | Innovator / non-NME filter |
| `Drug Geography` | Geography filter |
| `MoA` / `MoA_abbr` | MoA Intelligence tab |
| `Target_abbr` | MoA × Target views |
| `Modality_C` | Modality tab |
| `Route of Administration` | RoA donut chart |
| `First-In-Class` | FiC frontier analysis |
| `Headquarters` | HQ geography chart |
| `Launch Date` / `Approval Date` / `Exclusivity Date` | Market tab timelines |
| `Indication_Stages` | Stage × Indication rendering |
| `Cluster` | Cluster name in digest |
| `Reason for Discontinuation` | Attrition breakdown in digest |


---

## Loading data

1. Open `index.html` in Chrome or Edge (Firefox works but is not the primary test target).
2. On the landing page you will see two drop zones:
   - **Pipeline file** — drop the processed pipeline Excel here (required).
   - **Forecast file** — drop the GlobalData market forecast Excel here (optional; unlocks the Market Size tab).
3. Once the pipeline file is loaded, the left panel populates with filter options.

The tool holds all data in browser memory. Refreshing the page clears everything; you will need to reload the files.

---

## Left panel filters

Four filter groups control what the entire dashboard analyses:

**Indication** — select one or more disease indications from the cluster. All tabs update to reflect only the selected indications.

**Drug Type** — filter by NME / Innovator classification. "Innovator" = novel molecular entities only; unchecking shows all types including biosimilars, generics, and reformulations.

**Geography** — filter by regulatory geography (Global, US, EU, etc.).

**Development Stage** — filter to specific pipeline stages (Marketed, Phase III, Phase II, Phase I, Pre-clinical, Discontinued).

Each filter group has **None** and **All** buttons for rapid selection. The dashboard shows an empty state until at least one filter is active. All charts and exports reflect the active filter state.

---

## Tabs

### Overview

The entry point for any pipeline analysis. Shows six panels:

- **Pipeline by Development Stage** — bar chart of drug counts by stage, split by indication.
- **Stage × Indication** — heatmap of stage distribution across indications.
- **Active vs. Discontinued** — grouped bar showing active versus discontinued drugs per indication, with attrition rate annotation.
- **Modality Distribution** — bar chart of drug modalities (small molecule, antibody, cell therapy, etc.) by indication.
- **Route of Administration** — donut chart showing the distribution of administration routes across the active selection. Multi-RoA drugs are counted per route. Entries with no RoA data are classified as N/A.
- **Drug Explorer** — sortable, searchable table of all drugs in the current selection with key metadata columns.

### Indication Landscape

Priority analysis across indications:

- **Indication Priority Matrix** — scatter plot of pipeline size vs. attrition rate per indication; helps identify high-activity vs. high-failure areas.
- **Indication Priority Table** — tabular version of the same, sortable.

### MoA Intelligence

Mechanism of action analysis:

- **MoA × Stage Heatmap** — which mechanisms are concentrated at which development stages. Distinguishes validated (marketed), clinical-stage, and pre-clinical mechanisms.

### Biological Approach (WIP)

- **Pipeline by Biological Approach** — breakdown of biological approach classification (e.g. enzyme replacement, gene silencing, receptor agonism) across the selection.

### Modality & Innovation

Two views on drug type and innovation:

- **Modality Evolution** — how modality mix changes across development stages.
- **Stage × Modality** — heatmap of modality vs. stage drug counts.
- **Innovation Frontier — First-In-Class Pipeline** — highlights FiC-designated drugs with their sponsor and stage.

### Pipeline Drivers (Sponsors)

Sponsor-level pipeline analysis:

- **Top Pipeline Sponsors** — ranked bar chart of companies by drug count.
- **HQ Geography** — geographic distribution of sponsor headquarters.
- **Multi-Indication Drug Leaders** — drugs covering the broadest indication footprint.

### Company Intelligence

Seven charts profiling competitive company positioning:

- **Top 20 — Companies with Marketed Drug** — horizontal stacked bar showing marketed companies' full pipeline by stage (Marketed through Pre-clinical).
- **Top 20 — Pipeline-Only Companies** — same chart for companies with no marketed product in the selection.
- **Marketed Companies × Indication** — heatmap of drug counts per company per indication (marketed group).
- **Pipeline-Only Companies × Indication** — same for pipeline-only group.
- **Stage Profile — Top 20 Companies** — stacked bar showing stage composition per company, sorted by pipeline size.
- **First-In-Class Asset Leaders** — which companies hold the most FiC-designated assets.
- **Pipeline Breadth vs. Size** — scatter plot of number of indications covered (breadth) vs. total drugs; identifies focused vs. platform-style players.

Pipeline concentration is also reported as a Herfindahl-Hirschman Index (HHI) KPI strip: below 1,500 = Fragmented; 1,500–2,500 = Moderate; above 2,500 = Concentrated.

### Market Size

Requires a forecast file. Shows four views based on GlobalData forecast data:

- **Forecast Market Size — By Indication** — projected revenue by indication over the forecast horizon.
- **Forecast Market Size — By Drug** — projected revenue by individual drug.
- **Approval Timeline** — drugs by approval date.
- **Launch Timeline** — drugs by launch date.
- **Exclusivity Cliff** — drugs approaching exclusivity expiry.
- **Geographic Approval Coverage** — which regulatory geographies each drug is approved in.
- **Exclusivity Code Breakdown** — classification of exclusivity types.

### Strategic Digest

An auto-generated narrative summary of the current selection. Covers:

- Total pipeline size, active/discontinued split, attrition rate, marketed count, MoA diversity, and FiC count.
- Top attrition reasons (by count from Reason for Discontinuation field).
- Key findings: validated mechanisms (those with marketed drugs), failed mechanisms (high discontinuation), and emerging FiC assets.

The digest refreshes whenever the filter state changes.

---

## Excel downloads

Three download buttons appear in the top bar once data is loaded:

### Pipeline Excel — All

Contains all drugs in the current filter selection. Sheets:

- **Consolidated** — one row per drug with all key fields.
- **Per_Indication** — one row per drug × indication combination (long format).
- **Companies** — one row per company with drug counts by stage and indication coverage. Columns: Company, Total Drugs, Active, Discontinued, Marketed, Pre-Registration, Phase III, Phase II, Phase I, Pre-Clinical, # Indications, plus one column per indication showing drug count.
- **All Geographies (Long)** — per-drug geography breakdown.
- **Global Only (Dashboard)** — the subset of drugs with global development geography.
- **Metadata** — filter state, export timestamp, record counts.

### Pipeline Excel — Innovator NME Only

Identical structure to the All download, but restricted to Innovator/NME-classified drugs. Sheets are suffixed `_Innovator`:

- **Consolidated_Innovator**
- **Per_Indication_Innovator**
- **Companies_Innovator**
- **Metadata**

### Forecast Excel

Only available when a forecast file is loaded. Exports the processed forecast data with sheets for global summary and per-indication breakdown.

---

## Per-chart exports

Every chart panel has two export buttons:

- **↓ PNG** — downloads a 1200 × 600px PNG of the chart (via Plotly).
- **↓ Excel** — downloads the underlying data table for that chart as a standalone Excel file.

The Drug Explorer table has its own export to Excel.

### Markdown digest export

The Strategic Digest tab has a **↓ MD** button that downloads the narrative text as a `.md` file, suitable for pasting into reports or meeting notes.

---

## Stage classification

The dashboard uses a ranked stage system to determine a drug's highest achieved stage when a drug appears across multiple indications or has conflicting stage entries:

| Stage | Rank |
|---|---|
| Marketed | 99 |
| Pre-registration | 98 |
| Phase III | 97 |
| Phase II | 96 |
| Phase I | 95 |
| Pre-clinical | 94 |
| Discontinued | 1 |

`Highest_Cluster_Stage` is computed by the R pre-processing script. Within the dashboard, attrition is defined as rank ≤ 1 (Discontinued only); all other stages are counted as active.

---

## Technical notes

**Browser-only, no server required.** The entire tool — data processing, charting, Excel generation — runs client-side. The HTML file bundles Plotly.js (charting) and SheetJS (Excel read/write) via CDN references; an internet connection is required on first load to fetch these libraries.

**Data privacy.** No data is transmitted to any external server. All processing happens in the browser tab. Closing or refreshing the tab destroys the loaded data.

**File size.** The GlobalData export for a broad cardiometabolic cluster (10–15 indications, all stages) is typically 5,000–20,000 rows. The dashboard handles this comfortably. Very large exports (50,000+ rows) may produce slower chart render times on lower-spec machines.

**Supported browsers.** Chrome (primary) and Edge. Firefox is functional. Safari has known Plotly rendering edge cases and is not recommended for export workflows.


---

## Known limitations (v1.19)

- The **Strategic Digest** narrative is rule-based (template-driven), not LLM-generated. It reflects the statistical summary of the loaded data but does not provide strategic interpretation beyond what the underlying metrics support.
- The **Market Size** tab is entirely dependent on GlobalData forecast availability; indications with no forecast data produce empty panels.
- Company name parsing splits on the first semicolon or comma in the `Company Name` field — co-development partnerships are attributed to the first-named company only.
- RoA data quality depends on GlobalData's field population; sparse fields aggregate into the N/A category.
- The tool does not persist state between sessions. Filter selections, loaded files, and chart states are lost on page refresh.

---

*Pipeline Cluster Intelligence Dashboard is an internal BII tool at beta test*
