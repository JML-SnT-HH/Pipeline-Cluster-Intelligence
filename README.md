# Pipeline Cluster Intelligence Dashboard

**Current version:** v1.21  
---

## Overview

Pipeline Cluster Intelligence is a browser-based statistical analysis tool that digests pharmaceutical pipeline exports from GlobalData in an **indication-cluster-centric approach**. No server, no installation — all processing happens in-browser via JavaScript.

### Analytical workflow

```
GlobalData Drug Search exports  (one or more .xlsx files, raw or R-processed)
        ↓
In-browser processing
(header detection · multi-file merge · deduplication · stage normalisation ·
 indication & therapy area extraction · MoA enrichment · regulatory data)
        ↓
Statistical analysis + data visualisation
        ↓
Export: Consolidated Excel  ·  Markdown report  ·  Processed Forecast Excel
```

### Main outputs

1. **Consolidated Pipeline Excel** — one row per Drug ID (highest cluster stage, indication breakdown, regulatory dates, exclusivity). Ready for manual curation and tracking.
2. **Statistical visualisation** — interactive charts across pipeline stage, MoA intelligence, biological approach grouping, modality evolution, pipeline drivers, and market size.
3. **Markdown report** — structured export with quantitative pipeline data + editable analyst notes designed to guide LLM-assisted deep research.

---

## Getting Started

### Step 1 — Export pipeline data from GlobalData

GlobalData caps the number of rows per download. You have two options:

**Option A — Multiple raw batch exports (recommended)**

1. Open **GlobalData** → Database → Drugs → Drug Search
2. Select the therapy areas / indications of interest (use OR to combine)
3. If the result set is large, apply a **Development Stage** filter and export in stage batches (e.g. one file for Pre-clinical to IND, one for Phase I–II, one for Phase III–Marketed)
4. Export each batch as a standard Drug Search Excel: **Export → Excel**
5. Save using a consistent naming convention: `YYYYMMDD_ClusterName_StageBatch.xlsx`
6. Drop **all batch files at once** on the dashboard — the browser merges and deduplicates them automatically

**Option B — Single full export (12-sheet Advanced Data Export)**

1. Open **GlobalData** → Database → Drugs
2. Select all cluster indications
3. Click **Export → Advanced Data Export → select all 12 sheets**
4. Save as: `YYYYMMDD_ClusterName.xlsx`

> Both options are supported in the same drop zone. Raw batch exports and R-processed consolidated files can be mixed in the same drop.

**Option C — R-processed output (legacy)**

Run `GD_indicationcluster.R` on one or more raw exports and drop the resulting `_cluster.xlsx` file. The dashboard detects the Consolidated sheet automatically and loads it directly.

---

### Step 2 (optional) — Export sales forecast from GlobalData

For the Market Size panel:

1. Open **GlobalData** → Database → Drugs
2. Select the same cluster indications
3. Navigate to **Integrated Results** → Sales and Forecast
4. Set **Data Type: Indication** or use **AllDrugForecast** export
5. Export and save as: `SalesForecast_ClusterName.xlsx`

The dashboard accepts both the single-indication Forecast export and the AllDrugForecast multi-sheet format.

---

### Step 3 — Load the dashboard

1. Open `index.html` in any modern browser (Chrome / Edge / Firefox)
2. On the loading screen, drop (or click to browse) into the **Pipeline** zone:
   - One file or multiple batch files — drop them all at once
3. Optionally drop a **Sales Forecast** file
4. Click **Run Analysis →**

A progress bar shows each processing step: file reading → merge & deduplication → consolidated build → regulatory data → done.

---

### Step 4 — Explore and filter

Use the **left panel** to filter the analysis in real time.

**Therapy Area groups (new in v1.21)**

Indications are now grouped under their Therapy Area in collapsible sections:

- Click the **▾ Therapy Area header** to collapse or expand a group
- Use the **None / All** buttons on each Therapy Area header to toggle all indications in that group at once
- Click any individual **indication button** to toggle it

All charts, tables, and the WW Forecast 2032 KPI update instantly when filters change.

**Other filters**

| Filter | Options |
|--------|---------|
| Drug Type | Generic · Biosimilar · Innovator · Innovator (Non-NME) |
| Geography | Global · Europe · United States · Japan · China |
| Stage of Development | Disc → PreC → Ph1 → Ph2 → Ph3 → Pre-R → Mkt |

---

### Step 5 — Export results

From the left panel footer:

| Button | Output |
|--------|--------|
| ↓ Pipeline Excel | Consolidated + Per_Indication + Metadata sheets |
| ↓ Forecast Excel | Global Only (Dashboard) + All Geographies (Long) sheets |
| ✎ Export Analysis → .md | Structured Markdown with analyst input sections for LLM research |

---

## Dashboard Tabs

