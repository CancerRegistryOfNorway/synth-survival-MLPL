
********************************************************************************
* Masterfile for generation and evaluation of synthetic time-to-event data
********************************************************************************

clear all

global root "..." /*Insert path to main folder */
set scheme stcolor

do "${root}\stata\macros.do"
do "${root}\stata\settings.do"
set seed 2

* Dataprep
do "${dataprep}\prep_original_data_${site}.do" 

* Export to csv
use "${root}\original_data\original_${site}.dta", clear
label drop _all
outsheet * using "${root}\python\input\\${site}_original.csv", comma replace  

* Generate synthetic data from models
do "${root}\stata\generation\generate.do"

* Generate synthetic data from resampling
do "${root}\stata\generation\resampling.do"

* Privacy risk evaluation
do "${root}\stata\maximum_local_privacy_loss\risk_evaluation.do"
do "${root}\stata\maximum_local_privacy_loss\plot_posteriors.do"

* Utility metrics(requires that XGBoost propensity score has been run)
do "${root}\stata\utility\utility.do"

* Similarity based privacy metrics
do "${root}\stata\similarity_based_privacy\privacy.do"