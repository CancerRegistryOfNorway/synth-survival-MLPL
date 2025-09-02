
program synth_calc_p_cov

	syntax , 					///
		sequence(varlist)		///
		[h(passthru)]			///
		[knots(str)]			///
		[mod_knots(str)]		///
		[cutoff_high(str)]		///
		[cutoff_low(str)]		///
		[disclosure]
	
	if ("`disclosure'" == "" & "`h'" != ""){
		display as error "Need to use option disclosure when specifying sample h()"
		exit
	}
		
	local count_continuous = 0

	gen p_cov = 1
	
	foreach v of varlist `sequence'{
	
		if ("`disclosure'" == "disclosure") synth_replace_beta `v', `h'
		else estimates restore mod_`v'


		if "`e(cmd)'" == "mlogit"{
			predict p`v'* 
			
			matrix names = e(out)
			
			gen p_`v' = .
			forvalues i = 1/`=colsof(names)' {
				replace p_`v' = p`v'`i' if `v' == names[1,`i']
			}
			
			drop p`v'* 
		}
		else if "`e(cmd)'" == "regress"{
			local ++count_continuous
			
			tokenize `"`knots'"'
			local `v'_knots = "``count_continuous''"
			
			tokenize `"`cutoff_high'"'
			local `v'_cutoff_high = "``count_continuous''"
			
			tokenize `"`cutoff_low'"'
			local `v'_cutoff_low = "``count_continuous''"
			
			tokenize `"`mod_knots'"'
			local mod_`v'_knots = "``count_continuous''"
			
			tokenize "`mod_`v'_knots'"
			matrix knot_matrix = `1'
			forvalues i = 2/9{
				matrix knot_matrix = knot_matrix,``i''
			}

			capt frame drop cont_calcs
			frame create cont_calcs
			frame change cont_calcs
			
			range x -4.5 4.5 10000
			rcsgen x, knots(`mod_`v'_knots') rmatrix(Rmod_`v') gen(rcs`v')
			
			predict pred_`v'
			gen `v'_round = round(pred_`v')
			
			frame change default
			
			capt frame drop p_age
			frame create p_age age p

			matrix b = e(b)
			loc rmse = `e(rmse)'

			forvalues i = 7(1)89{
				frame cont_calcs: qui su age_round
				if (`i'<`r(min)'){
					frame cont_calcs: qui su x if age_round == round(`r(min)')
					loc center = `r(mean)'
				}
				else if (`i'>`r(max)'){
					frame cont_calcs: qui su x if age_round == round(`r(max)')
					loc center = `r(mean)'
				}
				else {
					frame cont_calcs: qui su x if age_round == round(`i')
					loc center = `r(mean)'
				}
				
				if (abs(`center') > 2) loc tol = 2
				qui {
					if (abs(`center')< 1.8){
						mata : st_numscalar("r(p)", p_age(`i', st_matrix("knot_matrix"), st_matrix("Rmod_`v'"), st_matrix("b"), `rmse', `center', `tol'))
					}
					else {
						mata : st_numscalar("r(p)", p_age_round(`i', st_matrix("knot_matrix"), st_matrix("Rmod_`v'"), st_matrix("b"), `rmse', `center', `tol'))
					}
				}
				frame post p_age (`i') (`r(p)')
			}
						
			frame change p_age
			replace age = round(age)
			tempfile `v'_probs
			save ``v'_probs'

			frame change default
			frame drop p_age
			frame drop cont_calcs

			merge m:1 age using ``v'_probs',  nogen 

			rename p p_age

			gen `v'_adj = clip(`v', ``v'_cutoff_low' , ``v'_cutoff_high' )
			rcsgen `v'_adj, knots(``v'_knots') rmatrix(R`v'_splines) gen(`v'_rcs)
				
		}

		replace p_cov = p_cov * p_`v'
	}
	drop *_rcs* *_adj 
end

program synth_replace_beta, eclass

	syntax anything, [h(integer 20)]
	
	estimates restore mod_`anything'
	
	matrix b_sample = b_sample_disclosure_`anything'[`h',....]
	ereturn repost b = b_sample
	
end

mata 
real scalar ev(real scalar x, real matrix k, real matrix R, real matrix b)
{
	real rowvector v, d
	real scalar nk, i, lambda
	
	v = x
	nk = length(k)
	for (i = 2; i < nk; i++) {
		lambda = (k[nk] - k[i])/(k[nk]  - k[1])
		v = v , ((x-k[i])^3)*(x > k[i]) - ///
			lambda*((x-k[1])^3)*(x>k[1]) - ///
			(1-lambda)*((x-k[nk])^3)*(x>k[nk])  
	}
	v = v, 1
	
	d = v * luinv(R)[,1..8]
	d = d, 1
	
	return(d*b')
}
end


mata
real scalar agefunc(real scalar x, real matrix k, real matrix R, real matrix b, real scalar rmse, real scalar age)
{
	real scalar mu
	
	mu = ev(x, k, R, b)
	
	return(normalden(age,mu,rmse)*normalden(x))
}
end


mata
real scalar p_age(real scalar age, real matrix k, real matrix R, real matrix b, real scalar rmse, real scalar center, real scalar tol) 
{
	class Quadrature scalar S
	S = Quadrature()
	S.setEvaluator(&agefunc())
	S.setLimits((center-tol, center+tol))
	S.setAbstol(1e-14)
	S.setReltol(1e-14)

	S.setArgument(1, k)
	S.setArgument(2, R)
	S.setArgument(3, b)
	S.setArgument(4, rmse)
	S.setArgument(5, age)
	S.integrate()
	return(S.value())
}

end

mata 

real scalar p_age_round(real scalar age, real matrix k, real matrix R, real matrix b, real scalar rmse, real scalar center, real scalar tol) 
{
	class Quadrature scalar S
	S = Quadrature()
	S.setEvaluator(&p_age())
	S.setLimits((age-0.5, age+0.5))

	S.setArgument(1, k)
	S.setArgument(2, R)
	S.setArgument(3, b)
	S.setArgument(4, rmse)
	S.setArgument(5, center)
	S.setArgument(6, tol)
	S.integrate()
	return(S.value())
}
end