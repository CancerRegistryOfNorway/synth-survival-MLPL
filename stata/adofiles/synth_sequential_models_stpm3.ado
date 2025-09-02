program synth_sequential_models_stpm3, rclass

	syntax , 							///
		sequence(varlist)				///
		continuous(varlist) 			///
		diag_year(varlist)				///
		[diag_year_grp_length(integer 1)]	///
		[save(str)]						///
		simulated_count(integer) 		///
		level(str) 						///
		censoring_date(integer) 		///
		[continuous_winsor(integer 0)] 	///
		[continuous_df(integer 4)] 		///
		[stpm3_df(integer 5)] 			///
		[dftvc(passthru)] 				///
		[stpm3_tvc(passthru)] 			///
		[sample_beta]					///
		[disclosure]					///
		[disclosure_H(passthru)]		///
		[interactions(varlist)]			///
		[interactions_3w(varlist)]		///
		[models_in_memory(str)]			///
		[model_only]
	
	*===========================================================================
	

	local N = _N
	
	return scalar N = `simulated_count'
	return local sequence "`sequence'"
	return local continuous "`continuous'"
	return local level "`level'"
	
	if ("`level'" != "inter" & "`interactions'" != ""){
		di as error "Cannot specify interactions when level is not inter"
		exit
	}
	
	if ("`level'" == "inter" & "`interactions'" == "" & "`interactions_3w'" == "") local interactions = "`sequence'"
	if ("`level'" == "inter") return local interactions "`interactions'"
	
	if ("`stpm3_tvc'" != "") {
		return local tvc "`stpm3_tvc'"
		return local dftvc "`stpm3_dftvc'"
	}
	
	foreach v of local sequence {
		assert !mi(`v')
	}
	
	qui su `diag_year'
	loc `diag_year'_min = `r(min)'

	*===========================================================================
	// Fit survival model

	// Winsorize continuous variables and specify knots for splines 
	local num = 1
	foreach v of local continuous {
		if `continuous_winsor' > 0 {
			_pctile `v', per(`continuous_winsor' `=100-`continuous_winsor'')
			local `v'_cutoff_low `r(r1)'
			local `v'_cutoff_high `r(r2)'
			
			return scalar continuous_winsor = `continuous_winsor'
		}
		else {
			qui su `v'
			local `v'_cutoff_low `r(min)'
			local `v'_cutoff_high `r(max)'
		}
		
		return scalar `v'_cutoff_low = ``v'_cutoff_low'
		return scalar `v'_cutoff_high =  ``v'_cutoff_high'
		
		_pctile `v', nquantiles(`continuous_df')
		
		local `v'_knots = "``v'_cutoff_low'" 
		forvalues i = 1/`=`continuous_df'-1'{
			local `v'_knots = "``v'_knots' `r(r`i')'"
		}
		local `v'_knots = "``v'_knots' ``v'_cutoff_high'"
		
		return local `v'_knots "``v'_knots'"

		local knots = `"`knots'"``v'_knots'""'
		local cutoff_high = `"`cutoff_high'"``v'_cutoff_high'""'
		local cutoff_low = `"`cutoff_low'"``v'_cutoff_low'""'
	}

	// generate dummy variables and interaction terms
		
	if ("`models_in_memory'" != ""){	
		_return restore `models_in_memory', hold
		
		foreach v of local continuous {
			local mod_`v'_knots = "`r(mod_`v'_knots)'"
			
			summarize `v'
			local `v'min = `r(min)'
			local `v'max = `r(max)'
			
			return local mod_`v'_knots "`mod_`v'_knots'"
			return matrix Rmod_`v' = Rmod_`v', copy
		}
		
	}
	else{
		
		synth_surv_vars_program_stpm3, define_splines ///
		sequence(`sequence') continuous(`continuous') continuous_df(`continuous_df') interactions(`interactions') interactions_3w(`interactions_3w') `stpm3_tvc' ///
		knots(`"`knots'"') cutoff_high(`"`cutoff_high'"') cutoff_low(`"`cutoff_low'"')
		
		if ("`level'" == "inter") {
			local regvars = "`r(vars)' `r(inter)'"
			local tvcvars = "`r(vars_tvc)'"
		}
		else if ("`level'" == "main"){
			 local regvars = "`r(vars)'"
			 local tvcvars = "`r(vars_tvc)'"
		}
		else if ("`level'" == "margin"){
			local regvars = ""
			local tvcvars = "`r(vars_tvc)'"
		} 
		
		// Fit  survival model
		#delim; 
		stpm3 `regvars' ,
			df(`stpm3_df') scale(lnhazard)
			tvc(`tvcvars') `dftvc' initmodel(weibull)
		;
		#delim cr
		estimates store mod_stpm3

		*===============================================================================
		// Model covariate distributions 

		local usedvars = ""
		local usedlist = ""
		local regs = ""
		foreach v of local sequence {

			local i : list v in continuous
			if `i'{
				// Save min/max for resampling of synthetic values
				summarize `v'
				local `v'min = `r(min)'
				local `v'max = `r(max)'
				
				// generate inverse normal rankings 
				capt drop rank
				local c: word count `usedvars'
				/*if `c' > 0{
					bysort `usedlist' : egen rank = rank(`v'), unique
					bysort `usedlist' : gen InvRankNorm`v' = invnormal((rank - 0.5)/_N)
				}
				else{
					egen rank = rank(`v'), unique
					gen InvRankNorm`v' = invnormal((rank - 0.5)/_N)
				}*/
				egen rank = rank(`v'), unique
				gen InvRankNorm`v' = invnormal((rank - 0.5)/_N)
				
				// fit splines and store R matrix 
				qui summarize InvRankNorm`v'
				local spacing = (`r(max)' - `r(min)')/8
				rcsgen InvRankNorm`v', knots(`r(min)'(`spacing')`r(max)') gen(rcs`v') orthog
				local mod_`v'_knots "`r(knots)'"
				matrix Rmod_`v' = r(R)
				return local mod_`v'_knots "`mod_`v'_knots'"
				return matrix Rmod_`v' = Rmod_`v', copy
				
				ds rcs`v'*
				local k `: word count `r(varlist)''

				tokenize `usedvars'
				local r = ""
				forvalues i = 1/`k'{
					forvalues j=1/`c'{
						local r = "`r' c.rcs`v'`i'##``j''"
					}
				}
				if ("`usedvars'" == "" | "`level'" == "margin") regress `v' rcs`v'*
				else if ("`level'" == "inter") regress `v' `r'
				else if ("`level'" == "main") regress `v' rcs`v'* `usedvars'
				estimates store mod_`v'
				
				local usedlist = "`usedlist' `v'"
				local usedvars = "`usedvars' c.`v'_rcs*"
				
				local t : list v in interactions
				if (`t'){
					local c: word count `inter_vars'
					if `c' > 0 {
						tokenize `inter_vars'
						forvalues j = 1/`c' {
							local reg_inter = "`reg_inter' c.`v'_rcs*#``j''"
						}
					}
					local inter_vars = "`inter_vars' c.`v'_rcs*"
				}
				
				local t : list v in interactions_3w
				if (`t'){
					local c: word count `inter_vars_3w'
					if `c' > 1 {
						local len: word count `inter_3w_pairs'
						forvalues j = 1/`len'{
							reg_inter = "`reg_inter' c.`v'_rcs*#``j''"
						}
					}
					if `c' > 0 {
						tokenize `inter_vars_3w'
						forvalues j = 1/`c' {
							local inter_3w_pairs = "`inter_3w_pairs' c.`v'_rcs*#``j''"
						}
					}
					local inter_vars_3w = "`inter_vars_3w' c.`v'_rcs*"
				}
				
				return matrix R`v'_splines = R`v'_splines, copy
		 
			}
			else{
				if ("`level'" == "inter") capt noisily mlogit `v' `usedvars' `reg_inter'
				else if ("`level'" == "main") capt noisily mlogit `v' `usedvars'
				else if ("`level'" == "margin") capt noisily mlogit `v'

				estimate store mod_`v'
				
				local usedlist = "`usedlist' `v'"
				local usedvars = "`usedvars' i.`v'"
				
				local t : list v in interactions
				if (`t'){
					local c: word count `inter_vars'
					if `c' > 0 {
						tokenize `inter_vars'
						forvalues j = 1/`c' {
							local reg_inter = "`reg_inter' i.`v'#``j''"
						}
					}
					local inter_vars = "`inter_vars' i.`v'"
				}
				
				local t : list v in interactions_3w
				if (`t'){
					local c: word count `inter_vars_3w'
					if `c' > 1 {
						local len: word count `inter_3w_pairs'
						tokenize `inter_3w_pairs'
						forvalues j = 1/`len'{
							local reg_inter = "`reg_inter' i.`v'#``j''"
						}
					}
					if `c' > 0 {
						tokenize `inter_vars_3w'
						forvalues j = 1/`c' {
							local inter_3w_pairs = "`inter_3w_pairs' i.`v'#``j''"
						}
					}
					local inter_vars_3w = "`inter_vars_3w' i.`v'"
				}
				
			}
		}
	}
	
	if ("`model_only'" == "model_only") exit
	if (`simulated_count' == 0 & "`disclosure'" == "") exit
	*===============================================================================
	// recreate covariate distributions from restored models 

	// clear dataframe, set simulation seed and set number of observations 
	clear 
	set obs `simulated_count'

	foreach v of local sequence {
		if ("`disclosure'" == "disclosure"){
			synth_sample_beta_disclosure `v', `disclosure_H'
			return add
		}

		if ("`sample_beta'" == "sample_beta") synth_sample_beta `v'
		else estimates restore mod_`v'

		if "`e(cmd)'" == "mlogit" & `simulated_count' > 0{
			// Predict category probabilities
			predict p`v'*
			su p`v'*
			matrix names = e(out)
			gen u`v' = runiform()

			qui ds p`v'*
			local n_`v': word count `r(varlist)'
			
			// Assign category number
			gen `v' = 0
			forvalues l = `n_`v''(-1)1 {
				egen cum_p`v' = rowtotal(p`v'1-p`v'`l')
				replace `v' = `l' if u`v' < cum_p`v'
				drop cum_p`v'
			}
			assert `v' > 0 & `v' <= `n_`v''
			
			// Recode back to original categories
			replace `v' = names[1,`v']
			tab `v'			 
			drop u`v' p`v'* 
		}
		if "`e(cmd)'" == "regress" & `simulated_count' > 0{
			gen `v' = 0
			
			gen u`v' = rnormal()
			rcsgen u`v', gen(rcs`v') knots(`mod_`v'_knots') rmatrix(Rmod_`v')
			predict `v'new
			replace `v' = `v'new
			*replace `v' = `v'new
			su `v'
			replace `v'  = clip(`v', ``v'min'-0.49999 , ``v'max'+0.49999)
			*drop u`v' rcs`v'* `v'new

			gen `v'_adj = clip(`v', ``v'_cutoff_low' , ``v'_cutoff_high' )
			rcsgen `v'_adj, gen(`v'_rcs) knots(``v'_knots') rmatrix(R`v'_splines)
			return matrix R`v'_splines = R`v'_splines, copy
			drop `v'_adj
			
			replace `v' = round(`v')
		}
	}

	*===============================================================================
	// restore survival model estimates and predict survival times
	if ("`disclosure'" == "disclosure"){
		synth_sample_beta_disclosure stpm3, `disclosure_H'
		return add
	}
	
	if ("`sample_beta'" == "sample_beta") synth_sample_beta stpm3
	else estimates restore mod_stpm3
	
	return local stpm3_cmdline "`e(cmdline)'"
	
	if (`simulated_count' > 0){
		gen U = runiform()*100
		predict t, centile(U, high(21) tol(1e-3)) merge

		// Round up to nearest full day
		gen t_days = ceil(t*365.25)
		replace t = t_days/365.25

		// generate date of diagnosis (uniformly across the year, not leap year)
		gen day = 365 + runiformint(1, 365)
		gen mmdx = month(day)
		gen dddx = day(day)
		
		capt confirm variable `diag_year'
		if (_rc != 0) gen `diag_year' = ``diag_year'_min'
		
		gen yrdx = `diag_year' + runiformint(0, `=`diag_year_grp_length'-1')
		qui su yrdx
		if (`r(max)' > year(`censoring_date')){
			qui su `diag_year'
			replace yrdx = `diag_year' + runiformint(0, `=year(`censoring_date')-`r(max)'') if `diag_year' > year(`censoring_date')
		}
		
		gen diagdate = mdy(mmdx,dddx,yrdx)

		// Resample diagdates on or after censoring date
		qui su diagdate 
		while `r(max)' >= `censoring_date'{
			replace day = 365 + runiformint(1, 365) if diagdate == `censoring_date'
			
			replace mmdx = month(day)
			replace dddx = day(day)
			replace yrdx = `diag_year' + runiformint(0, `=`diag_year_grp_length'-1')
			replace diagdate = mdy(mmdx,dddx,yrdx)
			qui summ diagdate 
		}

		assert diagdate < `censoring_date'

		gen exit = diagdate + t_days 
		format exit diagdate %d

		// implement censoring
		gen status = 1
		replace status = 0 if exit > `censoring_date'
		replace exit = `censoring_date' if exit > `censoring_date'

		// stset 
		gen id=_n
		stset exit, origin(diagdate) id(id) failure(status == 1) ///
				exit(time `censoring_date') scale(365.25)
				
		*===============================================================================	
		// save synthetic dataset 
		display "`save'"
		if ("`save'" != "") save "`save'", replace
	}