| Tab | Content |
|-----|---------|
| **Overview** | Stage waterfall · Stage × Indication · Active vs. Disc · Modality pie · Drug Explorer |
| **Indication Landscape** | Indication cards · Priority bubble matrix · Ranked table |
| **MoA Intelligence** | MoA × Stage heatmap · Validated / Emerging / Failed classification |
| **Biological Approach** | Approach stacked bar · Per-approach insight cards with MoA breakdown |
| **Modality & Innovation** | Modality evolution · Stage × Modality · FiC innovation frontier |
| **Pipeline Drivers** | Top sponsors · HQ geography · Multi-indication drug leaders |
| **Market Size** | Approval/launch timeline · Exclusivity cliff · Forecast area charts |
| **Strategic Digest** | Key findings · Invest / Watch / Avoid framework · Attrition analysis |

---

## Stage Classification

| Dashboard label | GlobalData source values |
|----------------|--------------------------|
| Disc | Inactive · Withdrawn · Discontinued · Archived · Unknown · Filing Rejected/Withdrawn |
| PreC | Preclinical · Discovery · IND/CTA Filed · **Phase 0** |
| Phase I | Phase I |
| Phase II | Phase II |
| Phase III | Phase III |
| Pre-R | Pre-Registration · Preregistration |
| Mkt | Marketed |

> **Note:** Phase 0 maps to PreC (not Discontinued), consistent with its position in the development sequence.

---

## File Structure

```
repo/
├── index.html                              # Main dashboard (v1.21)
├── <background>.jpg                        # Landing page background
├── 00A.fonts/                              # Custom font files (not included)
├── preprocess_forecast.R                   # Legacy: R script to pre-process wide forecast Excel
├── GD_indicationcluster.R                  # Optional: R script for advanced pipeline enrichment
├── Indication_Cluster_Expansion_Notes.md   # Developer notes for onboarding new clusters
└── README.md
```

> **Note:** The `.xlsx` data files (GlobalData exports) are **not included** in the repository — they contain proprietary pharmaceutical intelligence and must be exported from your GlobalData subscription.

---

## Hosting on GitHub Pages

1. Push all files in the **File Structure** table above to the `main` branch of your repository
2. Go to **Settings** → **Pages**
3. Source: `Deploy from a branch` → Branch: `main` → Folder: `/ (root)`
4. Click **Save**
5. Your dashboard will be live at `https://<username>.github.io/<repo-name>/`

> GitHub Pages serves static files only — no server-side processing. This dashboard is fully compatible because all computation happens in the browser.

---

## Expanding to Other Clusters

The tool is cluster-agnostic. To analyse a new cluster:

1. Export GlobalData for the new cluster's indications (see Step 1 above)
2. Drop the export(s) — the dashboard auto-detects all indication values directly from the data rows, grouped by Therapy Area
3. No configuration of indication names is required
4. For new clusters, check the **Biological Approach** tab: if >30% of drugs fall into "Other", the `BIO_RULES` in the HTML may need extending for that cluster's dominant MoA families

See `Indication_Cluster_Expansion_Notes.md` for the full onboarding checklist.

---

## Caution & Limitations

> ⚠ **Beta version** — Always cross-check key data points against the source GlobalData export before using outputs in decisions or reports.

- **MoA abbreviation** — when loading raw batch exports (Option A), MoA labels in the donut chart show the full GlobalData MoA string rather than abbreviated gene names. The full 12-sheet export (Option B) produces abbreviated labels via the Drug Target Details sheet.
- **Generic volume** — large mature clusters include many generics. Apply the **Innovator** Drug Type filter for innovation-focused analysis.
- **Attrition ≠ scientific failure** — high discontinuation rates in well-established classes often reflect commercial displacement, not mechanism failure.
- **GlobalData coverage** — pipeline data skews toward US/EU innovators. Chinese and Indian generic pipelines may be under-represented.
- **Font licensing** — font files are not distributed with this repository. Supply your own licensed fonts in `00A.fonts/` or use an open-source alternative (e.g. Inter, Roboto).

---

## Version History

| Version | Key changes |
|---------|-------------|
| v1.21 | Multi-file raw pipeline drop; Therapy Area collapsible groups in left panel; Phase 0 → PreC fix; indication filters use full names from data rows; regulatory & exclusivity data read from all dropped files |
| v1.20 | Market Size tab fix: AllDrugForecast multi-sheet deduplication (was 6× data inflation); drug forecast chart empty-state bug fixed |
| v1.19 | RoA donut rendering fix; README added |
| v1.12 | Font path fix (`00A.fonts/`); all text renders in the custom font |
| v1.10 | Two-column drop screen layout; GlobalData export instructions |
| v1.06 | Markdown export modal with editable analyst sections |
| v1.05 | Forecast preprocessing in-browser; Region vs Segment geo fix |
| v1.04 | Full in-browser GlobalData + forecast processing; no R required |
| v1.00 | Baseline release — validated on initial cluster, all tabs functional |
