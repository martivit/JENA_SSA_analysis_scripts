
data$overall <- "overall"



## create the list of analysis LOA 
so_loa_analysis <- expand.grid(
  analysis_var = indicator_so,
  analysis_type = "prop_select_one",
  group_var = group_vars,
  stringsAsFactors = FALSE
)
sm_loa_analysis <- expand.grid(
  analysis_var = indicator_sm,
  analysis_type = "prop_select_multiple",
  group_var = group_vars,
  stringsAsFactors = FALSE
)
int_loa_analysis <- expand.grid(
  analysis_var = indicator_int,
  analysis_type = "mean",
  group_var = group_vars,
  stringsAsFactors = FALSE
)
loa_analysis_combined <- dplyr::bind_rows(so_loa_analysis, sm_loa_analysis, int_loa_analysis)

loa_analysis_combined <- loa_analysis_combined[loa_analysis_combined$analysis_var != loa_analysis_combined$group_var, ]
loa_analysis_combined <- loa_analysis_combined[
  !mapply(function(a, g) grepl(a, g, fixed = TRUE), 
          loa_analysis_combined$analysis_var, 
          loa_analysis_combined$group_var), 
]
loa_analysis_combined <- loa_analysis_combined %>%
  filter(!(analysis_var %in% columns_to_exclude))

##------------------ run analysis  ------------------ 
# important: check separator

result <- create_analysis(
  srvyr::as_survey(data),
  loa = loa_analysis_combined,
  sm_separator =  "/")



## ------------------- organize output tables -----------
result_all<- result$results_table%>%
  select(
    analysis_type,
    analysis_var,
    analysis_var_value,
    group_var,
    group_var_value,
    stat,
    n,
    n_total
  )

## if names where used instead of label do the following: 
# label_label = 'label'
# result_all <- result_all %>%
#   mutate(question = if_else(
#     !is.na(match(analysis_var, survey[[var_dataset_colums]])),  # Check if a match exists
#     survey[[label_label]][match(analysis_var, survey[[var_dataset_colums]])],  # Get label if matched
#     analysis_var  # Keep original value if no match
#   )) %>%
#   relocate(question, .after = analysis_var)
# result_all <- result_all %>%
#   mutate(choice = if_else(
#     !is.na(match(analysis_var_value, choices[[var_dataset_colums]])),  # Check if a match exists
#     choices[[label_label]][match(analysis_var_value, choices[[var_dataset_colums]])],  # Get label if matched
#     analysis_var_value  # Keep original value if no match
#   )) %>%
#   relocate(choice, .after = analysis_var_value)
# result_all <- result_all %>%
#   mutate(
#     analysis_var_value = if_else(is.na(analysis_var_value), "NA", analysis_var_value),
#     choice = if_else(analysis_var_value == "NA", "NA", choice)
#   )

## if labels where used instead of label do the following:
raw_results_loaded <-result_all
result_all <- result_all %>%
  rename(
    question = analysis_var,
    choice = analysis_var_value
  )


## common
write_xlsx(result_all, path = "output/results_raw.xlsx")

group_vars <- unique(result_all$group_var)

# Step 4: Create a named list of filtered data frames
result_by_group <- lapply(group_vars, function(gv) {
  result_all %>% filter(group_var == gv)
})

# Step 5: Clean sheet names (truncate and make safe/unique)
names(result_by_group) <- make.unique(substr(gsub("[^A-Za-z0-9]", "_", group_vars), 1, 28))

# Step 6: Write to Excel
write_xlsx(result_by_group, path = "output/results_ALL.xlsx")


# ==========================================================
#                Layout improvements (optional)
# ==========================================================

## ------------------- preparation -----------

##   Create a permanent numeric Kobo Question Order key (stable sort) -----------
kobo_q_order_key <- raw_results_loaded %>%
  pull(analysis_var) %>%
  unique() %>%
  tibble::enframe(name = "kobo_q_order", value = "analysis_var") %>%
  mutate(kobo_q_order = kobo_q_order) 

result_all_loaded_filled <- raw_results_loaded %>%
  # Join the stable sort key
  left_join(kobo_q_order_key, by = "analysis_var") %>%
  # 2. Fill NA 'stat' values with 0 
  mutate(stat = if_else(is.na(stat), 0, stat))

