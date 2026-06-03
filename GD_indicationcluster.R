# =============================================================================
# GlobalData Indication Cluster Processor
# GD_indicationcluster.R
# =============================================================================
# PURPOSE:
#   Consolidates a GlobalData pipeline export for a defined indication CLUSTER.
#   Automatically reads the queried indications from the Excel file header
#   (row 12), isolates only cluster-relevant rows (dropping adjacent-indication
#   noise), and produces a two-sheet enriched Excel:
#     Sheet 1 "Consolidated"   — one row per Drug ID (highest cluster stage)
#     Sheet 2 "Per_Indication" — one row per Drug ID × cluster indication
#
# HOW TO USE:
#   1. Export from GlobalData with ALL cluster indications in one query
#      (use the OR operator in Drug Search → Therapy Area / Indication)
#   2. Set infile  to that export path
#   3. Set cluster_name to your label (e.g. "SEQ-1") — used in output filename
#   4. Run the whole script (Source button in RStudio)
# =============================================================================

library(readxl)
library(dplyr)
library(stringr)
library(writexl)
library(tidyr)

# -- USER SETTINGS (edit these) -----------------------------------------------

infile       <- "28052026_SEQ-1.xlsx"   # path to GlobalData export
cluster_name <- "SEQ-1"                 # your cluster label (used in filename)
outfile      <- paste0(format(Sys.Date(), "%Y%m%d"), "_", cluster_name, "_cluster.xlsx")

# -- GEOGRAPHY FILTER ---------------------------------------------------------

europe_countries <- c(
  "Albania", "Andorra", "Austria", "Belarus", "Belgium",
  "Bosnia and Herzegovina", "Bulgaria", "Croatia", "Cyprus",
  "Czech Republic", "Denmark", "Estonia", "Finland", "France",
  "Germany", "Greece", "Hungary", "Iceland", "Ireland", "Italy",
  "Kosovo", "Latvia", "Liechtenstein", "Lithuania", "Luxembourg",
  "Malta", "Moldova", "Monaco", "Montenegro", "Netherlands",
  "North Macedonia", "Norway", "Poland", "Portugal", "Romania",
  "Russia", "San Marino", "Serbia", "Slovakia", "Slovenia", "Spain",
  "Sweden", "Switzerland", "Turkey", "Ukraine", "United Kingdom",
  "Vatican City"
)

geo_inclusion_terms <- c(
  "Global", "United States", "EU", "Japan", "China", "South Korea",
  europe_countries
)

# =============================================================================
# HELPER FUNCTIONS  (identical to globaldata_pipeline.R)
# =============================================================================

collapse_u <- function(x, sep = ", ") {
  x <- str_squish(as.character(x))
  x <- x[!is.na(x) & x != "" & x != "NA"]
  if (!length(x)) NA_character_ else paste(unique(x), collapse = sep)
}

to_chr_id <- function(df) {
  if ("Drug Id" %in% names(df))
    df <- df %>% mutate(`Drug Id` = as.character(`Drug Id`))
  df
}

filter_geo <- function(df) {
  # Accept "Drug Geography" (Basic sheet) or "Country" (Regulatory/Exclusivity sheets)
  geo_col <- if ("Drug Geography" %in% names(df)) "Drug Geography"
             else if ("Country" %in% names(df))   "Country"
             else return(df)   # no geography column → pass through unfiltered
  geo_lower <- str_to_lower(str_squish(as.character(df[[geo_col]])))
  terms     <- str_to_lower(geo_inclusion_terms)
  keep      <- vapply(geo_lower, function(g) any(str_detect(g, fixed(terms))), logical(1))
  df[keep, , drop = FALSE]
}

find_skip <- function(path, sheet) {
  for (s in 0:25) {
    test <- tryCatch(
      suppressMessages(read_excel(path, sheet = sheet, skip = s, n_max = 1)),
      error = function(e) NULL
    )
    if (!is.null(test) && "Drug Id" %in% names(test)) return(s)
  }
  return(16L)
}

read_sheet <- function(path, sheet) {
  skip_n <- find_skip(path, sheet)
  df <- suppressMessages(
    read_excel(path, sheet = sheet, skip = skip_n, guess_max = 5000)
  )
  nm <- gsub(" ", " ", names(df), fixed = TRUE)
  names(df) <- str_squish(nm)
  if (length(names(df)) > 0 && names(df)[1] == "...1") df <- df[, -1, drop = FALSE]
  if ("Drug Id" %in% names(df)) {
    valid <- !is.na(df[["Drug Id"]]) & nchar(as.character(df[["Drug Id"]])) > 0
    df <- df[valid, , drop = FALSE]
  }
  df %>%
    mutate(across(where(is.character), str_squish)) %>%
    to_chr_id() %>%
    filter_geo()
}

# Three-layer robust match:
#   1. str_squish() both sides  → kills leading/trailing/internal whitespace
#   2. str_to_lower() both sides → case-insensitive
#   3. semicolon-split data side → handles multi-indication cells
ind_matches <- function(indication_col, query) {
  query_l <- str_to_lower(str_squish(query))
  vapply(
    str_split(str_to_lower(str_squish(as.character(indication_col))), ";"),
    function(parts) query_l %in% str_squish(parts),
    logical(1)
  )
}

# =============================================================================
# CLUSTER-SPECIFIC HELPERS
# =============================================================================

