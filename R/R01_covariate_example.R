# ======================================================================
# Cohort Covariate Extraction Script
# ======================================================================
# Purpose:
#   - Load ICD10 and ReadV2 codelists for covariates
#   - Extract covariate events from PEDW (hospital) and WLGP (GP)
#   - Link covariate events to study cohort
#   - Produce wide-format covariate table for downstream analysis
#
# ======================================================================

# -------------------------------
# Load packages
# -------------------------------
library(tidyverse)
library(here)
library(dbplyr)

# -------------------------------
# Load project configuration & helpers
# -------------------------------
source(here("R", "project_config.R"))
source(here("R", "db2_helper.R"))

# -------------------------------
# Database connection
# -------------------------------
con <- db2_connect()

# ======================================================================
# Step 1: Prepare Codelists
# ======================================================================

# ICD-10 codelists (hospital data)
icd10_codelist_files <- list(
  "hypertension" = "hypertension_icd10.csv",
  "diabetes"     = "diabetes_icd10.csv"
)

codelist_icd10_df <- imap_dfr(
  icd10_codelist_files,
  ~ read_csv(here("codelists", .x), col_types = cols(.default = "c")) %>%
    mutate(phenotype = .y)
)

db2_write_tbl(
  con,
  table   = tbl_proj_codelist_covariate_icd10,
  schema  = schema_collab,
  data    = codelist_icd10_df,
  overwrite = TRUE
)

# ReadV2 codelists (primary care data)
readv2_codelist_files <- list(
  "hypertension" = "hypertension_readv2.csv",
  "diabetes"     = "diabetes_readv2.csv"
) 

codelist_readv2_df <- imap_dfr(
  readv2_codelist_files,
  ~ read_csv(here("codelists", .x), col_types = cols(.default = "c")) %>%
    mutate(
      phenotype = .y,
      code = str_sub(code, 1, 5)  # standardize Read codes to 5 chars
    )
)

db2_write_tbl(
  con,
  table   = tbl_proj_codelist_covariate_readv2,
  schema  = schema_collab,
  data    = codelist_readv2_df,
  overwrite = TRUE
)

# ======================================================================
# Step 2: Load Source Tables
# ======================================================================

# Cohort 2020 table
cohort20 <- db2_tbl(con, tbl_cohort20, schema_data)

# GP events
wlgp_event <- db2_tbl(con, tbl_wlgp_event, schema_data)

# Hospital data (PEDW)
pedw_spell   <- db2_tbl(con, tbl_pedw_spell, schema_data)
pedw_episode <- db2_tbl(con, tbl_pedw_episode, schema_data)
pedw_diag    <- db2_tbl(con, tbl_pedw_diag, schema_data)

# Codelists from DB
codelist_icd10  <- db2_tbl(con, tbl_proj_codelist_covariate_icd10, schema_collab)
codelist_readv2 <- db2_tbl(con, tbl_proj_codelist_covariate_readv2, schema_collab)

# ======================================================================
# Step 3: Prepare Cohort Table
# ======================================================================

cohort <- cohort20 %>% 
  select(
    person_id = ALF_E,
    sex = GNDR_CD,
    date_of_birth = WOB,
    study_start_date = COHORT_START_DATE,
    study_end_date = COHORT_END_DATE
  ) %>% 
  db2_compute(
    con     = con,
    table   = tbl_proj_cohort,
    schema  = schema_collab,
    overwrite = TRUE
  )

# ======================================================================
# Step 4: Extract Covariates from PEDW (Hospital)
# ======================================================================

# Diagnoses (3- and 4-digit ICD-10)
pedw_diag_3 <- pedw_diag %>%
  select(
    procode3 = PROV_UNIT_CD,
    spell_id = SPELL_NUM_E,
    epiorder = EPI_NUM,
    code     = DIAG_CD_123
  ) %>%
  inner_join(codelist_icd10, by = "code")

pedw_diag_4 <- pedw_diag %>%
  select(
    procode3 = PROV_UNIT_CD,
    spell_id = SPELL_NUM_E,
    epiorder = EPI_NUM,
    code     = DIAG_CD_1234
  ) %>%
  inner_join(codelist_icd10, by = "code")

# Combine 3- and 4-digit diagnosis codes
pedw_diag_combined <- union_all(pedw_diag_3, pedw_diag_4)

# Add episode-level dates
pedw_diag_episode <- pedw_diag_combined %>%
  left_join(
    pedw_episode %>%
      select(
        procode3 = PROV_UNIT_CD,
        spell_id = SPELL_NUM_E,
        epiorder = EPI_NUM,
        date     = EPI_STR_DT
      ),
    by = c("procode3", "spell_id", "epiorder")
  )

# Add person IDs (via spell table)
pedw_diag_spell <- pedw_diag_episode %>%
  left_join(
    pedw_spell %>%
      select(
        person_id = ALF_E,
        procode3  = PROV_UNIT_CD,
        spell_id  = SPELL_NUM_E
      ),
    by = c("procode3", "spell_id")
  )

# Final PEDW covariate events
pedw_covariate_events <- pedw_diag_spell %>%
  mutate(
    source          = "PEDW",
    source_priority = 1
  ) %>%
  select(person_id, phenotype, date, code, source, source_priority)

# ======================================================================
# Step 5: Extract Covariates from WLGP (Primary Care)
# ======================================================================

wlgp_covariate_events <- wlgp_event %>%
  select(
    person_id = ALF_E,
    code      = EVENT_CD,
    date      = EVENT_DT
  ) %>%
  inner_join(codelist_readv2, by = "code") %>%
  mutate(
    source          = "WLGP",
    source_priority = 2
  ) %>%
  select(person_id, phenotype, date, code, source, source_priority)

# ======================================================================
# Step 6: Combine Events & Restrict to Cohort
# ======================================================================

covariate_events <- pedw_covariate_events %>% 
  union_all(wlgp_covariate_events) %>%
  inner_join(
    cohort %>%
      select(
        person_id,
        min_date  = date_of_birth,
        max_date  = study_start_date
      ),
    by = "person_id"
  ) %>%
  filter(date >= min_date & date <= max_date)

# ======================================================================
# Step 7: Collapse to First Event per Phenotype
# ======================================================================

covariate_agg <- covariate_events %>%
  window_order(date, source_priority, code) %>%
  group_by(person_id, phenotype) %>%
  mutate(
    row_num = row_number(),
    flag    = 1L
  ) %>%
  filter(row_num == 1) %>%
  ungroup()

# ======================================================================
# Step 8: Pivot to Wide Format
# ======================================================================

covariate_wide <- covariate_agg %>%
  select(person_id, phenotype, flag, date, code, source) %>%
  pivot_wider(
    names_from   = phenotype,
    values_from  = c(flag, date, code, source),
    names_glue   = "{phenotype}_{.value}"
  )

# ======================================================================
# Step 9: Merge with Cohort
# ======================================================================

cohort_covariate <- cohort %>%
  select(person_id) %>%
  left_join(covariate_wide, by = "person_id")

# ======================================================================
# Step 10: Write to Database
# ======================================================================

cohort_covariate_computed = cohort_covariate %>%
  db2_compute(
    con     = con,
    table   = tbl_proj_cohort_covariate,
    schema  = schema_collab,
    overwrite = TRUE
  )

# ======================================================================
# Step 11: Inspect Sample
# ======================================================================

cohort_covariate_collect <- cohort_covariate_computed %>% 
  head(1000) %>% 
  collect()
