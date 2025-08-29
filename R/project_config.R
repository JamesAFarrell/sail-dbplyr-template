# =============================================================================
# Configuration: Project, Schema, and Table Names
# =============================================================================

library(glue)

# -----------------------------------------------------------------------------
# Project metadata
# -----------------------------------------------------------------------------
project_name <- "HDS_EXAMPLE"

# -----------------------------------------------------------------------------
# Database schema names
# -----------------------------------------------------------------------------
schema_data      <- "SAILWMCCV"     # Read-only schema for data-sets
schema_collab    <- "SAILWWMCCV"    # Read/write collaboration schema
schema_reference <- "SAILUKHDV"     # Reference and look-up tables

# -----------------------------------------------------------------------------
# Cohort prefix used in data-set table names
# -----------------------------------------------------------------------------
cohort_prefix <- "C19_COHORT"

# Provisioned Datasets
# -----------------------------------------------------------------------------
# Cohort tables
# -----------------------------------------------------------------------------
tbl_cohort16 <- glue("{cohort_prefix}16")
tbl_cohort20 <- glue("{cohort_prefix}20")

# -----------------------------------------------------------------------------
# Patient Episode Database for Wales (PEDW)
# -----------------------------------------------------------------------------
tbl_pedw_spell      <- glue("{cohort_prefix}_PEDW_SPELL")
tbl_pedw_diag       <- glue("{cohort_prefix}_PEDW_DIAG")
tbl_pedw_oper       <- glue("{cohort_prefix}_PEDW_OPER")
tbl_pedw_episode    <- glue("{cohort_prefix}_PEDW_EPISODE")
tbl_pedw_superspell <- glue("{cohort_prefix}_PEDW_SUPERSPELL")

# -----------------------------------------------------------------------------
# Outpatient Data-set for Wales (OPDW)
# -----------------------------------------------------------------------------
tbl_opdw       <- glue("{cohort_prefix}_OPDW_OUTPATIENTS")
tbl_opdw_diag  <- glue("{cohort_prefix}_OPDW_OUTPATIENTS_DIAG")
tbl_opdw_oper  <- glue("{cohort_prefix}_OPDW_OUTPATIENTS_OPER")

# -----------------------------------------------------------------------------
# Emergency Department Data-set (EDDS)
# -----------------------------------------------------------------------------
tbl_edds <- glue("{cohort_prefix}_EDDS_EDDS")

# -----------------------------------------------------------------------------
# Welsh Longitudinal General Practice (WLGP)
# -----------------------------------------------------------------------------
tbl_wlgp_event <- glue("{cohort_prefix}_WLGP_GP_EVENT_CLEANSED")

# -----------------------------------------------------------------------------
# Welsh Demographic Service (WDS)
# -----------------------------------------------------------------------------
tbl_wdsd_per_res <- glue("{cohort_prefix}_WDSD_PER_RESIDENCE_GPREG")


# -----------------------------------------------------------------------------
# Project-specific Tables (Project Prefix)
# -----------------------------------------------------------------------------
# Codelists for covariates
tbl_proj_codelist_covariate_icd10 <- glue("{project_name}_CODELIST_COVARIATE_ICD10")
tbl_proj_codelist_covariate_readv2 <- glue("{project_name}_CODELIST_COVARIATE_READV2")

# Project cohort tables
tbl_proj_cohort           <- glue("{project_name}_COHORT")
tbl_proj_cohort_covariate <- glue("{project_name}_COHORT_COVARIATE")
