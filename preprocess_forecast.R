# =============================================================================
# preprocess_forecast.R
# Transposes a GlobalData-style wide SalesForecast Excel into the long (tidy)
# format expected by CMD_cluster_dashboard.html.
#
# Input format (wide — as exported by GlobalData):
#   Rows 1–N:  metadata / empty  (header row detected automatically)
#   Header row contains: Drug Name | Company Name | Indication | Segment | ...
#                        | 2026 (F) | 2027 (F) | ... | 2032 (F) | 2026-2032
#   One row per Drug × Indication × Geography (Global, US, RoW, Europe, China)
#
# Output format (long — dashboard-ready):
#   Drug Name | Company Name | Indication | Geography | Year | Sales (USD M)
#   One row per Drug × Indication × Geography × Year
#   Also writes a "Global Only" sheet filtered to Region == "Global"
#
# HOW TO USE:
#   1. Set infile  to your wide SalesForecast .xlsx path
#   2. Set outfile to the desired output path (or leave as auto-named)
#   3. Source / Run the script
# =============================================================================

library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(writexl)

# ── USER SETTINGS ─────────────────────────────────────────────────────────────

infile  <- "SalesForecast_SEQ-1.xlsx"  # path to the wide GlobalData forecast export
outfile <- paste0(format(Sys.Date(), "%Y%m%d"), "_", sub("\\.xlsx?$", "", basename(infile)), "_long.xlsx")

# Column that identifies the geography row (usually "Geography" or "Region")
geo_col_guess  <- c("Geography", "Region", "Country")

# Value to keep for the global aggregate (case-insensitive match)
global_label   <- "Global"

# ── HELPERS ───────────────────────────────────────────────────────────────────

find_header_row <- function(path, sheet) {
  # Iterate skip values 0..50. The true data header row is identified by having
  # "Drug Name" (or "Brand Name") PLUS at least one other data column header
  # (Indication, Company Name, Region, or Segment) in the same row.
  #
  # This prevents false matches on metadata rows such as:
  #   "View By: | Drug Name"  (only Drug Name, no companion data columns)
  # while correctly identifying the actual header row such as:
  #   "Drug Name | Segment | Company Name | Indication | Region | Units | 2026(F) | ..."
  for (s in seq(0L, 50L)) {
    test <- tryCatch(
      suppressMessages(read_excel(path, sheet = sheet, skip = s, n_max = 1)),
      error = function(e) NULL
    )
    if (is.null(test)) next
    nm <- names(test)
    has_drug    <- any(grepl("Drug.?Name|Brand.?Name",               nm, ignore.case = TRUE))
    has_partner <- any(grepl("Indication|Company.?Name|Region|Segment", nm, ignore.case = TRUE))
    if (has_drug && has_partner) return(s)
  }
  message("  WARNING: Data header row not found in first 50 rows — defaulting to skip = 0")
  return(0L)
}

# ── MAIN ──────────────────────────────────────────────────────────────────────

# Null-coalescing helper (must be defined before the loop)
`%||%` <- function(x, y) if (!is.null(x) && length(x) > 0 && !is.na(x[1])) x else y

message("=== preprocess_forecast.R ===")
message("Input : ", infile)

sheets <- excel_sheets(infile)
message("Sheets detected: ", paste(sheets, collapse = ", "))

all_long   <- list()
all_global <- list()

