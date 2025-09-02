
use "${root}\original_data\pancreas_2023.dta", clear

rename S_diagnosear daar
rename S_diagnosedato diag_date
rename S_alderDiagnose age
rename P_status STATUS
rename P_statusdato STATUSDATO
rename S_seerStadium stage

gen sex = P_kjonn == "M"

drop if STATUS == "E"
drop if age > 89
recode stage (9 = .) 

keep if daar >= $start_year & daar <= $end_year & diag_date < ${censoring_date}

gen x = mod(daar, ${daar_grp_length})
gen daar_grp = daar-x
drop x


// Adding follow-up time and event indicator
replace STATUS = "B" if ( STATUSDATO > $censoring_date )  
replace STATUSDATO = $censoring_date if ( STATUSDATO > $censoring_date )

clonevar exit = STATUSDATO 
gen id = _n

gen byte status = ( STATUS == "D" ) 
drop sykdomstilfellenr STATUSDATO STATUS P_kjonn

// Reformat vital status coding to binary dead/alive coding
drop if exit < $censoring_date & status == 0

recode stage (. = 999)

// stset data to assign as time-to-event in stata
stset exit, id(id) fail(status == 1)  ///
			exit(time ${censoring_date}) ///
			scale(365.25) origin(diag_date)
keep if _st == 1

save "${root}\original_data\original_pancreas.dta", replace 