# --------------------------------------------------------------------------
# parse_queried_indications()
#   Reads the "Therapy Area/ Indication:" cell from the GlobalData Excel header
#   and returns a clean character vector of indication strings.
#
#   Robustness:
#   - n_max = 50: handles variable-length headers regardless of query size
#   - Scans EVERY cell (row × col) for the label — label can appear in any
#     column (GlobalData places it in col 3 of the export, not col 1 or 2)
#   - Reads the value from the NEXT non-empty cell to the right in the same row
#   - Splits on " OR " case-insensitively
#   - Strips the trailing "(TherapyArea)" suffix GlobalData appends
#   - str_squish() on every part
# --------------------------------------------------------------------------
parse_queried_indications <- function(path,
                                      sheet = "Basic Drug Information") {
  raw <- suppressMessages(
    read_excel(path, sheet = sheet, col_names = FALSE, n_max = 50)
  )

  # Scan every cell for the "Therapy Area / Indication" label
  ta_row <- NA_integer_
  ta_col <- NA_integer_

  for (i in seq_len(nrow(raw))) {
    for (j in seq_len(ncol(raw))) {
      cell <- suppressWarnings(as.character(raw[[j]][i]))
      if (!is.na(cell) &&
          grepl("Therapy\\s+Area.*Indication", cell, ignore.case = TRUE)) {
        ta_row <- i
        ta_col <- j
        break
      }
    }
    if (!is.na(ta_row)) break
  }

  if (is.na(ta_row)) {
    warning("Could not find 'Therapy Area/ Indication:' cell in header. ",
            "Returning empty vector — check your Excel file.")
    return(character(0))
  }

  # Value is in the next non-empty cell to the right in the same row
  query_str <- NA_character_
  for (k in (ta_col + 1):min(ta_col + 5, ncol(raw))) {
    candidate <- suppressWarnings(as.character(raw[[k]][ta_row]))
    if (!is.na(candidate) && nzchar(str_squish(candidate))) {
      query_str <- candidate
      break
    }
  }

  if (is.na(query_str) || !nzchar(str_squish(query_str))) {
    warning("Therapy Area/ Indication value cell is empty or not found.")
    return(character(0))
  }

  # Split on uppercase OR only — case-sensitive is intentional.
  # GlobalData uses uppercase " OR " as the indication separator, but lowercase
  # " or " inside abbreviation parentheticals like "(MASH or NASH)".
  # Using (?i) would split "(MASH or NASH)" into "(MASH" and "NASH)".
  parts <- str_squish(
    unlist(strsplit(query_str, "\\s+OR\\s+", perl = TRUE))
  )

  # Strip trailing "(TherapyArea)" — the LAST parenthetical group.
  # Disease abbreviations like "(MASH or NASH)" are never last in GD exports;
  # the therapy area suffix always is.
  parts <- str_squish(
    gsub("\\s*\\([^)]*\\)\\s*$", "", parts, perl = TRUE)
  )

  parts <- parts[nzchar(parts)]
  message("  Detected ", length(parts), " queried indication(s):")
  for (p in parts) message("    - ", p)
  parts
}

# --------------------------------------------------------------------------
# abbr_indication()
#   Produces a short display label from a full GlobalData indication string.
#   Strategy: extract the first token from the FIRST parenthetical group
#   (e.g. "(MASH or NASH)" → "MASH").  Falls back to the full string (trimmed)
#   when no parenthetical is present (e.g. "Liver Cirrhosis").
# --------------------------------------------------------------------------
abbr_indication <- function(s) {
  vapply(s, function(x) {
    m <- regmatches(x, regexpr("\\(([^)]+)\\)", x))
    if (length(m) && nzchar(m)) {
      # Take first token before whitespace or "or"
      inner  <- gsub("[()]", "", m[[1]])
      tokens <- str_squish(
        unlist(strsplit(inner, "\\s+or\\s+|\\s*,\\s*", perl = TRUE))
      )
      tokens <- tokens[nzchar(tokens)]
      if (length(tokens)) return(tokens[[1]])
    }
    str_squish(x)   # fallback: full string
  }, character(1), USE.NAMES = FALSE)
}

# --------------------------------------------------------------------------
# parse_dates_col()
#   Robustly parses a character/mixed vector of GlobalData date cells into
#   R Date objects.  Handles Excel-serial numbers, ISO "YYYY-MM-DD", and the
#   GlobalData house format "DD-Mon-YYYY" (e.g. "01-Mar-2024").
# --------------------------------------------------------------------------
parse_dates_col <- function(x) {
  as.Date(sapply(x, function(v) {
    if (is.na(v)) return(NA_character_)
    # Already a Date or POSIXct from readxl
    if (inherits(v, c("Date", "POSIXct", "POSIXlt")))
      return(format(as.Date(v), "%Y-%m-%d"))
    # Excel serial number stored as numeric
    n <- suppressWarnings(as.numeric(v))
    if (!is.na(n) && n > 1000)
      return(format(as.Date(n, origin = "1899-12-30"), "%Y-%m-%d"))
    # Character parsing
    s <- str_squish(as.character(v))
    if (!nzchar(s) || s == "NA") return(NA_character_)
    for (fmt in c("%d-%b-%Y", "%d %b %Y", "%Y-%m-%d",
                  "%m/%d/%Y", "%d/%m/%Y", "%B %d, %Y")) {
      d <- suppressWarnings(as.Date(s, format = fmt))
      if (!is.na(d)) return(format(d, "%Y-%m-%d"))
    }
    NA_character_
  }, USE.NAMES = FALSE), format = "%Y-%m-%d")
}