for (sheet_name in sheets) {
  message("\n-- Processing sheet: ", sheet_name)

  skip_n <- find_header_row(infile, sheet_name)
  message("  Header row at Excel row ", skip_n + 1)

  df <- suppressMessages(
    read_excel(infile, sheet = sheet_name, skip = skip_n, guess_max = 5000)
  )
  names(df) <- str_squish(names(df))

  if (nrow(df) == 0 || ncol(df) < 3) {
    message("  Skipping — sheet appears empty or too narrow")
    next
  }
  message("  Columns (", ncol(df), "): ", paste(head(names(df), 20), collapse = " | "))

  # ── Detect year columns: any column whose name contains a 4-digit number
  #    starting with "2" (e.g. "2026", "2026 (F)", "2026F", "FY2026").
  #    Exclude columns that look like year-ranges: "2026-2032", "CAGR 2026-32".
  extract_year <- function(col_name) {
    # Remove range pattern first to avoid matching "2026" inside "2026-2032"
    if (grepl("2\\d{3}[^\\d].*2\\d{3}|2\\d{3}-", col_name)) return(NA_character_)
    m <- regmatches(col_name, regexpr("2\\d{3}", col_name))
    if (length(m) == 0L) return(NA_character_) else m
  }

  year_map  <- vapply(names(df), extract_year, character(1L), USE.NAMES = TRUE)
  year_cols <- names(year_map)[!is.na(year_map)]   # original column names
  clean_years <- unname(year_map[year_cols])        # extracted "2026", "2027", …

  if (!length(year_cols)) {
    message("  No year columns found — skipping")
    message("  Column names seen: ", paste(head(names(df), 20), collapse = " | "))
    next
  }
  # Sort by year value so output is chronological
  ord         <- order(as.integer(clean_years))
  year_cols   <- year_cols[ord]
  clean_years <- clean_years[ord]
  message("  Year columns (", length(year_cols), "): ",
          paste(clean_years, collapse = ", "))

  # ── Key columns
  drug_col <- names(df)[grepl("Drug.?Name|Brand.?Name", names(df), ignore.case = TRUE)][1]
  co_col   <- names(df)[grepl("Company.?Name|Company|Sponsor", names(df), ignore.case = TRUE)][1]
  ind_col  <- names(df)[grepl("^Indication|^Disease", names(df), ignore.case = TRUE)][1]
  if (is.na(ind_col)) ind_col <- names(df)[grepl("Indication", names(df), ignore.case = TRUE)][1]
  geo_col  <- names(df)[names(df) %in% geo_col_guess][1]
  if (is.na(geo_col))
    geo_col <- names(df)[grepl("Geography|Region|Country", names(df), ignore.case = TRUE)][1]

  message("  Drug col:    ", drug_col %||% "<not found>")
  message("  Company col: ", co_col   %||% "<not found>")
  message("  Indication:  ", ind_col  %||% "<not found>")
  message("  Geography:   ", geo_col  %||% "<not found>")

  # ── Drop growth/CAGR columns that look like "2026-2032"
  df_clean <- df %>%
    select(any_of(c(drug_col, co_col, ind_col, geo_col)), all_of(year_cols)) %>%
    filter(if (!is.na(drug_col)) !is.na(.data[[drug_col]]) else TRUE)

  # ── Rename columns to standard names
  rename_map <- c()
  if (!is.na(drug_col)) rename_map <- c(rename_map, setNames(drug_col, "Drug Name"))
  if (!is.na(co_col))   rename_map <- c(rename_map, setNames(co_col,   "Company Name"))
  if (!is.na(ind_col))  rename_map <- c(rename_map, setNames(ind_col,  "Indication"))
  if (!is.na(geo_col))  rename_map <- c(rename_map, setNames(geo_col,  "Geography"))
  df_clean <- df_clean %>% rename(any_of(rename_map))

  # ── Rename year columns to clean "2026", "2027" etc.
  yr_rename <- setNames(year_cols, clean_years)
  df_clean  <- df_clean %>% rename(any_of(yr_rename))

  # ── Pivot year columns from wide to long
  # Normalise all year columns to character first — some cells contain "-" or
  # other non-numeric placeholders that cause readxl to infer mixed types across
  # columns, which makes pivot_longer fail with a type-mismatch error.
  id_cols <- intersect(c("Drug Name","Company Name","Indication","Geography"), names(df_clean))
  long_df <- df_clean %>%
    mutate(across(all_of(clean_years), as.character)) %>%
    pivot_longer(
      cols      = all_of(clean_years),
      names_to  = "Year",
      values_to = "Sales (USD M)"
    ) %>%
    mutate(
      Year           = as.integer(Year),
      `Sales (USD M)` = suppressWarnings(as.numeric(gsub("[,$\\s-]", "", as.character(`Sales (USD M)`))))
    ) %>%
    filter(!is.na(`Sales (USD M)`), `Sales (USD M)` > 0)

  long_df[["Source Sheet"]] <- sheet_name
  all_long[[sheet_name]] <- long_df

  # ── Global subset
  if ("Geography" %in% names(long_df)) {
    global_df <- long_df %>%
      filter(str_to_lower(str_squish(Geography)) == str_to_lower(global_label))
    all_global[[sheet_name]] <- global_df
    message("  Long rows total : ", nrow(long_df))
    message("  Global rows only: ", nrow(global_df))
  } else {
    all_global[[sheet_name]] <- long_df
    message("  Long rows: ", nrow(long_df), " (no geography column — all treated as Global)")
  }
}

# ── WRITE OUTPUT ──────────────────────────────────────────────────────────────

if (!length(all_long)) {
  stop("No data processed. Ensure at least one sheet has columns containing 4-digit years starting with 2 (e.g. '2026', '2026 (F)', 'FY2026').")
}

combined_long   <- bind_rows(all_long)
combined_global <- bind_rows(all_global)

out_sheets <- list(
  "All Geographies (Long)"  = as.data.frame(combined_long),
  "Global Only (Dashboard)" = as.data.frame(combined_global)
)

message("\nWriting output to: ", outfile)
message("  'All Geographies (Long)'  : ", nrow(combined_long),   " rows")
message("  'Global Only (Dashboard)' : ", nrow(combined_global), " rows")
message("  Columns: ", paste(names(combined_global), collapse = ", "))
write_xlsx(out_sheets, outfile)
message("\nDone! Drop '", outfile, "' into the dashboard.")
message("The dashboard reads the 'Global Only (Dashboard)' sheet automatically.")
