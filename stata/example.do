
graph set window fontface "Aptos"

set scheme white_tableau

clear
set seed 2

set obs 100

gen id  = _n
gen grp = runiformint(1,2)

gen diag = runiformint(1,365*20)
replace diag = diag/365

tab grp, gen(grp)

survsim T , d(w) lambda(0.05) gamma(1) covariates(grp2 2.5)

gen t = min(20, diag+T)
gen status = (t < 20)

stset t, failure(status) origin(diag) 

replace grp = 1 if id == 1
replace grp1 = 0 if id == 1
replace grp2 = 1 if id == 1
replace diag = 0 if id == 1
replace T = 20 if id == 1
replace _t = T if id == 1
replace _d = 0 if id == 1

clonevar Group = grp 

sts graph , by(Group)   name(sim, replace) censored(s) legend(rows(1) pos(12)) title("Kaplan-Meier survival estimate", size(*0.7))
graph display, scale(*2) xsize(5) ysize(4)
graph export "${results}\export\example_sim.emf", replace

tab status Group

replace Group = 2 if id == 1
replace grp = 2 if id == 1

sts graph, by(Group) name(outlier, replace) censored(s) legend(rows(1) pos(12)) title("Kaplan-Meier survival estimate", size(*0.7))
graph display, scale(*2) xsize(5) ysize(4)
graph export "${results}\export\example_outlier.emf", replace


gen daar = 2000

save "${data}\example\orig.dta", replace


set seed 19

use "${data}\example\orig.dta", clear
global censoring_date = d(31dec2020)
local N = _N
capt _return drop synth_sequential_models
synth_sequential_models_stpm3, 														///
	sequence(grp)																	///
	continuous(id) 																	///
	diag_year(daar) diag_year_grp_length(20)										///
	stpm3_df(4)																		///
	simulated_count(`N') 															///
	level("main")  																	///
	censoring_date(${censoring_date}) 												///
	save("${root}\simulated_data\simulated_example.dta")
	

clonevar Group = grp
sts graph, by(Group) name(synth, replace) censored(s) legend(rows(1) pos(12)) title("Kaplan-Meier survival estimate", size(*0.7))
graph display, scale(*2) xsize(5) ysize(4)
graph export "${results}\export\example_synth.emf", replace


keep grp status id _st _d _origin _t _t0 diagdate exit 

estimates restore mod_grp 
predict p*

gen pgrp = p1 if grp == 1
replace pgrp = p2 if grp == 2
drop p?

estimates restore mod_stpm3

predict h if status == 1, hazard timevar(_t) merge
predict s, survival timevar(_t) merge

gen p_td = .
replace p_td = s if status == 0
replace p_td = h*s if status == 1

gen p = pgrp*p_td

drop pgrp-p_td

save "${root}\simulated_data\simulated_example_p.dta", replace 



use "${data}\example\orig.dta", clear
replace grp = 1 if id == 1
global censoring_date = d(31dec2020)
local N = _N
capt _return drop synth_sequential_models
synth_sequential_models_stpm3, model_only 											///
	sequence(grp)																	///
	continuous(id) 																	///
	diag_year(daar) diag_year_grp_length(20)										///
	stpm3_df(4)																		///
	simulated_count(`N') 															///
	level("main")  																	///
	censoring_date(${censoring_date}) 												///
	
use "${root}\simulated_data\simulated_example_p.dta", clear 

estimates restore mod_grp 
predict p`v'*

gen pgrp = p1 if grp == 1
replace pgrp = p2 if grp == 2
drop p?

estimates restore mod_stpm3

predict h if status == 1, hazard timevar(_t) merge
predict s, survival timevar(_t) merge

gen p_td = .
replace p_td = s if status == 0
replace p_td = h*s if status == 1

gen p_grp1 = pgrp*p_td

drop pgrp-p_td

save "${root}\simulated_data\simulated_example_p.dta", replace


egen p_tot = total(ln(p))
egen p1_tot = total(ln(p_grp1))

gen c = abs(p_tot - p1_tot)

gen p2_uniform = exp(p_tot)/(exp(p_tot) + exp(p1_tot))