# --------------------------------------------------------------------------
# build_regulatory_cols()
#   Appends five new columns to the Consolidated data frame.  Each column
#   covers ALL queried indications in the cluster, with values labelled by
#   abbreviated indication name and separated by "; ".
#
#   Column schema (one column each, works for any cluster / any indication set):
#
#     "Launch Date"         → "MASH: 2024-03-15; MASLD: 2023-11-20"
#     "Approval Date"       → "MASH: 2024-03-15; Liver Cirrhosis: 2021-07-08"
#     "Regulatory RoA"      → "MASH: Oral; MASLD: Subcutaneous"
#     "Regulatory regimen"  → "MASH: Once daily; MASLD: Once weekly"
#     "Exclusivity Date"    → "MASH (ODE): 2029-03-15; MASH (NCE): 2027-05-20"
#
#   Date priority: among all geo-filtered entries for a Drug ID × Indication
#   pair the EARLIEST date is used (min across countries / geographies).
# --------------------------------------------------------------------------
build_regulatory_cols <- function(consolidated, reg, mkt, excl,
                                   queried_inds, cluster_drug_ids) {

  drug_ids <- as.character(consolidated[["Drug Id"]])
  has_ind  <- function(df) "Indication" %in% names(df)

  # Helper: filter a sheet to cluster drugs, optionally by indication
  filter_qi <- function(df, qi) {
    out <- df %>% filter(`Drug Id` %in% cluster_drug_ids)
    if (has_ind(df)) out <- out %>% filter(ind_matches(`Indication`, qi))
    out
  }

  # Helper: for each indication, compute a named vector drug_id -> scalar value,
  # then collapse all non-NA entries across indications as "Abbr: value; Abbr: value"
  collapse_across_inds <- function(per_ind_list) {
    # per_ind_list: named list  abbr -> named character vector (drug_id -> value)
    if (length(per_ind_list) == 0) return(rep(NA_character_, length(drug_ids)))
    vapply(drug_ids, function(did) {
      parts <- vapply(names(per_ind_list), function(abbr) {
        v <- per_ind_list[[abbr]][did]
        if (is.null(v) || is.na(v) || !nzchar(v)) return("")
        paste0(abbr, ": ", v)
      }, character(1))
      parts <- parts[nzchar(parts)]
      if (!length(parts)) return(NA_character_)
      paste(parts, collapse = "; ")
    }, character(1), USE.NAMES = FALSE)
  }

  # ── Per-indication lookups ─────────────────────────────────────────────────
  ld_list   <- list()   # Launch Date
  ad_list   <- list()   # Approval Date
  roa_list  <- list()   # Regulatory RoA
  rgm_list  <- list()   # Regulatory regimen
  excl_list <- list()   # Exclusivity (code-annotated)

  for (qi in queried_inds) {
    abbr   <- abbr_indication(qi)
    reg_qi <- filter_qi(reg, qi)

    if (nrow(reg_qi) > 0) {

      # Launch Date — earliest across geo-filtered geographies
      if ("Launch Date" %in% names(reg_qi)) {
        ld <- reg_qi %>%
          mutate(.d = parse_dates_col(`Launch Date`)) %>%
          filter(!is.na(.d)) %>%
          group_by(`Drug Id`) %>%
          summarise(val = as.character(min(.d)), .groups = "drop")
        ld_list[[abbr]] <- setNames(ld$val, ld$`Drug Id`)
      }

      # Approval Date — column name varies across GlobalData exports
      appr_col <- grep("Approval Date", names(reg_qi), value = TRUE,
                       ignore.case = TRUE)[1]
      if (!is.na(appr_col)) {
        ad <- reg_qi %>%
          mutate(.d = parse_dates_col(.data[[appr_col]])) %>%
          filter(!is.na(.d)) %>%
          group_by(`Drug Id`) %>%
          summarise(val = as.character(min(.d)), .groups = "drop")
        ad_list[[abbr]] <- setNames(ad$val, ad$`Drug Id`)
      }

      # Regulatory RoA
      if ("Route of Admin" %in% names(reg_qi)) {
        roa <- reg_qi %>%
          group_by(`Drug Id`) %>%
          summarise(val = collapse_u(`Route of Admin`), .groups = "drop") %>%
          filter(!is.na(val), nzchar(val))
        roa_list[[abbr]] <- setNames(roa$val, roa$`Drug Id`)
      }
    }

    # Regulatory regimen — from Marketing Details
    if ("Dosage Frequency" %in% names(mkt)) {
      mkt_qi <- filter_qi(mkt, qi)
      if (nrow(mkt_qi) > 0) {
        rgm <- mkt_qi %>%
          group_by(`Drug Id`) %>%
          summarise(val = collapse_u(`Dosage Frequency`), .groups = "drop") %>%
          filter(!is.na(val), nzchar(val))
        rgm_list[[abbr]] <- setNames(rgm$val, rgm$`Drug Id`)
      }
    }

    # Exclusivity — collapse all codes per drug as "Code: date, Code: date"
    if (!is.null(excl) && nrow(excl) > 0 &&
        "Exclusivity Expiration" %in% names(excl) &&
        "Exclusivity Code" %in% names(excl)) {
      excl_qi <- filter_qi(excl, qi) %>%
        mutate(
          .exp  = parse_dates_col(`Exclusivity Expiration`),
          .code = str_squish(as.character(`Exclusivity Code`))
        ) %>%
        filter(!is.na(.exp), nzchar(.code), .code != "NA")

      if (nrow(excl_qi) > 0) {
        excl_coll <- excl_qi %>%
          group_by(`Drug Id`, .code) %>%
          summarise(.d = min(.exp), .groups = "drop") %>%
          arrange(`Drug Id`, .code) %>%
          group_by(`Drug Id`) %>%
          summarise(
            # Format: "ODE: 2029-03-15, NCE: 2027-05-20"
            val = paste0(.code, ": ", as.character(.d), collapse = ", "),
            .groups = "drop"
          )
        excl_list[[abbr]] <- setNames(excl_coll$val, excl_coll$`Drug Id`)
      }
    }
  }

  # ── Assemble into single columns ──────────────────────────────────────────
  result <- consolidated

  if (length(ld_list)   > 0)
    result[["Launch Date"]]        <- collapse_across_inds(ld_list)
  if (length(ad_list)   > 0)
    result[["Approval Date"]]      <- collapse_across_inds(ad_list)
  if (length(roa_list)  > 0)
    result[["Regulatory RoA"]]     <- collapse_across_inds(roa_list)
  if (length(rgm_list)  > 0)
    result[["Regulatory regimen"]] <- collapse_across_inds(rgm_list)
  if (length(excl_list) > 0) {
    # Exclusivity needs indication label in brackets around the code string
    # e.g. "MASH (ODE: 2029-03-15, NCE: 2027-05-20); MASLD (NCE: 2027-05-20)"
    excl_col <- vapply(drug_ids, function(did) {
      parts <- vapply(names(excl_list), function(abbr) {
        v <- excl_list[[abbr]][did]
        if (is.null(v) || is.na(v) || !nzchar(v)) return("")
        paste0(abbr, " (", v, ")")
      }, character(1))
      parts <- parts[nzchar(parts)]
      if (!length(parts)) return(NA_character_)
      paste(parts, collapse = "; ")
    }, character(1), USE.NAMES = FALSE)
    result[["Exclusivity Date"]] <- excl_col
  }

  result
}

# --------------------------------------------------------------------------
# Stage helpers (same buckets as globaldata_pipeline.R)
# --------------------------------------------------------------------------
stage_levels <- c(
  "Discontinued / Inactive", "PreC", "Phase I",
  "Phase II", "Phase III", "Pre-R", "Marketed"
)

remap_stage <- function(x) {
  xl <- str_to_lower(str_squish(coalesce(as.character(x), "")))
  dplyr::case_when(
    xl %in% c("inactive", "withdrawn", "discontinued",
              "withdrawn (marketed)", "archived", "unknown",
              "filing rejected/withdrawn", "phase 0") ~ "Discontinued",
    xl %in% c("preclinical", "discovery", "ind/cta filed") ~ "PreC",
    xl == "phase i"                                        ~ "Phase I",
    xl == "phase ii"                                       ~ "Phase II",
    xl == "phase iii"                                      ~ "Phase III",
    xl %in% c("pre-registration", "preregistration",
              "pre registration")                          ~ "Pre-registration",
    xl == "marketed"                                       ~ "Marketed",
    TRUE                                                   ~ as.character(x)
  )
}

stage_rank_val <- function(stage) {
  dplyr::case_when(
    stage == "Marketed"         ~ 99L,
    stage == "Pre-registration" ~ 98L,
    stage == "Phase III"        ~ 97L,
    stage == "Phase II"         ~ 96L,
    stage == "Phase I"          ~ 95L,
    stage == "PreC"             ~ 94L,
    stage == "Discontinued"     ~ 1L,
    TRUE                        ~ NA_integer_
  )
}

