args mod i


* Iterate over sampled parameters theta(h)
capt frame drop H_results
frame create H_results
frame change H_results
set obs $Hmax
gen H = _n

cross using "${data}\privacy_risk\test_scenarios_cov_${site}.dta"
sort id k_id H

gen log_p_h = .
gen pi_ratio = .
gen pi_k = .
gen pi_i = .
frame change default 


forvalues H = 1/$Hmax {
	di `H'
	* Calculate p(Z|theta(h))

	use "${data}\importance_sampling\simulated_${site}_pi_h`H'_td_`mod'_`i'.dta", clear

	qui merge m:1 age sex $daar_var stage using "${data}\importance_sampling\pi_h`H'_cov_`mod'_`i'.dta"
	assert inlist(_merge,2,3)
	drop if _merge == 2
	drop _merge 
	
	gen pi = p_cov*p_td
	
	replace pi = 0 if mi(pi)
	qui su pi
	if `r(min)' > 0{
		egen double log_p_h = total(ln(pi))
		local p_Z = log_p_h[1]

		frame H_results: replace log_p_h = `p_Z' if H == `H'
	}
	else {
		frame H_results: replace log_p_h = . if H == `H'
		di as error "log_p_h missing! (simulated sample with p = 0)"
	}

	* Calculate ratio p(y*|theta(h))/p(y_i|theta(h))
	use "${data}\importance_sampling\scenarios_original_pi_h`H'_td_`mod'_`i'.dta", clear 

	qui merge m:1 age sex $daar_var stage using "${data}\importance_sampling\pi_h`H'_cov_`mod'_`i'.dta", keep(match) nogen 
	
	replace p_cov = p_sex*p_stage*p_${daar_var} if p_age == 0 // p_age cancels out because it is idependent of stade
	
	gen pi = p_cov*p_td
	replace pi = 0 if mi(pi) & correct == 0
	assert !mi(pi)

	gen pi_i_h = pi if correct
	bysort id (pi_i_h) : replace pi_i_h = pi_i_h[1]

	rename pi pi_k_h
	gen pi_ratio_h = pi_k_h/pi_i_h
	gen H = `H'

	save "${data}\importance_sampling\R_i_H_stage_`mod'_`i'.dta", replace

	frame change H_results

	qui merge 1:1 H id k_id using "${data}\importance_sampling\R_i_H_stage_`mod'_`i'.dta", ///
	keepusing(pi_ratio_h pi_k_h pi_i_h) assert(match master) nogen 
	
	replace pi_ratio = pi_ratio_h if mi(pi_ratio)
	replace pi_k = pi_k_h if mi(pi_k)
	replace pi_i = pi_i_h if mi(pi_i)
	drop pi_ratio_h pi_k_h pi_i_h

	frame change default 
}


frame change H_results
save "${data}\importance_sampling\R_i_stage_`mod'_`i'.dta", replace

* Sum ratios over H for each y*
egen double pi_ratio_H = total(pi_ratio), by(k_id id)

egen double inv_pi_i_H = total(1/pi_i), by(k_id id)

gen p = pi_ratio_H/inv_pi_i_H

gen log_q_h = ln(pi_ratio/pi_ratio_H)
gen log_pq_h_all = log_p_h + log_q_h

* Sum weighted probabilities over H using log-sum-exp

gen eZ_h = 0 if mi(log_pq_h_all)

count if !mi(log_pq_h_all)
if `r(N)' > 0 {
	su log_pq_h_all
	local c = `r(max)'
	replace eZ_h = exp(log_pq_h_all - `c') if !mi(log_pq_h_all)
	
	egen eZ = total(eZ_h), by(k_id id)
	gen CU_i_logZ_all = `c' + ln(eZ)
}
else {
	gen eZ = 0
	gen CU_i_logZ_all = .
}

save "${data}\importance_sampling\R_i_stage_`mod'_`i'.dta", replace
bysort id k_id : keep if _n == 1

* Normalize probabilites over kandidates y* 

egen CU_i_logZ_all_max =  max(CU_i_logZ_all), by(id)
egen denom = total(exp(CU_i_logZ_all - CU_i_logZ_all_max)), by(id)
gen probability = exp(CU_i_logZ_all - CU_i_logZ_all_max)/denom

replace probability = 0 if mi(probability)

egen tot_p = total(p), by(id)
gen prior = p/tot_p

gsort id -probability -correct
gen sortvar = _n
bysort id (sortvar) : gen rank = _n

gen prob_prior = probability*prior
egen tot_prob_prior = total(prob_prior), by(id)
replace prob_prior = prob_prior/tot_prob_prior

gsort id -prob_prior -correct
replace sortvar = _n
bysort id (sortvar) : gen rank_prior = _n

keep sex age ${daar_var} id status _t stage correct CU_i_logZ_all probability prior rank prob_prior rank_prior




