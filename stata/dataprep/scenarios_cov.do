
frames reset   
use "${root}\original_data\original_${site}.dta", clear

frame create scenarios

qui su age
frame scenarios: range age `r(min)' `r(max)' `=`r(max)'+1-`r(min)''

qui su sex
frame scenarios: range sex `r(min)' `r(max)' `=`r(max)'+1-`r(min)''

levelsof ${daar_var}
loc ndaar = r(r)
di `ndaar'
qui su ${daar_var}
frame scenarios: range ${daar_var} `r(min)' `r(max)' `ndaar'

tab stage
frame scenarios: range stage 1 `r(r)' `r(r)'
frame scenarios: recode stage (4 = 999)

frame change scenarios
fillin _all
drop if missing(age,sex,${daar_var},stage)
drop _fillin

replace age = round(age)

save "${data}\privacy_risk\scenarios_cov_${site}.dta", replace
frame change default


use "${root}\original_data\original_${site}.dta", clear

rename stage stage_id

gen stage = .
qui tab stage_id
expand `r(r)' if mi(stage)
bysort id stage : replace stage = _n if mi(stage)
recode stage (4 = 999)

by id: gen k_id = _n

gen correct = (stage == stage_id)

save "${data}\privacy_risk\test_scenarios_cov_${site}.dta", replace