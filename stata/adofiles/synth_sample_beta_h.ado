program synth_sample_beta_h
	
	syntax anything , h(integer)
	
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
		matrix V_sub = V_sub/(e(rmse))^2*`sigma'^2
		frame coefs : drawnorm var1-var`=colsof(b_sub)', means(b_sub) cov(V_sub) n(1) double
	}
	else {
		frame coefs : drawnorm var1-var`=colsof(b_sub)', means(b_sub) cov(V_sub) n(1) double
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

	matrix temp_res = b 

	local names : colfullnames temp_res
	local names_b : colfullnames b_sample_sub

	capt matrix drop b_sample
	tokenize `names'
	forvalues i = 1/`=colsof(temp_res)'{
		if `: list i in local names_b'{
			matrix b_sample = (nullmat(b_sample), b_sample_sub[1....,"`i'"])
		}
		else {
			matrix b_sample = (nullmat(b_sample), temp_res[1....,"``i''"])
		}
	}

	matrix colnames b_sample = `names'
	
	if (`h' > 1 & `h' < ${Hmax}) {
		matrix b_sample_disclosure_`anything' = b_sample_disclosure_`anything'[1..`=`h'-1',....] \ b_sample \ b_sample_disclosure_`anything'[`=`h'+1'..${Hmax},....] 
	}
	else if (`h' == 1){
		matrix b_sample_disclosure_`anything' = b_sample \ b_sample_disclosure_`anything'[2..${Hmax},....] 
	}
	else if (`h' == ${Hmax}){
		matrix b_sample_disclosure_`anything' = b_sample_disclosure_`anything'[1..`=`h'-1',....] \ b_sample 
	}
end