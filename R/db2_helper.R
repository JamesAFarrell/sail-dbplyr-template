# -------------------------
# DB2 Helper Module
# -------------------------

#' Connect to a DB2 database
#'
#' @param dsn The ODBC data source name
#' @param bigint How to handle BIGINT columns: "integer64" (default), "numeric", or "character"
#' @return A DBI connection object
db2_connect <- function(dsn = "PR_SAIL", bigint = "integer64") {
  con <- DBI::dbConnect(
    odbc::odbc(),
    dsn      = dsn,
    uid      = rstudioapi::askForPassword("Enter username"),
    pwd      = rstudioapi::askForPassword("Enter password"),
    bigint   = bigint
  )
  
  return(con)
}


#' Resolve a table identifier for DB2
#'
#' @param table Table name
#' @param schema Optional schema name
#' @param to_upper Should table/schema names be uppercased (default TRUE)
#' @return A DBI::Id object for the table
db2_resolve_id <- function(table, schema = NULL, to_upper = TRUE) {
  if (to_upper) {
    table <- toupper(table)
    if (!is.null(schema)) {
      schema <- toupper(schema)
    }
  }
  DBI::Id(schema = schema, table = table)
}


#' Return a lazy tbl for a DB2 table
#'
#' @param con DBI connection
#' @param table Table name
#' @param schema Optional schema name
#' @return A dplyr lazy tbl object
db2_tbl <- function(con, table, schema = NULL) {
  full_table <- db2_resolve_id(table, schema)
  quoted_table <- DBI::dbQuoteIdentifier(con, full_table)
  
  sql_query <- dbplyr::build_sql(
    "SELECT * FROM ",
    quoted_table,
    con = con
  )
  
  dplyr::tbl(con, dbplyr::sql(sql_query))
}


#' Write a data frame to DB2
#'
#' @param con DBI connection
#' @param table Table name
#' @param schema Optional schema name
#' @param data Data frame to write
#' @param overwrite Should existing table be overwritten?
#' @param append Should data be appended if table exists?
db2_write_tbl <- function(con, table, schema = NULL, data,
                          overwrite = FALSE, append = FALSE) {
  full_id <- db2_resolve_id(table = table, schema = schema)
  quoted_id <- DBI::dbQuoteIdentifier(con, full_id)
  
  DBI::dbWriteTable(
    conn      = con,
    name      = quoted_id,
    value     = data,
    overwrite = overwrite,
    append    = append
  )
  
  invisible(NULL)
}


#' Compute a table from a query and store it in DB2
#'
#' @param query A dbplyr query (lazy tbl) or SQL object
#' @param con DBI connection
#' @param table Table name to create
#' @param schema Optional schema name
#' @param overwrite Should existing table be overwritten? Default FALSE
#' @param temporary Should table be temporary? Default FALSE
#' @return A lazy dplyr tbl pointing to the new table
db2_compute <- function(query, con, table, schema = NULL,
                        overwrite = FALSE, temporary = FALSE) {
  # Resolve table identifier
  full_table <- db2_resolve_id(table, schema)
  quoted_table <- DBI::dbQuoteIdentifier(con, full_table)
  
  # Check for existing table
  if (DBI::dbExistsTable(con, full_table)) {
    if (overwrite) {
      DBI::dbRemoveTable(con, full_table)
    } else {
      tbl_name <- if (!is.null(schema)) paste(schema, table, sep = ".") else table
      stop(glue::glue("Table {tbl_name} already exists. Use overwrite = TRUE."))
    }
  }
  
  # Render query to SQL string
  sql_string <- trimws(as.character(dbplyr::sql_render(query)))
  
  # Create table SQL
  table_type <- if (temporary) "CREATE GLOBAL TEMPORARY TABLE" else "CREATE TABLE"
  full_sql <- glue::glue(
    "{table_type} {quoted_table} AS ({sql_string}) WITH DATA"
  )
  
  # Execute query
  DBI::dbExecute(con, full_sql)
  
  # Return lazy tbl
  db2_tbl(con, table, schema)
}


#' Create a schema in DB2 if it does not exist
#'
#' @param con DBI connection object
#' @param schema Character scalar. Schema name to create.
#' @param replace Logical. If TRUE, drops and recreates the schema if it exists. Default FALSE.
#' @return Invisibly returns TRUE if schema was created or already exists, FALSE otherwise.
#' @examples
db2_create_schema <- function(con, schema, replace = FALSE) {
  stopifnot(is.character(schema), length(schema) == 1)
  
  schema <- toupper(schema)  # force uppercase
  
  # Check if schema exists
  exists <- dbGetQuery(con, glue::glue("
    SELECT COUNT(*) AS CNT
    FROM SYSCAT.SCHEMATA
    WHERE SCHEMANAME = '{schema}'
  "))$CNT > 0
  
  if (exists) {
    if (replace) {
      message(glue::glue("Dropping and recreating schema {schema}..."))
      dbExecute(con, glue::glue("DROP SCHEMA {schema} RESTRICT"))
      dbExecute(con, glue::glue("CREATE SCHEMA {schema}"))
    } else {
      message(glue::glue("Schema {schema} already exists, skipping."))
    }
  } else {
    message(glue::glue("Creating schema {schema}..."))
    dbExecute(con, glue::glue("CREATE SCHEMA {schema}"))
  }
  
  invisible(TRUE)
}


