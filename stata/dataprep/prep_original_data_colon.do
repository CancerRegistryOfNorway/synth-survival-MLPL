
use "${root}\original_data\datasett_colon_til_syntetisering.dta", clear

drop if STATUS == "E"

gen daar = year(diag_date)

keep if daar >= $start_year & daar <= $end_year & diag_date < ${censoring_date}

gen x = mod(daar, ${daar_grp_length})
gen daar_grp = daar-x
drop x


// Adding follow-up time and event indicator
replace STATUS = "B" if ( STATUSDATO > $censoring_date )  
replace STATUSDATO = $censoring_date if ( STATUSDATO > $censoring_date )

clonevar exit = STATUSDATO 
gen id = _n

rename STATUS tilstand

gen byte status = ( tilstand == "D" ) 
drop tilstand SID_surv PERSONLOEPENR STATUSDATO

// Reformat vital status coding to binary dead/alive coding
drop if exit < $censoring_date & status == 0

recode stage (. = 999)

// stset data to assign as time-to-event in stata
stset exit, id(id) fail(status == 1)  ///
			exit(time ${censoring_date}) ///
			scale(365.25) origin(diag_date)
keep if _st == 1


label save using "${dataprep}\labels.do", replace


save "${root}\original_data\original_colon.dta", replace 
