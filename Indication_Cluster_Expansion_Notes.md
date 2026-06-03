# CMD Indication Cluster Dashboard — Agile Expansion Notes

**File:** `Indication_Cluster_vX.XX.html`  
**Last reviewed:** June 2026  
**Scope:** Guidance for onboarding new CMD indication clusters into the pipeline intelligence dashboard

---

## 1. Architecture — What Is Already Cluster-Agnostic

The dashboard was built to be data-driven from the start. The following components require **zero changes** for any new cluster:

- **Header detection** — Reads the queried indications directly from the GlobalData export's "Therapy Area / Indication:" row. No hardcoded indication names.
- **Stage distribution, MoA heatmap, Drug Explorer** — Fully derived from the loaded pipeline data.
- **Validated / Emerging / Failed MoA classification** — Rule-based on attrition rates and stage reached; applies universally.
- **Sponsor rankings, HQ geography, multi-indication drug leaders** — All aggregated from the data.
- **Regulatory timeline** — Approval dates, launch dates, exclusivity cliff — read from GlobalData Regulatory Information and Exclusivity Details sheets.
- **Left panel filters** — Indication names are dynamically populated from the loaded file; Drug Type, Stage, and Geography filters are universal.
- **Strategic Digest (key findings, Invest/Watch/Avoid)** — Fully auto-generated from data patterns.
- **SalesForecast area charts** — Accept any long-format forecast file regardless of cluster.

---

## 2. Per-Cluster Onboarding Checklist

Work through this list for each new indication cluster before declaring it production-ready.

### 2.1 Data Export (GlobalData)

- [ ] Query GlobalData Drug Search with **all cluster indications joined by OR** in the "Therapy Area / Indication" field.
- [ ] Ensure the export includes all 12 standard sheets: `Basic Drug Information`, `Basic Company Information`, `Marketing Details`, `Review Designation`, `Detailed Drug Description`, `Drug Target Details`, `Regulatory Information`, `Exclusivity Details`, and others.
- [ ] Note the file naming convention: `YYYYMMDD_[ClusterCode].xlsx` (e.g., `28052026_MET-1.xlsx`).

### 2.2 R Pre-Processing (`GD_indicationcluster.R`)

```r
infile       <- "28052026_MET-1.xlsx"
cluster_name <- "MET-1"
```

- [ ] Set `cluster_name` to the cluster code (e.g., `"MET-1"`, `"CV-1"`, `"SEQ-4"`).
- [ ] Run the script. Check the console output confirms the correct number of detected indications.
- [ ] Inspect the output Excel:
  - **Consolidated sheet**: confirm `Highest_Cluster_Stage` is correctly populated for known marketed drugs in that cluster.
  - **Per_Indication sheet**: confirm no indication is missing (compare count against GlobalData query).
  - **Launch Date / Approval Date columns**: spot-check 2–3 known approved drugs for correct dates.

### 2.3 Dashboard Loading

- [ ] Drop the cluster Excel (raw GlobalData OR processed R output) into `Indication_Cluster_vX.XX.html`.
- [ ] Verify KPI strip reflects the correct cluster name and plausible drug counts.
- [ ] Apply **Innovator** filter in Drug Type — mandatory for large clusters (MET-1, CV-1) where generics dominate volume.
- [ ] Check Indication Landscape cards match the expected indication list for the cluster.

### 2.4 Biological Approach Review (most common required change)

The `BIO_RULES` array in the dashboard determines how MoAs are grouped into biological approach categories. It must be reviewed and extended for each new cluster.

**Current coverage (v1.01):**

| Approach | Primary Clusters |
|---|---|
| Incretin / Hormonal | SEQ-1, MET-1, MET-2 |
| Nuclear Receptors | SEQ-1, MET-1, MET-3 |
| FGF / Growth Factors | SEQ-1 |
| Precision RNA / Genetic | SEQ-1 |
| Lipid Metabolism | SEQ-1, MET-3 |
| Fibrosis / ECM | SEQ-1, SEQ-4 |
| Inflammation / Immune | SEQ-1, SEQ-2, SEQ-4 |
| Mitochondria / Stress | SEQ-1, MET-5 |
| Insulin & Analogs | MET-1 |
| SGLT Inhibitors | MET-1, SEQ-4 |
| DPP-4 Inhibitors | MET-1 |
| β-cell / Secretagogues | MET-1 |
| Glucokinase / Glycogen | MET-1 |
| Biguanides / AMPK | MET-1 |

**Action for each new cluster:**
1. Load the cluster file and navigate to the **Biological Approach** tab.
2. Check the proportion falling into "Other" — if >30% are uncategorised, BIO_RULES needs extension.
3. Pull the top 20 uncategorised MoA_abbr values from the Drug Explorer (filter Stage ≠ Disc, uncheck the Biological Approach columns).
4. Add keyword rules for the dominant uncategorised MoAs into `BIO_RULES` in the HTML source.
5. Save as a new version.

**Indicative rules needed per cluster (to be verified on load):**

