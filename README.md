# JENA/SSA Analysis Tool
An R-based analysis pipeline for processing and analyzing School level Assessment data with support for complex disaggregations, derived indicators, and formatted Excel outputs

## Table of Contents

- [Repository Structure](#repository-structure)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Running the Analysis](#running-the-analysis)
  - [Understanding the Outputs](#understanding-the-outputs)
- [Advanced Features](#advanced-features)
  - [Using Names Instead of Labels](#using-names-instead-of-labels)
  - [Custom Operations for Derived Indicators](#custom-operations-for-derived-indicators)
- [Troubleshooting](#troubleshooting)



## Features

- **Flexible Indicator Types**: Handles select_one, select_multiple, and numeric (integer) questions
- **Derived Indicators**: Calculate ratios like Pupil-Teacher Ratio (PTR) and Pupil-Classroom Ratio (PCR)
- **Binary Indicators**: Automatically convert numeric thresholds into Yes/No flags
- **Multi-level Disaggregation**: Analyze data across multiple strata and combinations
- **Custom Answer Ordering**: Define fixed rankings for specific question types
- **Low-N Filtering**: Automatically exclude disaggregations with insufficient sample sizes
- **Formatted Excel Output**: Color-coded headers, percentage formatting, and grouped metrics

## Repository Structure

```
.
├── jena_ssa_analysis.R          # Main script - run this to execute the analysis
├── 0_variable_definition.R      # Configuration file - UPDATE THIS
├── 1_preparation.R              # Data loading and indicator extraction
├── 2_analysis.R                 # Analysis execution and output formatting
├── helpers.R                    # Helper functions for derived/binary indicators
├── input/                       # Place your data files here
│   ├── SSA_Data 2025.xlsx      # Main dataset
│   └── SSA_questionnaire.xlsx  # KoBoToolbox form structure
└── output/                      # Analysis results (created automatically)
    ├── results_raw.xlsx
    ├── results_ALL.xlsx
    └── results_pivoted_formatted.xlsx
```

## Installation

### Prerequisites

- R (version 4.0 or higher recommended)
- RStudio (optional but recommended)

### Setup

1. Clone this repository:
```bash
git clone https://github.com/yourusername/ssa-analysis.git
cd ssa-analysis
```

2. Open `jena_ssa_analysis.R` in R or RStudio. The script will automatically install all required packages on first run:
   - writexl, readr, gdata, tidyverse, rlang, dplyr
   - formattable, data.table, hablar, tidyr, readxl, purrr
   - analysistools (from GitHub)

## Configuration

### Step 1: Prepare Your Input Files

Place the following files in the `input/` folder:

1. **Main Dataset** (e.g., `SSA_Data 2025.xlsx`)
   - Your survey data with one row per survey response
   - Column headers should match KoBoToolbox labels or names

2. **KoBoToolbox Form** (e.g., `SSA_questionnaire.xlsx`)
   - Export from KoBoToolbox (XLSForm format)
   - Must contain `survey` and `choices` sheets

### Step 2: Update Configuration

Open `0_variable_definition.R` and modify the following sections:

#### File Paths
```r
dataset_path = 'input/SSA_Data 2025.xlsx'
dataset_sheet = 'SSA_questionnaire'
kobo_path = 'input/SSA_questionnaire.xlsx'
```

#### Column Naming Convention
Specify whether your dataset uses KoBoToolbox **labels** or **names**:
```r
var_dataset_colums = 'label::English (en)'  # For labels, depends on your kobotool
# var_dataset_colums = 'name'               # For names
```

#### Disaggregation Variables
Define how you want to break down your analysis:
```r
group_vars <- c(
  "overall", 
  "Governorate", 
  "Type of the School", 
  "what is the Key informant type?",
  "What is the main source of drinking water provided by the school?"
)

# Optional: Add combined disaggregations
group_vars <- c(group_vars, "Governorate, Type of the School")

# Exclude columns that don't need analysis
columns_to_exclude <- c('Sub-District', 'Community', 'School name')
```

#### Derived Indicators (Optional)
Calculate composite indicators like ratios:
```r
derived_specs <- tibble::tribble(
  ~new_var, ~numerator,                                   ~denominator,                                                                                                          ~operation, ~scale,
  "PTR",    "Total number of students within the school", list(c("How many teaching staff were there ? Male:", "How many teaching staff were there ? Female:")),               "sum",      1,
  "PCR",    "Total number of students within the school", list("How many total classrooms are there at this school that are functioning? (used for lessons)"),                 NA,         1
)
```

#### Binary Indicators (Optional)
Create Yes/No flags based on thresholds:
```r
binary_specs <- tibble::tribble(
  ~new_var,                                      ~source,                                   ~condition,
  "schools_with_window_replacement_needs",      "Number of windows that need replacement",  ">= 1",
  "schools_with_toilet_repair_needs",           "Number of windows that need repairs",      ">= 1"
)

```

#### Custom Answer Ordering (Optional)
Define fixed rankings for specific questions:
```r
CUSTOM_RANK_1 <- tibble::tribble(
  ~answer_option, ~answer_rank_1,
  "Totally destroyed/not usable", 1,
  "Moderate Damaged, but can be repaired", 2,
  "Limited damage, can easily be repaired", 3,
  "No damage", 4
)
KEY_IDENTIFIERS_1 <- CUSTOM_RANK_1$answer_option
```

#### Minimum Sample Size
Set the threshold for excluding small disaggregation groups:
```r
MIN_N_TOTAL_THRESHOLD <- 12
FILTER_PROXY_VAR <- "Governorate"  # Variable to check for minimum N
```

## Usage

### Running the Analysis

1. Ensure your configuration in `0_variable_definition.R` is complete
2. Open `jena_ssa_analysis.R` in R or RStudio
3. Run the entire script (Ctrl+Shift+Enter in RStudio or `source('jena_ssa_analysis.R')`)

The script will:
- Install any missing packages
- Load and prepare your data
- Extract indicator types from KoBoToolbox form
- Calculate derived and binary indicators
- Run analysis across all disaggregations
- Generate three Excel output files

### Understanding the Outputs

The `output/` folder will contain:

#### 1. `results_raw.xlsx`
- Long-format table with all analysis results
- Columns: analysis_type, question, choice, group_var, group_var_value, stat, n, n_total
- Useful for further processing or importing into other tools

#### 2. `results_ALL.xlsx`
- Separate sheets for each disaggregation variable
- Same long format as results_raw.xlsx
- Easier navigation when reviewing specific breakdowns

#### 3. `results_pivoted_formatted.xlsx` ⭐
- **Most user-friendly output**
- Wide format with metrics grouped by disaggregation level
- Color-coded question headers
- Percentage formatting for proportions
- Custom answer ordering applied
- Low-N disaggregations filtered out
- One sheet per disaggregation variable

## Advanced Features

### Using Names Instead of Labels

If your dataset uses KoBoToolbox **names** (e.g., `q1_school_type`) instead of labels, uncomment the mapping code in `2_analysis.R`:

```r
label_label = 'label'
result_all <- result_all %>%
  mutate(question = if_else(
    !is.na(match(analysis_var, survey[[var_dataset_colums]])),
    survey[[label_label]][match(analysis_var, survey[[var_dataset_colums]])],
    analysis_var
  )) %>%
  relocate(question, .after = analysis_var)
```

### Custom Operations for Derived Indicators

Supported operations:
- `"sum"`: Add multiple columns
- `"subtract"`: First column minus rest
- `"multiply"`: Multiply columns together
- `"divide"`: First column divided by second
- `NA`: Direct division (numerator / denominator)

### Excel Styling Customization

Modify the header color in `2_analysis.R`:
```r
HEADER_COLOR <- "#DBD8D7"  # Light gray (default)
```

## Troubleshooting

### Common Issues

**Correctly identify the label/name columns**
- in `0_variable_definition.R` correctly specify the dataset column name in `var_dataset_colums`
- in `2_analysis.R`, locate the section labeled `## if names where used instead of label do the following` and comment or uncomment it as appropriate.

**"Column not found" errors**
- Check that `var_dataset_colums` matches your actual column naming convention
- Verify column names in your dataset match those in KoBoToolbox form

**Empty output files**
- Ensure your dataset is not empty
- Check that indicator types are correctly identified in KoBoToolbox form
- Verify sheet names in `0_variable_definition.R` match your Excel files

**Derived indicators showing NA**
- Confirm column names in `derived_specs` exactly match your dataset
- Check for missing or non-numeric values in source columns
- Use verbose mode: `add_derived_indicators(data, derived_specs, verbose = TRUE)`

**Low-N filtering too aggressive**
- Adjust `MIN_N_TOTAL_THRESHOLD` to a lower value
- Check if `FILTER_PROXY_VAR` has sufficient variation