# Short stage label for Indication_Stages column: "Ph2", "PreC", "Mkt" etc.
short_stage <- function(stage) {
  dplyr::case_when(
    stage == "Marketed"         ~ "Mkt",
    stage == "Pre-registration" ~ "Pre-R",
    stage == "Phase III"        ~ "Ph3",
    stage == "Phase II"         ~ "Ph2",
    stage == "Phase I"          ~ "Ph1",
    stage == "PreC"             ~ "PreC",
    stage == "Discontinued"     ~ "Disc",
    TRUE                        ~ stage
  )
}

# =============================================================================
# CORE ENRICHMENT  (adapted from process_indication() in globaldata_pipeline.R)
# Processes ONE indication at a time across the pre-filtered drug universe.
# =============================================================================
process_indication <- function(basic, comp, mkt, rev, desc, tgt_dt, reg,
                                query_ind, drug_universe_ids) {

  if (!("Inactive/Discontinued Date" %in% names(basic)))
    basic[["Inactive/Discontinued Date"]] <- NA_character_
  if (!("Reason for Discontinuation" %in% names(basic)))
    basic[["Reason for Discontinuation"]] <- NA_character_

  base <- basic %>%
    filter(ind_matches(`Indication`, query_ind),
           `Drug Id` %in% drug_universe_ids) %>%
    group_by(`Drug Id`) %>%
    summarise(
      `Drug Name`    = first(na.omit(`Drug Name`)),
      `Generic Name` = first(na.omit(`Generic Name`)),
      `Brand Name`   = collapse_u(`Brand Name`),
      `Company Name` = collapse_u(`Company Name`),
      `Therapy Area` = first(na.omit(`Therapy Area`)),
      `Indication`   = query_ind,
      `Development Stage` = first(na.omit(`Development Stage`)),
      `Highest development stage` = first(na.omit(`Highest Development Stage`)),
      `Alias Name`  = collapse_u(`Alias Name`),
      `RoA`         = collapse_u(`Route of Administration`),
      `Target` = {
        t <- str_squish(as.character(`Target`))
        t <- t[!is.na(t) & t != "" & t != "NA"]
        t <- unique(str_squish(unlist(strsplit(paste(t, collapse = ";"), ";"))))
        if (!length(t)) NA_character_ else paste(t, collapse = "; ")
      },
      `MoA`        = collapse_u(`Mechanism of Action`),
      `Modality`   = collapse_u(`Molecule Type`),
      `Drug Type`  = first(na.omit(`Drug Type`)),
      `Mono/Combo` = first(na.omit(`Mono/Combination Drug`)),
      `First-In-Class` = first(na.omit(`First-In-Class`)),
      `Inactive/Discontinued Date` = first(na.omit(`Inactive/Discontinued Date`)),
      `Reason for Discontinuation` = first(na.omit(`Reason for Discontinuation`)),
      .groups = "drop"
    )

  if (nrow(base) == 0) return(NULL)
  du <- base %>% distinct(`Drug Id`)

  # Headquarters
  hq <- comp %>%
    mutate(
      rel      = str_squish(as.character(`Independent/Parent/Subsidiary/Joint Venture`)),
      rel_l    = str_to_lower(rel),
      hq       = str_squish(as.character(`Headquarters`)),
      rel_rank = case_when(
        rel_l == "parent"      ~ 1L,
        rel_l == "independent" ~ 2L,
        TRUE                   ~ 3L
      )
    ) %>%
    filter(!is.na(`Drug Id`), `Drug Id` != "",
           !is.na(`Company Name`), `Company Name` != "",
           !is.na(hq), hq != "") %>%
    group_by(`Drug Id`, `Company Name`, rel_rank, rel) %>%
    summarise(hq_collapsed = collapse_u(hq), .groups = "drop") %>%
    arrange(`Drug Id`, `Company Name`, rel_rank) %>%
    group_by(`Drug Id`, `Company Name`) %>% slice(1) %>% ungroup() %>%
    transmute(`Drug Id`, `Company Name`,
              `Headquarters` = hq_collapsed,
              `Parent or Subsidiary` = rel)

  reg_roa <- reg %>%
    group_by(`Drug Id`) %>%
    summarise(`Regulatory RoA` = collapse_u(`Route of Admin`), .groups = "drop") %>%
    right_join(du, by = "Drug Id")

  dosing <- mkt %>%
    group_by(`Drug Id`) %>%
    summarise(`Dosing` = collapse_u(`Dosage Frequency`), .groups = "drop") %>%
    right_join(du, by = "Drug Id")

  designation <- rev %>%
    filter(ind_matches(`Indication`, query_ind)) %>%
    group_by(`Drug Id`) %>%
    summarise(`Designation` = collapse_u(`Designation Type`), .groups = "drop") %>%
    right_join(du, by = "Drug Id") %>%
    mutate(`Designation` = if_else(is.na(`Designation`) | `Designation` == "",
                                   "None", `Designation`)) %>%
    select(`Drug Id`, `Designation`)

  descriptions <- desc %>%
    filter(ind_matches(`Indication`, query_ind)) %>%
    group_by(`Drug Id`) %>%
    summarise(
      `Drug Description` = collapse_u(`Drug Description`,                sep = " | "),
      `MoA Description`  = collapse_u(`Mechanism of Action Description`, sep = " | "),
      `Safety Details`   = collapse_u(`Safety Details`,                  sep = " | "),
      `Efficacy Details` = collapse_u(`Efficacy Details`,                sep = " | "),
      .groups = "drop"
    ) %>%
    right_join(du, by = "Drug Id")

  base %>%
    mutate(`Company Name` = str_squish(as.character(`Company Name`))) %>%
    left_join(hq,          by = c("Drug Id", "Company Name")) %>%
    left_join(reg_roa,     by = "Drug Id") %>%
    left_join(dosing,      by = "Drug Id") %>%
    left_join(designation, by = "Drug Id") %>%
    left_join(descriptions,by = "Drug Id") %>%
    select(any_of(c(
      "Drug Id", "Drug Name", "Generic Name", "Brand Name", "Company Name",
      "Headquarters", "Parent or Subsidiary", "Therapy Area", "Indication",
      "Development Stage", "Highest development stage",
      "Inactive/Discontinued Date", "Reason for Discontinuation",
      "Alias Name", "RoA", "Regulatory RoA", "Target", "MoA",
      "Modality", "Drug Type", "Mono/Combo", "First-In-Class", "Dosing",
      "Designation", "Drug Description", "MoA Description",
      "Safety Details", "Efficacy Details"
    ))) %>%
    arrange(`Drug Name`, `Drug Id`)
}

