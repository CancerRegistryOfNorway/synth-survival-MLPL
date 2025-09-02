program synth_surv_vars_program_stpm3, rclass

	syntax, 						///
		sequence(varlist)			///
		continuous(varlist) 		///
		[define_splines]			///
		[make_splines]				///
		[continuous_df(integer 4)]  ///
		[interactions(varlist)]		///
		[interactions_3w(varlist)]	///
		[stpm3_tvc(varlist)]		///
		[knots(str)]				///
		[cutoff_high(str)]			///
		[cutoff_low(str)]
	
	local count_continuous = 0
	
	foreach v of local sequence {
	
		local i : list v in continuous

		if `i'{
			local ++count_continuous

			tokenize `"`knots'"'
			local `v'_knots = "``count_continuous''"
			
			tokenize `"`cutoff_high'"'
			local `v'_cutoff_high = "``count_continuous''"
			
			tokenize `"`cutoff_low'"'
			local `v'_cutoff_low = "``count_continuous''"
			
			gen `v'_adj = clip(`v', ``v'_cutoff_low' , ``v'_cutoff_high' )
			if "`define_splines'" == "define_splines"{
				rcsgen `v'_adj, knots(``v'_knots') gen(`v'_rcs) orthog
				matrix R`v'_splines = r(R)
			} 
			else if "`make_splines'" == "make_splines" {
				rcsgen `v'_adj, knots(``v'_knots') gen(`v'_rcs) rmatrix(R`v'_splines)
			}
			

			local vars = "`vars' @ns(`v', df(`continuous_df') winsor(``v'_cutoff_low' ``v'_cutoff_high', values))"
			
			local t : list v in stpm3_tvc
			if (`t') local vars_tvc = "`vars_tvc' @ns(`v', df(`continuous_df') winsor(``v'_cutoff_low' ``v'_cutoff_high', values))"
			
			local t : list v in interactions
			if (`t'){
				local len_inter : word count `vars_inter'
				if `len_inter' > 0 {
					
					qui ds `vars_inter'
					local len : word count `r(varlist)'
					tokenize `r(varlist)'
				
					forvalues i = 1/`len' {
						local cont : list `i' in continuous
						if `cont' {
							local inter = "`inter'  @ns(`v', df(`continuous_df') winsor(``v'_cutoff_low' ``v'_cutoff_high', values))#@ns(``i'', df(`continuous_df') winsor(```i''_cutoff_low' ```i''_cutoff_high', values))"
						}
						else {
							local inter = "`inter'  @ns(`v', df(`continuous_df') winsor(``v'_cutoff_low' ``v'_cutoff_high', values))#``i''"
						}
					}
				}
				local vars_inter = "`vars_inter' `v'"
			}
			
			local t : list v in interactions_3w
			if (`t'){
				local len_inter : word count `vars_inter3'
				if `len_inter' > 1 {
					local len : word count `vars_inter3_pairs'
					
					forvalues i = 1/`len' {
						local inter3 = "`inter3' @ns(`v', df(`continuous_df') winsor(``v'_cutoff_low' ``v'_cutoff_high', values))#`vars_inter3_pairs`i''"
					}
					
				}
				if `len_inter' > 0 {
					qui ds `vars_inter3'
					local len : word count `r(varlist)'
					tokenize `r(varlist)'
					
					local len_pairs : word count `vars_inter3_pairs'
					
					forvalues i = 1/`len' {
						local ++len_pairs
						local vars_inter3_pairs = "`vars_inter3_pairs' `v'#``i''"
						local cont : list `i' in continuous
						if `cont' {
							local vars_inter3_pairs`len_pairs' = "@ns(`v', df(`continuous_df') winsor(``v'_cutoff_low' ``v'_cutoff_high', values))#@ns(``i'', df(`continuous_df') winsor(```i''_cutoff_low' ```i''_cutoff_high', values))"
						}
						else {
							local vars_inter3_pairs`len_pairs' = "@ns(`v', df(`continuous_df') winsor(``v'_cutoff_low' ``v'_cutoff_high', values))#i.``i''"
						}
					}
					
				}
				local vars_inter3 = "`vars_inter3' `v'"
			}
			
		}
		else {
			
			local t : list v in interactions
			if (`t'){
				
				local len_inter : word count `vars_inter'
				if `len_inter' > 0 {
					qui ds `vars_inter'
					local len : word count `r(varlist)'
					tokenize `r(varlist)'
				
					forvalues i = 1/`len' {
						local cont : list `i' in continuous
						if `cont' {
							local inter = "`inter'  i.`v'#@ns(``i'', df(`continuous_df') winsor(```i''_cutoff_low' ```i''_cutoff_high', values))"
						}
						else {
							local inter = "`inter' i.`v'#i.``i''"
						}
					}
				}
				local vars_inter = "`vars_inter' `v'"
			} 
			
			local t : list v in interactions_3w
			if (`t'){
				local len_inter : word count `vars_inter3'
				if `len_inter' > 1 {
					local len : word count `vars_inter3_pairs'
					
					forvalues i = 1/`len' {
						local inter3 = "`inter3' i.`v'#`vars_inter3_pairs`i''"
					}
					
				}
				if `len_inter' > 0 {
					qui ds `vars_inter3'
					local len : word count `r(varlist)'
					tokenize `r(varlist)'
					
					local len_pairs : word count `vars_inter3_pairs'
					
					forvalues i = 1/`len' {
						local ++len_pairs
						local vars_inter3_pairs = "`vars_inter3_pairs' `v'#``i''"
						local cont : list `i' in continuous
						if `cont' {
							local vars_inter3_pairs`len_pairs' = "i.`v'#@ns(``i'', df(`continuous_df') winsor(```i''_cutoff_low' ```i''_cutoff_high', values))"
						}
						else {
							local vars_inter3_pairs`len_pairs' = "i.`v'#i.``i''"
						}
					}
					
				}
				local vars_inter3 = "`vars_inter3' `v'"
			}
			
			local vars = "`vars' i.`v'"
			
			local t : list v in stpm3_tvc
			if (`t') local vars_tvc = "`vars_tvc' i.`v'"
			
		}
	}
	
	
	return local vars "`vars'"
	return local inter "`inter' `inter3'"
	return local vars_tvc "`vars_tvc'"
			
end