- **CV-1 (ASCVD):** Lp(a) inhibitors (LPA), PCSK9 inhibitors (already: Lipid Metabolism), cardiac myosin inhibitors, Factor XIa / FXIa, anti-inflammatory (already: Inflammation), base/prime editing targets
- **CV-2 (Heart Failure):** SGLT2 (already: SGLT Inhibitors), nsMRA / finerenone, cardiac myosin (MYH7, MYBPC3), natriuretic peptide system (NPPA, NPPB, NEP)
- **MET-2 (Obesity):** Incretin (already: GLP1R, GIPR), amylin (already: Incretin), myostatin/ActRII, melanocortin (MC4R), cannabinoid receptor (CNR1)
- **SEQ-2 (Diabetic Complications):** VEGF, VEGFR (retinopathy), aldose reductase (AKR1B1), PKC isoforms, AGE/RAGE pathway
- **SEQ-4 (CKD):** SGLT2 (already), endothelin (ETB), complement (C3, C5), TGF-β (already: Fibrosis)

---

## 3. Known Shortcomings — Cluster-Specific

### 3.1 Attrition ≠ Scientific Failure for Mature Clusters

**Problem:** The "Failed / High Attrition" classification uses >55% discontinuation rate with no active Phase III. This correctly identifies scientific dead-ends (e.g., ASK1 inhibitors in MASH) but **misclassifies commercially displaced classes** as failures.

**Affected clusters:** MET-1 (sulfonylureas displaced by GLP1s), MET-2 (older CNS weight-loss agents), CV-1 (fibrates displaced by statins).

**Current mitigation:** None automated — requires analyst judgement when reading the Strategic Digest.

**Potential fix:** Add a `commerciallyDisplaced: true` flag to known drug classes, shown as a distinct badge ("Superseded") rather than "Failed".

### 3.2 Generic Volume Distorts Numbers

**Problem:** Large established clusters (MET-1, CV-1) contain hundreds of generic and biosimilar entries in GlobalData. Without filtering, KPI "Total Pipeline" and attrition metrics reflect the generic landscape, not the innovation pipeline.

**Mitigation:** Always apply **Drug Type = Innovator** filter in the left panel as the default view for established clusters. Consider making Innovator the default-on filter for clusters where generic count >50% of total.

### 3.3 Indication Abbreviation Edge Cases

The `abbrInd()` function extracts the first token from a parenthetical abbreviation — e.g., `"Type 2 Diabetes (T2D)"` → `"T2D"`. Indication names without parentheticals use the full string (truncated to 24 chars).

**Affected clusters:** MET-1 (`"Type 2 Diabetes"` → no abbreviation, shown in full), SEQ-4 (`"IgA Nephropathy"` → no standard abbreviation).

**Fix:** Add a manual abbreviation override map in the `abbrInd()` function for known long-name indications that lack parenthetical abbreviations.

### 3.4 Market Size Tab Requires Cluster-Specific Forecast File

Each cluster needs its own SalesForecast Excel pre-processed via `preprocess_forecast.R`. The Market Size tab shows a placeholder until a file is loaded.

**Current workflow:**
1. Obtain SalesForecast_[ClusterCode].xlsx from GlobalData or internal forecasting.
2. Run `preprocess_forecast.R` with appropriate `infile` setting.
3. Drop the output into the dashboard's left panel or Market Size tab.

### 3.5 Biological Approach Insights Are Text-Only

The insight cards in the Biological Approach tab generate text from rule-based logic (attrition rates, Ph3 counts). They do not cross-reference external literature, clinical trial failures, or mechanism-specific context beyond what GlobalData pipeline data provides.

**Limitation:** For a cluster like CV-1, a statement like "Lp(a) inhibitors — Emerging (3 drugs, 0% attrition)" is accurate but doesn't convey why the space is considered high-priority (genetic validation, ASCVD risk, major outcomes trials expected 2027–28). This contextual layer remains analyst-generated.

---

## 4. Versioning Convention

| Version | Change scope |
|---|---|
| `v1.00` | Baseline — SEQ-1 validated, all tabs functional |
| `v1.01` | BIO_RULES extended for MET-1 / cross-cluster use |
| `v1.XX` | Minor feature additions, bug fixes, chart refinements |
| `v2.00` | Major architectural change (new tab, new data source type, multi-cluster view) |

**File naming:** `Indication_Cluster_vX.XX.html`  
**Saved location:** `08 - Claude / 05 - CMD /`

Each version is a complete, self-contained HTML file. Previous versions are retained for rollback.

---

## 5. Acceptance Criteria for a New Cluster

A cluster is considered dashboard-ready when:

- [ ] Correct indication count detected on file load (verified against GlobalData query)
- [ ] At least one known marketed drug shows `Highest_Cluster_Stage = Marketed`
- [ ] Biological Approach tab: <20% of innovator drugs fall into "Other"
- [ ] MoA heatmap shows ≥5 distinct mechanisms with ≥2 entries each
- [ ] No JS console errors on load
- [ ] Regulatory timeline shows at least one approval/launch event for clusters with approved drugs
- [ ] Indication Landscape cards match the expected cluster definition from IndiBase

---

## 6. Future Development Priorities

| Priority | Feature | Effort |
|---|---|---|
| High | Manual abbreviation overrides for long indication names | Low |
| High | "Commercially displaced" flag for mature drug classes | Medium |
| Medium | Multi-cluster comparison view (e.g., SEQ-1 vs MET-1 side by side) | High |
| Medium | Default Innovator-only filter for clusters with >50% generics | Low |
| Low | Cluster-aware BIO_RULES presets (auto-switch based on detected cluster code) | Medium |
| Low | Integrated IndiBase lookup to auto-validate indication list completeness | Medium |
