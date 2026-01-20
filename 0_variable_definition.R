##------------------ filepath  ------------------ 
dataset_path = 'input/SSA_Data 2025.xlsx'
dataset_sheet = 'SSA_questionnaire'

kobo_path = 'input/SSA_questionnaire.xlsx'
survet_sheet = 'survey'
choice_sheet = 'choices'


##------------------ column name/label  ------------------ 
##IMPORTANT: define the column in the kobo that correspond to what has been used in the final dataset, either name or label
var_dataset_colums = 'label::English (en)'


##------------------ define the disaggregation variables:  ------------------ 
# 1) strata
group_vars <- c("overall", "Governorate", "Type of the School", "what is the Key informant type?", "What is the main source of drinking water provided by the school? (Select most frequently used)")
# 2) combined strata 
group_vars <- c(group_vars,"Governorate, What is the main source of drinking water provided by the school? (Select most frequently used)")
# 3) columns present in kobo that do not need to be calculated 
columns_to_exclude <- c('Sub-District', 'Community', 'School name')


##------------------ define numerator/denominator indicators (ratios) ------------------
# 1) List the derived indicators you want to compute.
#    new_var:   name of the new column to create
#    numerator: column in your dataset to use as numerator
#    denominator: column in your dataset to use as denominator --> if sum is needed that create a +/- etc with the names of the columns "`C1` + `C2`"
#    scale:     multiply result by this (use 1 for ratios, 100 for %)

derived_specs <- tibble::tribble(
  ~new_var, ~numerator,                                   ~denominator,                                                                 ~scale,
  "PTR",    "Total number of students within the school", "`How many teaching staff were there ? Male:` + `How many teaching staff were there ? Female:`",   1,
  "PCR",    "Total number of students within the school", list("How many total classrooms are there at this school that are functioning? (used for lessons)"), 1
)

##------------------ define binary indicators (>=1 logic) ------------------
# new_var:  name of the new column
# source:   column to check
# condition: optional condition (default: ">= 1")
binary_specs <- tibble::tribble(
  ~new_var,                                      ~source,                                   ~condition,
  "schools_with_window_replacement_needs",      "Number of windows that need replacement",  ">= 1",
  "schools_with_toilet_repair_needs",           "Number of windows that need repairs",      ">= 1"
)


##------------------ define fixed ranking ------------------
# Group 1:
CUSTOM_RANK_1 <- tibble::tribble(
  ~answer_option, ~answer_rank_1,
  "Totally destroyed/not usable", 1,
  "Used as shelter and thus not usable", 2,
  "Moderate Damaged, but can be repaired to become usable", 3, 
  "Limited damage, can easily be repaired", 4,
  "Damaged, but can set up temporary tents in the grounds of the school", 5,
  "No damage", 6
)
KEY_IDENTIFIERS_1 <- CUSTOM_RANK_1$answer_option 
# Group 2:
CUSTOM_RANK_2 <- tibble::tribble(
  ~answer_option, ~answer_rank_2,
  "School headmaster", 1,
  "Teacher", 2,
  "Civil Society Groups", 3,
  "Local Council",4,
  "NGOs staff",5,
  "Mukhtar",6,
  "Community Leaders (IDPs)",7,
  "Community Leaders (Host Community)",8,
  "Camp Manager",9,
  "Local Charities",10,
  "Local Relief Committees",11,
  "Other",12
)
KEY_IDENTIFIERS_2 <- CUSTOM_RANK_2$answer_option 

##------------------ Define the minimum acceptable n_total for a disaggregation group
MIN_N_TOTAL_THRESHOLD <- 12
FILTER_PROXY_VAR <- "Governorate" 

