args mod i

global root "..." /*Insert path to main folder */
do "${root}\stata\macros.do"
do "${root}\stata\settings.do"

do "${root}\stata\models.do" "`mod'"

* run modelling without sampling to botain model objects
use "${root}\original_data\original_${site}.dta", clear
capt _return drop synth_sequential_models
synth_sequential_models_stpm3, 														///
	sequence(${sequence})															///
	continuous(age) continuous_winsor(${winsor}) continuous_df(${dfcont}) 			///
	diag_year(${daar_var}) diag_year_grp_length(${daar_grp_length})					///
	stpm3_tvc(${tvc}) ${stpm3_dftvc} stpm3_df(${df})								///
	simulated_count(0) 																///
	level(${level}) interactions(${interactions}) interactions_3w(${interaction_3w}) ///
	censoring_date(${censoring_date}) 												///
	model_only
_return hold synth_sequential_models

* retrieve sampled coefficients for importance sampling 
local mods = "${sequence} stpm3"
foreach m of local mods{
	use "${data}\sample_beta\b_sample_disclosure_${prefix}`m'_`mod'_`i'.dta", clear
	mkmat *, matrix(b_sample_disclosure_`m'_`mod')
	matrix b_sample_disclosure_`m' =  b_sample_disclosure_`m'_`mod'
}

* retrieve knot locations and spline matrices
_return restore synth_sequential_models, hold
local cont = "`r(continuous)'"
foreach c of local cont {
	local knots = `"`knots'"`r(`c'_knots)'""'
	local cutoff_high = `"`cutoff_high'"`r(`c'_cutoff_high)'""'
	local cutoff_low = `"`cutoff_low'"`r(`c'_cutoff_low)'""'
	local mod_knots = `"`mod_knots'"`r(mod_`c'_knots)'""'
	
	matrix Rmod_`c' = r(Rmod_`c')
	matrix R`c'_splines = r(R`c'_splines)
}

* Calculate likelihoods p(Z|theta^(h)), p(Y|theta^(h)), p(Y_{-i}^*|theta^(h))
* First calculate likelihood for all possible cominations of covariates, before 
* calculating the likelihood for the observed/synthetic follow-up times. 
loc h = 1
while `h' <= $Hmax {
	
	* calculate p(D|theta^(h)) for all combinations of covatiates, excl. follow-up-time
	use "${data}\privacy_risk\scenarios_cov_${site}.dta", clear
	synth_calc_p_cov, sequence(${sequence}) disclosure h(`h') ///
		knots(`"`knots'"') mod_knots(`"`mod_knots'"') ///
		cutoff_high(`"`cutoff_high'"') cutoff_low(`"`cutoff_low'"')
	save "${data}\importance_sampling\pi_h`h'_cov_`mod'_`i'.dta", replace

	* calculate p_td

	* calculate p(Y_{-i}^*|theta^(h)) for observed follow-up with all candidates for covariates
	_return restore synth_sequential_models, hold
	local cont = "`r(continuous)'"
	use "${data}\privacy_risk\test_scenarios_cov_${site}.dta", clear

	synth_calc_p_td, sequence(${sequence}) continuous(`cont') disclosure h(`h') interactions(${interactions}) ///
		knots(`"`knots'"') mod_knots(`"`mod_knots'"') ///
		cutoff_high(`"`cutoff_high'"') cutoff_low(`"`cutoff_low'"')
		
	count if mi(p_td)
	*resample theta(h) if necessary
	if r(N) > 0 {
		save "${data}\importance_sampling\simulated_pi_h`h'_td_resampeled_`mod'_`i'.dta", replace
		local mods = "${sequence} stpm3"
		foreach m of local mods{
			synth_sample_beta_h `m', h(`h')
		}
		log using "${root}\stata\synth_models.log", append
		di as error "Missing p_td original data: Resampling b(h) for model $name h = `h'"
		log close
		continue
	}
	
	
	keep id k_id ${sequence} _t p_td correct
	save "${data}\importance_sampling\scenarios_original_pi_h`h'_td_`mod'_`i'.dta", replace


	* calculate p(Z|theta^(h)) for follow-up 
	_return restore synth_sequential_models, hold
	local cont = "`r(continuous)'"
	use "${root}\simulated_data\simulated_${name}`i'.dta", clear
	recode stage (. = 999)

	synth_calc_p_td, sequence(${sequence}) continuous(`cont') disclosure h(`h') interactions(${interactions}) ///
		knots(`"`knots'"') mod_knots(`"`mod_knots'"') ///
		cutoff_high(`"`cutoff_high'"') cutoff_low(`"`cutoff_low'"')
	
	count if mi(p_td)
	*resample theta(h) if necessary
	if r(N) > 0 {
		save "${data}\importance_sampling\simulated_pi_h`h'_td_resampeled_`mod'_`i'.dta", replace
		local mods = "${sequence} stpm3"
		foreach m of local mods{
			synth_sample_beta_h `m', h(`h')
		}
		log using "${root}\stata\synth_models.log", append
		di as error "Missing p_td synthetic data: Resampling b(h) for model $name h = `h'"
		log close
		continue
	}

	keep id ${sequence} _t p_td
	save "${data}\importance_sampling\simulated_${site}_pi_h`h'_td_`mod'_`i'.dta", replace
	
	loc ++h
}

* calculating likelihoods from probabilities
do "${root}\stata\maximum_local_privacy_loss\calc_prob_stage.do" "`mod'" "`i'"
save "${data}\privacy_risk\risk_stage_${name}`i'.dta", replace
frame change default

* Delete intermediate steps
capt rm "${data}\importance_sampling\R_i_stage_`mod'_`i'.dta"
capt rm "${data}\importance_sampling\R_i_H_stage_`mod'_`i'.dta"

forvalues h = 1/$Hmax {
	capt rm "${data}\importance_sampling\simulated_${site}_pi_h`h'_td_`mod'_`i'.dta"
	capt rm "${data}\importance_sampling\pi_h`h'_cov_`mod'_`i'.dta"
	capt rm "${data}\importance_sampling\scenarios_original_pi_h`h'_td_`mod'_`i'.dta"
}