# =============================================================================
# POST-PROCESSING  (MoA_abbr, Target_abbr, Modality_C — same as pipeline.R)
# =============================================================================
enrich_columns <- function(df, global_target_map) {

  # Remap Development Stage
  df <- df %>%
    mutate(`Development Stage` = remap_stage(`Development Stage`))

  # Fill undisclosed
  df <- df %>%
    mutate(
      RoA      = if_else(is.na(RoA)      | str_squish(RoA)      == "", "undisclosed", RoA),
      MoA      = if_else(is.na(MoA)      | str_squish(MoA)      == "", "undisclosed", MoA),
      Modality = if_else(is.na(Modality) | str_squish(Modality) == "", "undisclosed", Modality),
      Target   = if_else(is.na(Target)   | str_squish(Target)   == "", "undisclosed", Target)
    )

  # Modality_C
  df <- df %>%
    mutate(
      Modality_C = {
        m <- str_squish(coalesce(Modality, ""))
        dplyr::case_when(
          m == "undisclosed"                                                    ~ "undisclosed",
          m == "Small Molecule"                                                 ~ "SMOLs",
          m %in% c("Synthetic Protein", "Synthetic Peptide", "Recombinant Protein",
                   "Recombinant Peptide", "Recombinant Enzyme",
                   "Recombinant Peptide; Recombinant Protein",
                   "Protein", "Polysaccharide", "Peptide",
                   "Fusion Protein", "Enzyme")                                  ~ "Protein / Peptides",
          m %in% c("Antibody", "Monoclonal antibody", "Monoclonal Antibody",
                   "Monoclonal Antibody; Synthetic Peptide",
                   "Single-Domain Antibody (sdAb)")                            ~ "Antibodies",
          m %in% c("Antibody Drug Conjugate (ADC)",
                   "Small Molecule Drug Conjugate", "Polymer")                 ~ "Drug Conjugates",
          m == "Biologic"                                                       ~ "Other Biologics",
          m %in% c("Antisense Oligonucleotide", "Oligonucleotide",
                   "Antisense RNAi Oligonucleotide", "Aptamer", "siRNA")       ~ "Oligonucleotides",
          m == "mRNA"                                                           ~ "mRNA",
          m == "Cell Therapy"                                                   ~ "Cell Therapy",
          m %in% c("Gene Therapy", "Gene-Modified Cell Therapy")               ~ "Gene Therapy",
          m == "Recombinant Vector Vaccine"                                     ~ "Vector Vaccine",
          TRUE                                                                  ~ "QC: uncounted"
        )
      }
    )

  # Target_abbr & MoA_abbr
  make_target_abbr <- function(target_str, lkp) {
    if (is.na(target_str) || target_str == "undisclosed") return(target_str)
    parts <- str_squish(strsplit(target_str, ";")[[1]])
    parts <- parts[parts != ""]
    result <- vapply(parts, function(p) {
      idx <- which(str_to_lower(lkp$target_name) == str_to_lower(p))
      if (length(idx)) lkp$gene_abbr[idx[1]] else p
    }, character(1))
    paste(result, collapse = "; ")
  }

  make_moa_abbr <- function(moa_str, lkp) {
    if (is.na(moa_str) || moa_str == "undisclosed") return(moa_str)
    parts <- str_squish(strsplit(moa_str, ";")[[1]])
    parts <- parts[parts != ""]
    result <- vapply(parts, function(p) {
      p_l <- str_to_lower(p)
      for (i in seq_len(nrow(lkp))) {
        tname_l <- str_to_lower(lkp$target_name[i])
        if (startsWith(p_l, tname_l)) {
          suffix <- str_squish(substr(p, nchar(lkp$target_name[i]) + 1L, nchar(p)))
          return(if (nchar(suffix) > 0L)
            paste0(lkp$gene_abbr[i], " ", str_to_lower(suffix))
          else lkp$gene_abbr[i])
        }
      }
      p
    }, character(1))
    paste(result, collapse = "; ")
  }

  df <- df %>%
    mutate(
      Target_abbr = vapply(Target, make_target_abbr, character(1), lkp = global_target_map),
      MoA_abbr    = vapply(MoA,    make_moa_abbr,    character(1), lkp = global_target_map)
    )

  # Top-15 MoA_C / Target_C (innovator only)
  innovator_rows <- df %>%
    filter(str_detect(str_to_lower(coalesce(`Drug Type`, "")), "innovator"))

  top15_targets <- innovator_rows %>%
    filter(!is.na(Target_abbr), Target_abbr != "undisclosed") %>%
    count(Target_abbr, sort = TRUE) %>% slice_head(n = 15) %>% pull(Target_abbr)

  top15_moas <- innovator_rows %>%
    filter(!is.na(MoA_abbr), MoA_abbr != "undisclosed") %>%
    count(MoA_abbr, sort = TRUE) %>% slice_head(n = 15) %>% pull(MoA_abbr)

  df <- df %>%
    mutate(
      Target_C = if_else(Target_abbr %in% top15_targets, Target_abbr, "Others"),
      MoA_C    = if_else(MoA_abbr    %in% top15_moas,    MoA_abbr,    "Others")
    )

  # Dev.Stage_rank
  df <- df %>%
    mutate(Dev.Stage_rank = stage_rank_val(`Development Stage`))

  # Rank columns
  target_c_ranks   <- df %>% filter(Target_C != "Others") %>%
    count(Target_C, sort = TRUE) %>% mutate(Target_c_rank = row_number()) %>%
    select(Target_C, Target_c_rank)
  moa_c_ranks      <- df %>% filter(MoA_C != "Others") %>%
    count(MoA_C, sort = TRUE) %>% mutate(MoA_c_rank = row_number()) %>%
    select(MoA_C, MoA_c_rank)
  modality_c_ranks <- df %>% filter(Modality_C != "undisclosed") %>%
    count(Modality_C, sort = TRUE) %>% mutate(Modality_c_rank = row_number()) %>%
    select(Modality_C, Modality_c_rank)

  df %>%
    left_join(target_c_ranks,   by = "Target_C") %>%
    left_join(moa_c_ranks,      by = "MoA_C") %>%
    left_join(modality_c_ranks, by = "Modality_C") %>%
    mutate(
      Target_c_rank   = if_else(Target_C   == "Others",      99L, Target_c_rank),
      MoA_c_rank      = if_else(MoA_C      == "Others",      99L, MoA_c_rank),
      Modality_c_rank = if_else(Modality_C == "undisclosed", 99L, Modality_c_rank)
    ) %>%
    relocate(`Gene Name`, Target_abbr, Target_C, Target_c_rank, .after = `Target`) %>%
    relocate(MoA_abbr, MoA_C, MoA_c_rank,                      .after = `MoA`) %>%
    relocate(Modality_C, Modality_c_rank,                       .after = Modality)
}

# =============================================================================
# MAIN
# =============================================================================

