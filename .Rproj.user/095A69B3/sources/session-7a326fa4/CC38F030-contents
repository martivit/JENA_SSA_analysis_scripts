# evaluate a term that can be:
# - single column name (string)
# - character vector of column names -> row-wise sum
# - expression string like "a + b - c"
eval_term <- function(df, term) {
  to_num <- function(x) suppressWarnings(as.numeric(x))
  
  # sum of multiple columns (already NA+int -> int)
  if (is.character(term) && length(term) > 1) {
    cols <- intersect(term, names(df))
    if (length(cols) == 0) return(rep(NA_real_, nrow(df)))
    mat <- as.matrix(dplyr::mutate(dplyr::select(df, dplyr::all_of(cols)),
                                   dplyr::across(everything(), to_num)))
    s <- rowSums(mat, na.rm = TRUE)
    all_na <- apply(is.na(mat), 1, all)
    s[all_na] <- NA_real_
    return(s)
  }
  
  # NEW: treat NA as 0 only for "+" expressions
  if (is.character(term) && length(term) == 1 && grepl("\\+", term) && !grepl("[-*/]", term)) {
    parts <- trimws(strsplit(term, "\\+")[[1]])
    cols <- intersect(parts, names(df))
    if (length(cols) == 0) return(rep(NA_real_, nrow(df)))
    
    mat <- as.matrix(dplyr::mutate(dplyr::select(df, dplyr::all_of(cols)),
                                   dplyr::across(everything(), to_num)))
    s <- rowSums(mat, na.rm = TRUE)
    all_na <- apply(is.na(mat), 1, all)
    s[all_na] <- NA_real_   # keeps NA+NA = NA
    return(s)
  }
  
  # other expressions unchanged (keep normal R behavior)
  if (is.character(term) && length(term) == 1 && grepl("[+\\-*/()]", term, perl = TRUE)) {
    val <- rlang::eval_tidy(rlang::parse_expr(term), data = df)
    return(to_num(val))
  }
  
  # single column name
  col <- as.character(term)[1]
  if (!col %in% names(df)) return(rep(NA_real_, nrow(df)))
  return(to_num(df[[col]]))
}


add_derived_indicators <- function(df, specs) {
  if (nrow(specs) == 0) return(df)
  
  for (i in seq_len(nrow(specs))) {
    new <- specs$new_var[i]
    sc  <- ifelse(is.null(specs$scale[i]), 1, specs$scale[i])
    
    num_vec <- eval_term(df, specs$numerator[[i]])
    den_vec <- eval_term(df, specs$denominator[[i]])
    
    df[[new]] <- dplyr::case_when(
      is.na(num_vec) | is.na(den_vec) ~ NA_real_,
      den_vec == 0                    ~ NA_real_,
      TRUE                            ~ (num_vec / den_vec) * sc
    )
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

