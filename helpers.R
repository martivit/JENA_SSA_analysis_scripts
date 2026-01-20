normalize_term <- function(term) {
  # If term is a nested list (list-of-1 containing character vector), unwrap it
  while (is.list(term) && length(term) == 1) term <- term[[1]]
  # If it’s still a list, flatten it
  if (is.list(term)) term <- unlist(term, use.names = FALSE)
  term
}



# evaluate a term that can be:
# - single column name (string)
# - character vector of column names -> row-wise sum
# - expression string like "a + b - c"
eval_term <- function(df, term, operation = NA) {
  to_num <- function(x) suppressWarnings(as.numeric(x))
  
  # Handle character vector with specified operation
  if (is.character(term) && length(term) > 1) {
    cols <- intersect(term, names(df))
    
    if (length(cols) == 0) return(rep(NA_real_, nrow(df)))
    
    mat <- as.matrix(dplyr::mutate(dplyr::select(df, dplyr::all_of(cols)),
                                   dplyr::across(everything(), to_num)))

    
    # Default to sum if no operation specified
    if (is.na(operation)) operation <- "sum"
    
    result <- switch(operation,
                     "sum" = {
                       s <- rowSums(mat, na.rm = TRUE)
                       all_na <- apply(is.na(mat), 1, all)
                       cat("  Sum (first 3):", head(s, 3), "\n")
                       cat("  All NA (first 3):", head(all_na, 3), "\n")
                       s[all_na] <- NA_real_
                       s
                     },
                     "subtract" = {
                       # First column minus sum of rest (or just col1 - col2 if two columns)
                       if (ncol(mat) == 2) {
                         mat[,1] - mat[,2]
                       } else {
                         mat[,1] - rowSums(mat[,-1, drop=FALSE], na.rm = TRUE)
                       }
                     },
                     "multiply" = {
                       apply(mat, 1, function(row) {
                         if (all(is.na(row))) return(NA_real_)
                         prod(row, na.rm = TRUE)
                       })
                     },
                     "divide" = {
                       # First column divided by second column
                       if (ncol(mat) >= 2) {
                         result <- mat[,1] / mat[,2]
                         result[mat[,2] == 0] <- NA_real_
                         result
                       } else {
                         rep(NA_real_, nrow(df))
                       }
                     },
                     # Default: sum
                     {
                       s <- rowSums(mat, na.rm = TRUE)
                       all_na <- apply(is.na(mat), 1, all)
                       s[all_na] <- NA_real_
                       s
                     }
    )
    cat("  Result (first 3):", head(result, 3), "\n")
    return(result)
  }
  
  # Expression string with backticks for complex column names
  if (is.character(term) && length(term) == 1 &&
      !term %in% names(df) &&
      grepl("[+\\-*/]", term, perl = TRUE)) {
    val <- rlang::eval_tidy(rlang::parse_expr(term), data = df)
    return(to_num(val))
  }
  
  # Single column name
  col <- as.character(term)[1]
  if (!col %in% names(df)) return(rep(NA_real_, nrow(df)))
  return(to_num(df[[col]]))
}
add_derived_indicators <- function(df, specs, verbose = FALSE) {
  if (nrow(specs) == 0) return(df)
  
  # Ensure operation column exists
  if (!"operation" %in% names(specs)) {
    specs$operation <- NA_character_
  }
  
  # Helper: safe scale
  get_scale <- function(x) {
    x <- suppressWarnings(as.numeric(x))
    if (length(x) == 0 || is.na(x)) 1 else x
  }
  
  for (i in seq_len(nrow(specs))) {
    new <- as.character(specs$new_var[i])
    
    # scale (defaults to 1 if missing/NA)
    sc <- get_scale(specs$scale[i])
    
    # normalize terms (unwrap list-cols like list(c("a","b")))
    num_term <- normalize_term(specs$numerator[[i]])
    den_term <- normalize_term(specs$denominator[[i]])
    
    # operation (only relevant for multi-column terms)
    op <- specs$operation[i]
    op <- if (is.na(op)) NA_character_ else trimws(as.character(op))

    
    # Numerator: usually a single column; don't apply op unless you *intend* to
    num_vec <- eval_term(df, num_term)
    
    # Denominator: apply operation only if provided (e.g., "sum" for PTR)
    den_vec <- eval_term(df, den_term, operation = op)
  
    
    df[[new]] <- dplyr::case_when(
      is.na(num_vec) | is.na(den_vec) ~ NA_real_,
      den_vec == 0                    ~ NA_real_,
      TRUE                            ~ (num_vec / den_vec) * sc
    )
    
    if (verbose) {
      cat("Result (first 5):", paste(head(df[[new]], 5), collapse = " "), "\n")
    }
  }
  
  df
}


add_binary_indicators <- function(df, specs) {
  if (nrow(specs) == 0) return(df)
  
  to_num <- function(x) suppressWarnings(as.numeric(x))
  
  for (i in seq_len(nrow(specs))) {
    new   <- specs$new_var[i]
    col   <- specs$source[i]
    cond  <- specs$condition[i]
    
    if (!col %in% names(df)) {
      warning(sprintf("Column '%s' for binary indicator '%s' not found.", col, new))
      df[[new]] <- NA_character_
      next
    }
    
    col_vec <- to_num(df[[col]])
    # Apply the condition dynamically (supports >=, >, ==, etc.)
    yes_flag <- rlang::eval_tidy(rlang::parse_expr(paste0("col_vec ", cond)))
    df[[new]] <- dplyr::if_else(yes_flag, "Yes", "No", missing = NA_character_)
  }
  df
}

