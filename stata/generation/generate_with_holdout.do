********************************************************************************
* Generate synthetic data using "${root}\stata\generation\generate_dataset_with_holdout.do"
* with models as defined in "${root}\stata\models.do"
*
* Generates multiple datasets in paralell stata sessions as long as there is 
* free capacity. 

local args \`mod' \`i'
local dofile "${root}\stata\generation\generate_dataset_with_holdout.do"

forvalues i = 1/$nsim {
	
	use "${root}\original_data\original_${site}.dta", clear

	gen holdout = (runiform() < 0.2)

	save "${root}\original_data\holdout\original_holdout_${site}_`i'.dta", replace
	
	label drop _all
	outsheet id $sequence diag_date status exit _t holdout using "${root}\python\input\original_holdout_${site}_`i'.csv", comma replace  

	
	forvalues mod = 0/5{
		
		sleep `=10*1000'
		
		while 1{
			
			sysresources
			
			if (r(pctfreemem) < 25 | r(cpuload) > 0.75){
				
				sleep `=30*1000'
				continue
			}
			else{
				
				winexec $StataExe /e `dofile' `args'
				
				noi di "started model `mod' simulation `i': " c(current_time)
				
				continue, break
			}
		}
				
	}
}