message("\n=== GD_indicationcluster.R ===")
message("File        : ", infile)
message("Cluster     : ", cluster_name)
message("Output      : ", outfile)

# -- 1. Detect queried indications from file header ---------------------------
message("\n-- Step 1: Detecting queried indications from header...")
queried_inds <- parse_queried_indications(infile)
if (!length(queried_inds)) stop("No queried indications found. Aborting.")

# -- 2. Read all sheets -------------------------------------------------------
message("\n-- Step 2: Reading sheets...")
basic  <- read_sheet(infile, "Basic Drug Information")
comp   <- read_sheet(infile, "Basic Company Information")
mkt    <- read_sheet(infile, "Marketing Details")
rev    <- read_sheet(infile, "Review Designation")
desc   <- read_sheet(infile, "Detailed Drug Description")
tgt_dt <- read_sheet(infile, "Drug Target Details")
reg    <- read_sheet(infile, "Regulatory Information")

# Exclusivity Details (optional — silently skipped if absent from this export)
excl <- tryCatch(
  read_sheet(infile, "Exclusivity Details"),
  error = function(e) { message("  Exclusivity Details sheet not found — skipping."); NULL }
)

message("  Basic Drug Information: ", nrow(basic), " rows after geo filter")
if (!is.null(excl)) message("  Exclusivity Details: ", nrow(excl), " rows after geo filter")

# -- 3. Isolate cluster-relevant Drug IDs ------------------------------------
message("\n-- Step 3: Isolating cluster-relevant Drug IDs...")

# Keep only rows where Indication matches one of the queried indications
cluster_basic <- basic %>%
  filter(Reduce(`|`, lapply(queried_inds, function(qi) ind_matches(`Indication`, qi))))

cluster_drug_ids <- unique(cluster_basic[["Drug Id"]])
message("  ", nrow(cluster_basic), " rows match cluster indications")
message("  ", length(cluster_drug_ids), " unique Drug IDs in cluster")

# -- 4. Build global target → gene abbreviation map --------------------------
message("\n-- Step 4: Building target → gene abbreviation map...")
global_target_map <- tgt_dt %>%
  transmute(
    target_name = str_squish(as.character(`Official Target Name`)),
    gene_names  = str_squish(as.character(`Gene Names`))
  ) %>%
  filter(!is.na(target_name), target_name != "", target_name != "NA") %>%
  mutate(
    gene_abbr = vapply(
      strsplit(gene_names, "[,;]"),
      function(v) {
        v <- str_squish(v)
        v <- v[!is.na(v) & v != "" & v != "NA"]
        if (!length(v)) NA_character_ else v[[1]]
      },
      character(1)
    )
  ) %>%
  filter(!is.na(gene_abbr), gene_abbr != "") %>%
  distinct(target_name, .keep_all = TRUE) %>%
  arrange(desc(nchar(target_name)))

# Also build gene_by_drug lookup
gene_long_all <- cluster_basic %>%
  select(`Drug Id`, `Target`) %>%
  mutate(
    Target = if_else(is.na(Target) | str_squish(Target) == "", NA_character_, Target)
  ) %>%
  filter(!is.na(Target)) %>%
  mutate(target_list = strsplit(str_squish(as.character(Target)), ";")) %>%
  unnest_longer(target_list, values_to = "target_item") %>%
  mutate(target_item = str_squish(as.character(target_item))) %>%
  filter(!is.na(target_item), target_item != "") %>%
  left_join(
    global_target_map %>% rename(target_item = target_name),
    by = "target_item"
  ) %>%
  group_by(`Drug Id`) %>%
  summarise(
    `Gene Name` = {
      gn <- gene_abbr
      gn <- gn[!is.na(gn) & gn != ""]
      if (!length(gn)) NA_character_ else paste(unique(gn), collapse = "; ")
    },
    .groups = "drop"
  )

# -- 5. Build Per_Indication sheet --------------------------------------------
message("\n-- Step 5: Building Per_Indication sheet...")
per_ind_list <- list()

for (qi in queried_inds) {
  message("  Processing indication: ", qi)
  res <- process_indication(basic, comp, mkt, rev, desc, tgt_dt, reg,
                             qi, cluster_drug_ids)
  if (!is.null(res) && nrow(res) > 0) {
    per_ind_list[[length(per_ind_list) + 1]] <- res
  }
}

if (!length(per_ind_list)) stop("No results for any queried indication. Aborting.")

per_ind_raw <- bind_rows(per_ind_list) %>%
  left_join(gene_long_all, by = "Drug Id") %>%
  mutate(`Cluster` = cluster_name)

# Apply full enrichment
per_ind <- enrich_columns(per_ind_raw, global_target_map) %>%
  mutate(Dev.Stage_rank = stage_rank_val(`Development Stage`)) %>%
  relocate(`Cluster`, .before = everything()) %>%
  arrange(`Drug Name`, `Drug Id`, desc(Dev.Stage_rank))

message("  Per_Indication rows: ", nrow(per_ind))

# -- 6. Build Consolidated sheet ----------------------------------------------
message("\n-- Step 6: Building Consolidated sheet...")

# For each Drug ID, find the row with the highest Dev.Stage_rank
best_row <- per_ind %>%
  group_by(`Drug Id`) %>%
  slice_max(Dev.Stage_rank, n = 1, with_ties = FALSE) %>%
  ungroup()

# Count distinct cluster indications per Drug ID
ind_counts <- per_ind %>%
  group_by(`Drug Id`) %>%
  summarise(
    n_cluster_indications = n_distinct(`Indication`),
    .groups = "drop"
  )

# Build "Indication_Stages" string: "MASH (Ph2); MASLD (Ph1)" sorted stage-desc
ind_stages <- per_ind %>%
  mutate(
    ind_abbr   = abbr_indication(`Indication`),
    stage_short = short_stage(`Development Stage`),
    ind_stage_str = paste0(ind_abbr, " (", stage_short, ")")
  ) %>%
  arrange(`Drug Id`, desc(Dev.Stage_rank)) %>%
  group_by(`Drug Id`) %>%
  summarise(
    Indication_Stages = paste(unique(ind_stage_str), collapse = "; "),
    .groups = "drop"
  )

# Geographies for each Drug ID (from geo-filtered basic sheet)
drug_geos <- basic %>%
  filter(`Drug Id` %in% cluster_drug_ids) %>%
  group_by(`Drug Id`) %>%
  summarise(Drug_Geographies = collapse_u(`Drug Geography`), .groups = "drop")

