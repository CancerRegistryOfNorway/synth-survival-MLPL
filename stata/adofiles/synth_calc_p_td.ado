
program synth_calc_p_td

	syntax , 							///
		sequence(passthru)				///
		continuous(passthru) 			///
		[interactions(passthru)] 		///
		[interactions_3w(passthru)]		///
		[h(passthru)]					///
		[knots(passthru)]				///
		[mod_knots(passthru)]			///
		[cutoff_high(passthru)]			///
		[cutoff_low(passthru)]			///
		[disclosure]
	
	if ("`disclosure'" == "" & "`h'" != ""){
		display as error "Need to use option disclosure when specifying sample h()"
		exit
	}
	
	synth_surv_vars_program_stpm3, make_splines ///
		`sequence' `continuous' `interactions' `interactions_3w' ///
		`knots' `cutoff_high' `cutoff_low'
	
	if ("`disclosure'" == "disclosure") synth_replace_beta stpm3, `h'
	else estimates restore mod_stpm3
	
	predict h if status == 1, hazard timevar(_t) merge
	predict s, survival timevar(_t) merge
	
	gen p_td = .
	replace p_td = s if status == 0
	replace p_td = h*s if status == 1
	
	*drop s h
	
end


program synth_replace_beta, eclass

	syntax anything, h(integer)
	
	estimates restore mod_`anything'
	
	matrix b_sample = b_sample_disclosure_`anything'[`h',....]
	ereturn repost b = b_sample
	
end
