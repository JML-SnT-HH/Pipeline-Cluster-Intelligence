# Pipeline Cluster Intelligence Dashboard

**Current version:** v1.12  
**Developed by:** BioInnovation Institute · S&S Team 
**Contact:** Jamie Lin — jml@bii.dk

---

## Overview

Pipeline Cluster Intelligence is a browser-based statistical analysis tool that digests complex pharmaceutical pipeline exports from GlobalData in an **indication-cluster-centric approach**. No server, no installation, no R runtime required at runtime — all processing happens in-browser via JavaScript.

### Analytical workflow

```
GlobalData Export (raw .xlsx)
        ↓
In-browser processing
(header detection · geo filter · MoA enrichment · stage normalisation)
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

1. Open **GlobalData** → Database → Drugs
2. Select **all indications** belonging to the cluster of interest using the Therapy Area / Indication filter (join multiple indications with OR)
3. Click **Export** → Advanced Data Export
4. Select **all 12 data sheets**
5. Save as: `YYYYMMDD_ClusterName.xlsx` (e.g. `28052026_SEQ-1.xlsx`)

### Step 2 (optional) — Export sales forecast from GlobalData

For the Market Size panel:

1. Open **GlobalData** → Database → Drugs
2. Select the same cluster indications
3. Navigate to **Integrated Results** → Sales and Forecast
4. Set **Data Type: Indication**
5. Export and save as: `SalesForecast_ClusterName.xlsx`

### Step 3 — Load the dashboard

1. Open `index.html` in any modern browser (Chrome / Edge / Firefox)
2. On the loading page, drop (or click to browse):
   - **Pipeline Export** (required)
   - **Sales Forecast** (optional — for Market Size tab)
3. Click **Run Analysis →**

### Step 4 — Explore and filter

Use the **left panel** to filter the analysis in real time:
- **Indication Names** — toggle individual indications or click **ALL** to select all
- **Drug Type** — Generic / Biosimilar / Innovator
- **Geography** — Global / Europe / United States / Japan / China
- **Stage of Development** — Disc → PreC → Ph1 → Ph2 → Ph3 → Pre-R → Mkt

All charts, tables, and the WW Forecast 2032 KPI update instantly when filters change.

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

## File Structure

```
repo/
├── index.html                          # Main dashboard (v1.12)
├── BII_bg.jpg                          # Landing page background
├── 00A.fonts/
│   ├── NovoApplySans-Rg.ttf
│   ├── NovoApplySans-Md.ttf
│   └── NovoApplySans-Bd.ttf
├── preprocess_forecast.R               # Optional: R script to pre-process wide forecast Excel
├── GD_indicationcluster.R              # Optional: R script for advanced pipeline enrichment
├── Indication_Cluster_Expansion_Notes.md   # Developer notes for onboarding new clusters
└── README.md
```

> **Note:** The `.xlsx` data files (GlobalData exports) are **not included** in the repository — they contain proprietary pharmaceutical intelligence and must be exported fresh from your GlobalData subscription.

---


## Expanding to Other Clusters

The tool is designed to be cluster-agnostic. To analyze a new cluster (e.g. MET-1 Diabetes, CV-1 ASCVD):

1. Export GlobalData for the new cluster's indications (same steps as above)
2. Drop the new export — the dashboard auto-detects indications from the file header
3. For new clusters, check the **Biological Approach** tab: if >30% of drugs fall into "Other", the `BIO_RULES` in the HTML may need extending for that cluster's dominant MoA families

See `Indication_Cluster_Expansion_Notes.md` for the full onboarding checklist and known shortcomings per cluster type.

---

## Caution & Limitations

> ⚠ **Beta version** — This tool is in active development. Always cross-check key data points against the source GlobalData export before using outputs in investment decisions or reports.

Known limitations:
- **Generic volume** — large mature clusters (MET-1, CV-1) include many generics. Apply the **Innovator** Drug Type filter for innovation-focused analysis.
- **Attrition ≠ scientific failure** — high discontinuation rates in well-established classes (e.g. sulfonylureas) often reflect commercial displacement rather than mechanism failure. Human interpretation required.
- **GlobalData coverage** — pipeline data skews toward US/EU innovators. Chinese and Indian generic pipelines may be under-represented.
- **Font licensing** — NovoApplySans is a proprietary Novo Nordisk typeface. If hosting publicly, confirm font distribution rights or replace with an open-source alternative (e.g. Inter, Roboto).

---

## Version History

| Version | Key changes |
|---------|-------------|
| v1.12 | Font path fix (`00A.fonts/`); all text renders in NovoApplySans |
| v1.11 | Font inheritance rule; NONE buttons removed (ALL only) |
| v1.10 | Two-column drop screen layout; GlobalData export instructions |
| v1.09 | Tab title; project description on landing page; ALL buttons per filter group |
| v1.08 | BII background image; relative path; 18% opacity |
| v1.07 | Y-axis headroom; dynamic bar width; forecast chart legend fix |
| v1.06 | Markdown export modal with editable analyst sections |
| v1.05 | Forecast preprocessing in-browser; `Region` vs `Segment` geo fix |
| v1.04 | Full in-browser GlobalData + forecast processing; no R required |
| v1.03 | Stacked area charts use `stackgroup` (true stacking, not overlap) |
| v1.02 | Forecast side-by-side layout; left panel syncs to forecast charts |
| v1.01 | BIO_RULES extended for MET-1 / cross-cluster support |
| v1.00 | Baseline release — SEQ-1 validated, all tabs functional |

---

*Pipeline Cluster Intelligence · BioInnovation Institute · CMD Landscape · 2026*