# Join everything onto best_row
consolidated <- best_row %>%
  left_join(ind_counts,  by = "Drug Id") %>%
  left_join(ind_stages,  by = "Drug Id") %>%
  left_join(drug_geos,   by = "Drug Id") %>%
  rename(Highest_Cluster_Stage = `Development Stage`) %>%
  relocate(Highest_Cluster_Stage, Dev.Stage_rank,
           n_cluster_indications, Indication_Stages, Drug_Geographies,
           .after = `Drug Id`) %>%
  arrange(desc(Dev.Stage_rank), `Drug Name`)

message("  Consolidated rows (unique Drug IDs): ", nrow(consolidated))

# -- 6b. Append indication-specific regulatory/commercial columns -------------
message("\n-- Step 6b: Appending regulatory & exclusivity columns per indication...")
consolidated <- build_regulatory_cols(
  consolidated    = consolidated,
  reg             = reg,
  mkt             = mkt,
  excl            = excl,
  queried_inds    = queried_inds,
  cluster_drug_ids= cluster_drug_ids
)
# Report what was added
new_reg_cols <- intersect(
  names(consolidated),
  c("Launch Date", "Approval Date", "Regulatory RoA",
    "Regulatory regimen", "Exclusivity Date")
)
message("  Added ", length(new_reg_cols), " regulatory/exclusivity columns: ",
        paste(new_reg_cols, collapse = ", "))

# -- 7. Generate plots --------------------------------------------------------
message("\n-- Step 7: Generating plots...")

library(ggplot2)
library(showtext)

# Font setup (falls back silently if font files absent)
tryCatch({
  font_add(
    family     = "NovoApplySans",
    regular    = "font/NovoApplySans-Rg.ttf",
    bold       = "font/NovoApplySans-Bd.ttf",
    italic     = "font/NovoApplySans-It.ttf",
    bolditalic = "font/NovoApplySans-BdIt.ttf"
  )
  showtext_auto()
  showtext_opts(dpi = 300)
  plot_font <- "NovoApplySans"
}, error = function(e) {
  message("  NovoApplySans not found — using default font for plots")
  plot_font <<- ""
})

bii_colors <- c(
  teal_dark  = "#00374D", teal   = "#005F78",
  teal_mid   = "#0090AF", teal_light = "#66C4D8",
  green_dark = "#004A44", green  = "#007268",
  green_mid  = "#00A896", orange = "#F08010",
  gray_mid   = "#7A7A7A", gray_light = "#C8C8C8"
)

# y-break helper (unchanged from globaldata_pipeline.R)
maybe_break_y <- function(p, df,
                           stage_col  = "stage_bucket",
                           count_col  = "n",
                           disc_label = "Discontinued / Inactive",
                           ratio = 2) {
  totals    <- df %>% group_by(.data[[stage_col]]) %>%
    summarise(total = sum(.data[[count_col]], na.rm = TRUE), .groups = "drop")
  disc_n    <- totals %>% filter(.data[[stage_col]] == disc_label) %>% pull(total)
  other_max <- totals %>% filter(.data[[stage_col]] != disc_label) %>%
    pull(total) %>% max(na.rm = TRUE)
  if (!length(disc_n) || !length(other_max) || other_max == 0) return(p)
  if (disc_n < ratio * other_max) return(p)
  break_lo <- ceiling(other_max * 1.2)
  break_hi <- floor(disc_n * 0.85)
  if (break_lo >= break_hi) return(p)
  tryCatch(
    p + ggbreak::scale_y_break(c(break_lo, break_hi), scales = "free",
                                ticklabels = NULL),
    error = function(e) p   # ggbreak not installed: skip break silently
  )
}

# Fill scale helper
bii_fill_scale <- function(cats,
                            grey_cats  = c("Others", "undisclosed"),
                            grey_color = unname(bii_colors[["gray_mid"]])) {
  library(unikn)
  pal    <- tryCatch(usecol(pal_unikn_pair, n = 16),
                     error = function(e) scales::hue_pal()(16))
  named  <- sort(setdiff(unique(cats), grey_cats))
  spcl   <- intersect(grey_cats, unique(cats))
  ordered <- c(named, spcl)
  colors  <- c(setNames(pal[seq_len(length(named))], named),
               setNames(rep(grey_color, length(spcl)), spcl))
  scale_fill_manual(values = colors, breaks = ordered, drop = FALSE)
}

# Innovator filter + stage buckets on Consolidated
map_stage_bucket <- function(x) {
  xl <- str_to_lower(str_squish(coalesce(x, "")))
  dplyr::case_when(
    xl %in% c("archived", "discontinued", "withdrawn", "unknown") ~ "Discontinued / Inactive",
    xl %in% c("preclinical", "discovery", "ind/cta filed")        ~ "PreC",
    startsWith(xl, "phase i")  & !startsWith(xl, "phase ii")      ~ "Phase I",
    startsWith(xl, "phase ii") & !startsWith(xl, "phase iii")     ~ "Phase II",
    startsWith(xl, "phase iii")                                    ~ "Phase III",
    xl %in% c("pre-registration", "preregistration", "pre registration", "pre-r") ~ "Pre-R",
    xl == "marketed"                                               ~ "Marketed",
    TRUE                                                           ~ "Discontinued / Inactive"
  )
}

innov <- consolidated %>%
  filter(str_detect(str_to_lower(coalesce(`Drug Type`, "")), "innovator")) %>%
  mutate(stage_bucket  = factor(map_stage_bucket(Highest_Cluster_Stage),
                                 levels = stage_levels),
         modality_bucket = Modality_C)

message("  Innovator drugs in Consolidated: ", nrow(innov))

ind_label <- paste0(cluster_name, " cluster (", length(queried_inds), " indications)")
plot_dir  <- dirname(normalizePath(outfile, mustWork = FALSE))

plot_data <- list()

