# =============================================================================
# Script: Load CSVs into the DB2 database
# =============================================================================

library(DBI)
library(readr)
library(stringr)
library(here)
library(glue)

# -----------------------------------------------------------------------------
# Load helper functions and project configuration
# -----------------------------------------------------------------------------
source(here("R", "db2_helper.R"))
source(here("R", "project_config.R"))

con <- db2_connect()
input_dir   <- here("dev", "data")
schema_dir  <- here("dev", "schema")

# -----------------------------------------------------------------------------
# Main function: import CSVs into DB2
# -----------------------------------------------------------------------------
import_synthetic_csvs <- function(con, input_dir, schema_dir) {
  
  csv_files <- list.files(input_dir, pattern = "\\.csv$", full.names = TRUE)
  
  # Ensure required schemas exist
  db2_create_schema(con, schema_data)
  db2_create_schema(con, schema_collab)
  db2_create_schema(con, schema_reference)
  
  for (file in csv_files) {
    # Derive table name
    table_name  <- tools::file_path_sans_ext(basename(file)) %>% toupper()
    
    # Load JSON schema for this CSV
    json_file <- file.path(schema_dir, paste0(tools::file_path_sans_ext(basename(file)), ".json"))
    if (!file.exists(json_file)) {
      stop(glue("Schema JSON file does not exist for {basename(file)}"))
    }
    schema_json <- jsonlite::fromJSON(json_file)
    
    # Read CSV as character
    df <- readr::read_csv(
      file,
      col_types = readr::cols(.default = readr::col_character()),
      show_col_types = FALSE
    )
    
    # Verify columns match schema
    csv_cols <- colnames(df)
    schema_cols <- names(schema_json)
    
    missing_cols <- setdiff(schema_cols, csv_cols)
    extra_cols   <- setdiff(csv_cols, schema_cols)
    
    if (length(missing_cols) > 0) {
      stop(glue("CSV {basename(file)} is missing columns: {paste(missing_cols, collapse=', ')}"))
    }
    if (length(extra_cols) > 0) {
      stop(glue("CSV {basename(file)} has extra columns not in schema: {paste(extra_cols, collapse=', ')}"))
    }
    
    # Convert columns to schema types
    for (col_name in schema_cols) {
      df[[col_name]] <- tryCatch(
        switch(
          schema_json[[col_name]],
          "character" = as.character(df[[col_name]]),
          "numeric"   = as.numeric(df[[col_name]]),
          "integer"   = as.integer(df[[col_name]]),
          "bigint"    = bit64::as.integer64(df[[col_name]]),
          "logical"   = as.logical(df[[col_name]]),
          "date"      = as.Date(df[[col_name]]),
          "datetime"  = as.POSIXct(df[[col_name]]),
          stop(glue::glue("Unknown type '{schema_json[[col_name]]}' for column {col_name} in {basename(file)}"))
        ),
        error = function(e) stop(glue(
          "Error converting column {col_name} in {basename(file)} to type {schema_json[[col_name]]}: {e$message}"
        ))
      )
    }
    
    # Write to DB2 table
    db2_write_tbl(
      con = con,
      table = table_name,
      schema = schema_data,
      data = df,
      overwrite = TRUE
    )
    
    message(glue("Loaded {basename(file)} to {schema_data}.{table_name}"))
  }
}

# -----------------------------------------------------------------------------
# Run the CSV import
# -----------------------------------------------------------------------------
import_synthetic_csvs(con, input_dir, schema_dir)

# Close database connection
dbDisconnect(con)
message("Database connection closed.")
