# R Curation Pipeline Template for Prototyping in SAIL Databank with `dbplyr`

Template repository providing R tools for prototyping cohort curation pipelines in SAIL Databank, including dbplyr-DB2 helper functions, example workflows, and synthetic datasets.

---

## Overview

`sail-dbplyr-template` is a starter template for prototyping SAIL Databank workflows in R. It provides:

- **DB2 helper functions** with dbplyr support to handle DB2-specific SQL syntax for lazy tables, table creation, and schema management.
- **Example cohort covariate pipeline** for extracting phenotype data from hospital (PEDW) and GP (WLGP) records.
- **Selected synthetic datasets** to support prototyping and collaboration outside SAIL's secure environment.

This template supports prototyping SAIL Databank curation pipelines, providing a framework designed for DB2 workflows that can be executed inside or outside the SAIL environment.

---

## Repository Structure

```
sail-dbplyr-template/
├─ .gitignore
├─ R/
│  ├─ db2_helper.R              # DB2 helper functions with dbplyr integration
│  ├─ project_config.R          # Project configuration, schema, and table definitions
│  └─ R01_covariate_example.R   # Example cohort covariate pipeline
├─ codelists/                   # Example codelists for phenotypes and covariates
    ├─ dev/
    │  ├─ load_synthetic_data.R     # Script to load synthetic data into DB2
    │  ├─ data/                     # Synthetic datasets for prototyping
    │  └─ schema/                   # JSON schemas describing synthetic datasets
└─ sail-dbplyr-template.Rproj   # RStudio project file
```

---

## Getting Started

### Prerequisites

- **R ≥ 4.0**
- **R packages:** `DBI`, `odbc`, `dbplyr`, `tidyverse`, `glue`, `jsonlite`, `bit64`, `here`
- **DB2 access:**
  - **Inside SAIL:** DB2 is already available and accessible via ODBC.
  - **Outside SAIL:** a local DB2 instance is required for testing and prototyping. See [rstudio-db2-lab](https://github.com/JamesAFarrell/rstudio-db2-lab) for a Docker-based RStudio Server environment configured to connect to a DB2 database.

### Installing Dependencies

```r
install.packages(c(
  "DBI", "odbc", "dbplyr", "tidyverse", 
  "glue", "jsonlite", "bit64", "here"
))
```

### Synthetic Data

- **load_synthetic_data.R**  
  Loads CSVs from `dev/data/` into DB2, creating schemas if needed.  
  Each dataset is validated against its JSON schema in `dev/schema/` to ensure column names and types match.

- **data/**  
  Synthetic CSV datasets mimicking the structure of SAIL Databank tables.  
  Useful for prototyping pipelines without using real patient data.

- **schema/**  
  JSON schemas specify column names and data types for each CSV.  
  The `load_synthetic_data.R` script uses these to set column types automatically.  
  Supported types: `character`, `numeric`, `integer`, `bigint`, `logical`, `date`, `datetime`.

---

## Usage

### Load synthetic data

```
library(here)
source(here("dev", "load_synthetic_data.R"))
```
Creates schemas and loads synthetic datasets into DB2.

### Connect to DB2

```
library(DBI)
library(here)   
source(here("R", "db2_helper.R"))

con <- db2_connect(dsn = "PR_SAIL")
```
When run, you may be prompted for DB2 credentials:
- Inside SAIL: enter your SAIL username and password.
- Outside SAIL: enter the username and password for your local or lab DB2 instance.

---

## Core R Functions for DB2

The `db2_helper.R` script provides utility functions to make working with DB2 through `dbplyr` easier:

- **`db2_connect()`** – Establish a DB2 connection via ODBC.  
- **`db2_resolve_id()`** – Resolve table identifiers with schema handling and optional uppercase conversion.  
- **`db2_tbl()`** – Wrapper around `dbplyr::tbl()` that returns a lazy `dplyr` table for DB2.  
- **`db2_write_tbl()`** – Write a data frame into a DB2 table.  
- **`db2_compute()`** – Wrapper around `dplyr::compute()`, computing a query and storing the result in DB2.  
- **`db2_create_schema()`** – Create a schema in DB2 if it does not already exist.  

---