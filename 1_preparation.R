
##------------------ upload dataset and kobo
data    <- read_excel(dataset_path , sheet = dataset_sheet)
survey  <- read_excel(kobo_path , sheet = survet_sheet)
choices  <- read_excel(kobo_path , sheet = choice_sheet)



##------------------ extract select_one and select_multiple indicator
indicator_sm <- survey[grepl("select_multiple", survey$type),]  [[var_dataset_colums]]
indicator_so <- survey[grepl("select_one", survey$type),]  [[var_dataset_colums]]
indicator_int <- survey[grepl("integer", survey$type),]  [[var_dataset_colums]]



# add composite indicator (PTR, PCR, etc etc) defined in 0_variable_definition
data <- add_derived_indicators(data, derived_specs)
indicator_int <- unique(c(indicator_int, derived_specs$new_var))

#  add binary indicators defined in 0_variable_definition
data <- add_binary_indicators(data, binary_specs)
indicator_so <- unique(c(indicator_so, binary_specs$new_var))