##  Filter out disaggregations with low N_TOTAL, BUT KEEP "overall" -----------
groups_to_keep <- result_all_loaded_filled %>%
  filter(analysis_var == FILTER_PROXY_VAR) %>%
  group_by(group_var_value) %>%
  summarise(max_n_total = max(n_total, na.rm = TRUE)) %>%
  ungroup() %>%
  filter(max_n_total >= MIN_N_TOTAL_THRESHOLD) %>%
  pull(group_var_value)

result_all_loaded_filtered <- result_all_loaded_filled %>%
  filter(group_var_value %in% groups_to_keep | group_var_value == "overall")


# Apply necessary column creation
result_all_processed <- result_all_loaded_filtered %>%
  
  # Create the 'answer_option' column (Includes trimws() for safety)
  mutate(
    is_sm = analysis_type == "prop_select_multiple",
    answer_option = case_when(
      is_sm ~ trimws(gsub(".*/", "", analysis_var_value)),
      TRUE ~ trimws(analysis_var_value)
    )
  ) %>%
  
  # EXCLUDE specific analysis variables
  filter(analysis_var != FILTER_PROXY_VAR) %>%
  
  # Create a secondary, initial answer order key (tie-breaker)
  group_by(kobo_q_order, analysis_var) %>%
  mutate(initial_answer_order = row_number()) %>%
  ungroup()

## ------------------- Conditional Sorting Logic (Targeted and Stable) -----------
LARGE_NA_RANK_PROXY <- 999 # Retained from WC5 for stability


# 1. Identify questions that CONTAIN all required answers (FLEXIBLE CHECK)
question_group_map <- result_all_processed %>%
  group_by(analysis_var) %>%
  summarise(
    answers = list(unique(answer_option)),
    .groups = "drop"
  ) %>%
  rowwise() %>% 
  mutate(
    is_group_1 = all(KEY_IDENTIFIERS_1 %in% unlist(answers)),
    is_group_2 = all(KEY_IDENTIFIERS_2 %in% unlist(answers)),
    order_group_id = case_when(
      is_group_1 ~ 1,
      is_group_2 ~ 2,
      TRUE ~ NA_real_ 
    )
  ) %>%
  ungroup() %>%
  select(analysis_var, order_group_id)

# 2. Apply the conditional sorting
result_all_processed_sorted <- result_all_processed %>%
  
  # Join ranks from both groups
  left_join(CUSTOM_RANK_1, by = "answer_option") %>%
  left_join(CUSTOM_RANK_2, by = "answer_option") %>%
  
  # Join the question's order group ID
  left_join(question_group_map, by = "analysis_var") %>%
  
  # Create the final 'answer_rank' column with the correct classification
  mutate(
    final_answer_rank = case_when(
      order_group_id == 1 & !is.na(answer_rank_1) ~ answer_rank_1,
      order_group_id == 2 & !is.na(answer_rank_2) ~ answer_rank_2,
      TRUE ~ NA_real_ 
    )
  ) %>%
  
  mutate(
    sort_rank_proxy = coalesce(final_answer_rank, LARGE_NA_RANK_PROXY)
  ) %>%
  
  # Group by the numeric Kobo key, then sort answers by:
  group_by(kobo_q_order) %>%
  arrange(kobo_q_order, sort_rank_proxy, initial_answer_order, .by_group = TRUE) %>%
  ungroup() %>%
  
  # Remove temporary/sort columns
  select(-answer_rank_1, -answer_rank_2, -order_group_id, -final_answer_rank, -initial_answer_order, -sort_rank_proxy)




## ------------------- Final Factor Ordering (Ensures stable iteration based on numeric key) -----------


ordered_questions <- result_all_processed_sorted %>%
  arrange(kobo_q_order) %>% 
  pull(analysis_var) %>%
  unique()

result_all_processed_sorted <- result_all_processed_sorted %>%
  mutate(analysis_var = factor(analysis_var, levels = ordered_questions)) %>%
  # Remove the question sort key from the final output data frame
  select(-kobo_q_order)


