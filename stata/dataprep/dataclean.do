args dataset variables
use "${root}\simulated_data\\`dataset'.dta", clear 

*===============================================================================
// clean and format any variables which are going to be preserved in the final
// simulated dataset 

do "${dataprep}\labels.do"

capt confirm variable stage
if _rc == 0{
	label values (stage) stage
	replace stage = . if stage == 999
	tab stage, mi
}

capt confirm variable sex
if _rc == 0{
	label values (sex) sex 
	tab sex, mi
}

capt confirm variable $daar_var
if _rc == 0{
	su $daar_var
}

capt confirm variable age
if _rc == 0{
	su age 
}

tab status, mi

rename diagdate diag_date
clonevar STATUSDATO = exit
		
gen STATUS = "D" if status == 1
replace STATUS = "B" if status == 0
assert !mi(STATUS)

// keep only variables required for synthetic dataset 
keep `variables' STATUS STATUSDATO diag_date yrdx id status exit uage

stset exit, id(id) fail(status == 1)  ///
			exit(time ${censoring_date}) ///
			scale(365.25) origin(diag_date)


save "${root}\simulated_data\\`dataset'.dta", replace 