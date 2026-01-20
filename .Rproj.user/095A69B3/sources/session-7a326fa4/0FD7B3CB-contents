# 1. checking packages
if (!requireNamespace("devtools", quietly = TRUE)) {
  install.packages("devtools")
}
cran_pkgs <- c(
  "writexl", "readr", "gdata", "tidyverse", "rlang", 
  "dplyr", "formattable", "data.table", "hablar", 
  "tidyr", "readxl", "purrr" 
)
installed <- rownames(installed.packages())
to_install <- setdiff(cran_pkgs, installed)
if (length(to_install) > 0) {
  install.packages(to_install, dependencies = TRUE)
}
if (!"analysistools" %in% installed) {
  devtools::install_github("impact-initiatives/analysistools")
}



library(writexl)
library(readr)
library(gdata)
library(tidyverse)
library(rlang)
library(dplyr)
library(formattable)
library(data.table)
library(hablar)
library(tidyr)
library(readxl)
library(purrr)
library(analysistools)

source('helpers.R')
source('0_variable_definition.R') ## IMPORTANT to UPDATE: file paths and language-label / strata (and if names where used instead of label)
source('1_preparation.R')
source('2_analysis.R') 