# Get a list of all unique group variables to loop over from the processed data
group_vars <- unique(result_all_processed_sorted$group_var)

# Pivot, format, and organize the data in a list of data frames (unchanged)
pivoted_tables_list <- lapply(group_vars, function(gv) {
  
  # 1. Filter and Pivot
  data_pivoted <- result_all_processed_sorted %>%
    filter(group_var == gv) %>%
    pivot_wider(
      id_cols = c(analysis_var, answer_option, analysis_var_value, analysis_type),
      names_from = `group_var_value`,
      values_from = c(stat, n, n_total)
    )
  
  # 2. Reorder Columns for Grouped Metrics (unchanged logic)
  metric_cols <- names(data_pivoted)[grep("^(stat|n|n_total)_", names(data_pivoted))]
  
  if (length(metric_cols) > 0) {
    sorted_metric_cols <- metric_cols[order(
      gsub("^(stat|n|n_total)_", "", metric_cols), 
      sub("_.*", "", metric_cols) 
    )]
    
    id_cols <- setdiff(names(data_pivoted), metric_cols)
    
    data_pivoted <- data_pivoted %>%
      select(all_of(id_cols), all_of(sorted_metric_cols))
  }
  
  # 3. Create the Question-Level Header Rows (unchanged logic)
  unique_questions <- levels(data_pivoted$analysis_var)
  final_rows <- list()
  
  for (q in unique_questions) {
    if (q %in% data_pivoted$analysis_var) { 
      header_row <- data_pivoted %>% 
        filter(analysis_var == q) %>%
        select(analysis_var, analysis_var_value, answer_option, analysis_type) %>%
        slice(1) %>%
        mutate(
          answer_option = q,              
          analysis_var = q,
          analysis_var_value = "",        
          analysis_type = "",             
          across(starts_with("stat_"), ~NA_real_),
          across(starts_with("n_"), ~NA_integer_)
        )
      
      data_rows <- data_pivoted %>% filter(analysis_var == q)
      
      final_rows[[q]] <- bind_rows(header_row, data_rows)
    }
  }
  
  # 4. Combine all question groups
  return(bind_rows(final_rows))
})

# Name the sheets for the Excel file
names(pivoted_tables_list) <- make.unique(substr(gsub("[^A-Za-z0-9]", "_", group_vars), 1, 28))

## ------------------- Excel Export with openxlsx -----------
HEADER_COLOR <- "#DBD8D7"

export_formatted_excel <- function(pivoted_tables_list, path, header_color) {
  # ... (Excel export function code is unchanged)
  wb <- openxlsx::createWorkbook()
  
  # Define styles
  header_style <- openxlsx::createStyle(fgFill = header_color, border = NULL)
  percent_style <- openxlsx::createStyle(numFmt = "0.0%") 
  
  for (sheet_name in names(pivoted_tables_list)) {
    
    df <- pivoted_tables_list[[sheet_name]]
    
    openxlsx::addWorksheet(wb, sheet_name)
    
    # Ensure stat columns are numeric/double before writing
    stat_cols <- grep("^stat_", names(df))
    if (length(stat_cols) > 0) {
      df[stat_cols] <- lapply(df[stat_cols], as.numeric)
    }
    
    openxlsx::writeData(wb, sheet_name, df, rowNames = FALSE)
    
    # Identify header rows
    header_rows <- which(df$analysis_type == "")
    
    # 1. Apply Percentage Style FIRST
    if (length(stat_cols) > 0) {
      openxlsx::addStyle(
        wb,
        sheet_name,
        style = percent_style,
        rows = 2:(nrow(df) + 1), 
        cols = stat_cols,
        gridExpand = TRUE
      )
    }
    
    # 2. Apply Header Style SECOND
    if (length(header_rows) > 0) {
      openxlsx::addStyle(
        wb,
        sheet_name,
        style = header_style,
        rows = header_rows + 1,
        cols = 1:ncol(df),
        gridExpand = TRUE
      )
    }
  }
  
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
}

# Export the list of tables to a new Excel file using the formatting function
export_formatted_excel(
  pivoted_tables_list, 
  path = "output/results_pivoted_formatted.xlsx",
  header_color = HEADER_COLOR
)