end

program synth_sample_beta, eclass
	
	syntax anything
	
	estimates restore mod_`anything'

	capt frame drop coefs
	frame create coefs
	if "`e(cmd)'" == "regress" {
		loc sigma = e(rmse)*(e(N)-e(df_m))/rchi2(e(N)-e(df_m))
		matrix V = e(V)/(e(rmse))^2*`sigma'^2
		frame coefs : drawnorm var1-var`=colsof(e(b))', means(e(b)) cov(V) n(1) 
		ereturn repost V = V
		ereturn scalar rmse = `sigma'
	}
	else {
		frame coefs : drawnorm var1-var`=colsof(e(b))', means(e(b)) cov(e(V)) n(1) 
	}
	
	
	if "`anything'" == "stpm2"{
		frame coefs : drop var`=colnumb(e(b),"_cons")+1'-var`=colsof(e(b))'
		loc j = colnumb(e(b),"_cons")
		forvalues i = `=colnumb(e(b),"_rcs1")'/`=colnumb(e(b),"_cons")-1' {
			loc ++j
			frame coefs : gen var`j' = var`i'
		}
	}
	
	frame coefs : mkmat _all, matrix(b_sample)
	frame drop coefs

	local names : colfullnames e(b)
	matrix colnames b_sample = `names'
	ereturn repost b = b_sample

end

program synth_sample_beta_disclosure, rclass

	syntax anything, [disclosure_H(integer 20)]
	
	estimates restore mod_`anything'
	
	matrix b = e(b)
	matrix V = e(V)
	matrix d = vecdiag(V)

	loc z_list ""
	forvalues i = 1/`=colsof(b)'{
		if b[1,`i'] != 0 | d[1,`i'] != 0{
			loc z_list = "`z_list' `i'"
		}
	}

	matselrc V V_sub, col(`z_list') row(`z_list')
	matselrc b b_sub, col(`z_list') row(1)
	matrix colnames b_sub = `z_list'

	capt frame drop coefs
	frame create coefs
	if "`e(cmd)'" == "regress" {
		loc sigma = e(rmse)*(e(N)-e(df_m))/rchi2(e(N)-e(df_m))
		matrix V = e(V)/(e(rmse))^2*`sigma'^2
		frame coefs : drawnorm var1-var`=colsof(e(b))', means(e(b)) cov(V) n(`disclosure_H') 
	}
	else {
		if (`=colsof(b_sub)' == 1) {
			frame coefs : drawnorm var1, means(b_sub) cov(V_sub) n(`disclosure_H') 
		}
		else {
			frame coefs : drawnorm var1-var`=colsof(b_sub)', means(b_sub) cov(V_sub) n(`disclosure_H') 
		}
	}

	if "`anything'" == "stpm2"{
		frame coefs : drop var`=colnumb(e(b),"_cons")+1'-var`=colsof(e(b))'
		loc j = colnumb(e(b),"_cons")
		forvalues i = `=colnumb(e(b),"_rcs1")'/`=colnumb(e(b),"_cons")-1' {
			loc ++j
			frame coefs : gen var`j' = var`i'
		}
	}

	frame coefs : mkmat _all, matrix(b_sample_sub)
	local names : colnames b_sub
	matrix colnames b_sample_sub = `names'

	matrix temp_res = J(1,`disclosure_H',1)' * b 

	local names : colfullnames temp_res
	local names_b : colfullnames b_sample_sub

	capt matrix drop b_sample_disclosure
	tokenize `names'
	forvalues i = 1/`=colsof(temp_res)'{
		if `: list i in local names_b'{
			matrix b_sample_disclosure = (nullmat(b_sample_disclosure), b_sample_sub[1....,"`i'"])
		}
		else {
			matrix b_sample_disclosure = (nullmat(b_sample_disclosure), temp_res[1....,"``i''"])
		}
	}

	frame drop coefs
	
	matrix colnames b_sample_disclosure = `names'
	return matrix b_sample_disclosure_`anything' = b_sample_disclosure
end