if (nrow(innov) > 0) {

  # -- Plot 1: Stage counts ---------------------------------------------------
  p1_df <- innov %>%
    count(stage_bucket, name = "n") %>%
    tidyr::complete(stage_bucket = factor(stage_levels, levels = stage_levels),
                    fill = list(n = 0))

  p1 <- ggplot(p1_df, aes(x = stage_bucket, y = n)) +
    geom_col(fill = bii_colors[["teal"]]) +
    geom_text(aes(label = ifelse(n > 0, n, "")),
              vjust = -0.4, size = 3.5, colour = bii_colors[["teal_dark"]],
              family = plot_font) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
    coord_cartesian(clip = "off") +
    labs(title = paste0("Pipeline development: ", ind_label),
         subtitle = "Innovator drugs only | Highest cluster stage",
         x = NULL, y = "Number of drugs") +
    theme_minimal(base_size = 12, base_family = plot_font) +
    theme(axis.text.x = element_text(angle = 40, hjust = 1),
          panel.grid.major.x = element_blank(),
          plot.title = element_text(face = "bold"),
          plot.margin = margin(10, 15, 40, 40, "pt"))
  p1 <- maybe_break_y(p1, p1_df)
  ggsave(file.path(plot_dir, sub("\\.xlsx$", "_plot1_stage.png", basename(outfile))),
         p1, width = 12, height = 6, dpi = 300)
  plot_data[["Plot1 - Stage"]] <- as.data.frame(p1_df) %>%
    rename(Stage = stage_bucket, `Drug Count` = n)
  message("  Plot 1 saved")

  # -- Plot 2: Stage × Modality -----------------------------------------------
  p2_df <- innov %>%
    count(stage_bucket, modality_bucket, name = "n") %>%
    tidyr::complete(stage_bucket    = factor(stage_levels, levels = stage_levels),
                    modality_bucket, fill = list(n = 0))

  p2 <- ggplot(p2_df, aes(x = stage_bucket, y = n, fill = modality_bucket)) +
    geom_col() +
    bii_fill_scale(p2_df$modality_bucket) +
    labs(title = paste0("Pipeline by modality: ", ind_label),
         subtitle = "Innovator drugs only",
         x = NULL, y = "Number of drugs", fill = "Modality") +
    guides(fill = guide_legend(nrow = 2, byrow = TRUE)) +
    coord_cartesian(clip = "off") +
    theme_minimal(base_size = 12, base_family = plot_font) +
    theme(axis.text.x = element_text(angle = 40, hjust = 1),
          panel.grid.major.x = element_blank(),
          plot.title = element_text(face = "bold"),
          legend.position = "bottom",
          plot.margin = margin(10, 15, 40, 40, "pt"))
  p2 <- maybe_break_y(p2, p2_df)
  ggsave(file.path(plot_dir, sub("\\.xlsx$", "_plot2_modality.png", basename(outfile))),
         p2, width = 14, height = 8, dpi = 300)
  plot_data[["Plot2 - Modality"]] <- as.data.frame(p2_df) %>%
    rename(Stage = stage_bucket, Modality = modality_bucket, `Drug Count` = n)
  message("  Plot 2 saved")

  # -- Plot 3: Stage × Target (top 15 genes) ----------------------------------
  gene_long <- innov %>%
    mutate(`Gene Name` = str_squish(coalesce(`Gene Name`, ""))) %>%
    tidyr::separate_rows(`Gene Name`, sep = ";") %>%
    mutate(`Gene Name` = str_squish(`Gene Name`)) %>%
    filter(`Gene Name` != "")

  if (nrow(gene_long) > 0) {
    top15_genes <- gene_long %>% count(`Gene Name`, name = "n") %>%
      arrange(desc(n)) %>% slice_head(n = 15) %>% pull(`Gene Name`)

    p3_df <- gene_long %>%
      mutate(gene_bucket = ifelse(`Gene Name` %in% top15_genes, `Gene Name`, "Others")) %>%
      count(stage_bucket, gene_bucket, name = "n") %>%
      tidyr::complete(stage_bucket = factor(stage_levels, levels = stage_levels),
                      gene_bucket, fill = list(n = 0))

    p3 <- ggplot(p3_df, aes(x = stage_bucket, y = n, fill = gene_bucket)) +
      geom_col() +
      bii_fill_scale(p3_df$gene_bucket) +
      labs(title = paste0("Pipeline by target: ", ind_label),
           subtitle = "Innovator drugs only | Top 15 gene targets",
           x = NULL, y = "Number of drugs", fill = "Gene / Target") +
      guides(fill = guide_legend(nrow = 3, byrow = TRUE)) +
      coord_cartesian(clip = "off") +
      theme_minimal(base_size = 12, base_family = plot_font) +
      theme(axis.text.x = element_text(angle = 40, hjust = 1),
            panel.grid.major.x = element_blank(),
            plot.title = element_text(face = "bold"),
            legend.position = "bottom",
            plot.margin = margin(10, 15, 40, 40, "pt"))
    p3 <- maybe_break_y(p3, p3_df)
    ggsave(file.path(plot_dir, sub("\\.xlsx$", "_plot3_target.png", basename(outfile))),
           p3, width = 14, height = 8, dpi = 300)
    plot_data[["Plot3 - Target"]] <- as.data.frame(p3_df) %>%
      rename(Stage = stage_bucket, `Gene / Target` = gene_bucket, `Drug Count` = n)
    message("  Plot 3 saved")
  }

  # -- Plot 4: Stage × MoA_C --------------------------------------------------
  p4_df <- innov %>%
    filter(!is.na(MoA_C)) %>%
    distinct(`Drug Id`, stage_bucket, MoA_C) %>%
    count(stage_bucket, MoA_C, name = "n") %>%
    tidyr::complete(stage_bucket = factor(stage_levels, levels = stage_levels),
                    MoA_C, fill = list(n = 0))

  p4 <- ggplot(p4_df, aes(x = stage_bucket, y = n, fill = MoA_C)) +
    geom_col() +
    bii_fill_scale(p4_df$MoA_C) +
    labs(title = paste0("Pipeline by MoA: ", ind_label),
         subtitle = "Innovator drugs only | Top 15 MoAs shown",
         x = NULL, y = "Number of unique drugs", fill = "MoA") +
    guides(fill = guide_legend(nrow = 4, byrow = TRUE)) +
    coord_cartesian(clip = "off") +
    theme_minimal(base_size = 12, base_family = plot_font) +
    theme(axis.text.x = element_text(angle = 40, hjust = 1),
          panel.grid.major.x = element_blank(),
          plot.title = element_text(face = "bold"),
          legend.position = "bottom",
          plot.margin = margin(10, 15, 40, 40, "pt"))
  p4 <- maybe_break_y(p4, p4_df)
  ggsave(file.path(plot_dir, sub("\\.xlsx$", "_plot4_moa.png", basename(outfile))),
         p4, width = 14, height = 8, dpi = 300)
  plot_data[["Plot4 - MoA"]] <- as.data.frame(p4_df) %>%
    rename(Stage = stage_bucket, `Drug Count` = n)
  message("  Plot 4 saved")

} else {
  message("  No innovator drugs found — skipping plots.")
}

# -- 8. Write output Excel ----------------------------------------------------
message("\n-- Step 8: Writing output Excel...")

out_sheets <- c(
  list(
    Consolidated   = as.data.frame(consolidated),
    Per_Indication = as.data.frame(per_ind)
  ),
  plot_data
)

write_xlsx(out_sheets, outfile)
message("Done! Written to: ", outfile)
message("  Consolidated rows   : ", nrow(consolidated))
message("  Per_Indication rows : ", nrow(per_ind))
message("  Plot sheets         : ", length(plot_data))
