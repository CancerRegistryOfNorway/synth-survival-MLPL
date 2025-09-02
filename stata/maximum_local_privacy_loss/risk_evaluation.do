********************************************************************************
* Evaluate privacy risk(MLPL) using "${root}\stata\risk_evaluation_estimation.do"
* with models as defined in "${root}\stata\models.do"
*
* Evaluate multiple datasets in paralell stata sessions as long as there is 
* free capacity. 

* Make dataset with all combinations of covariates
do "${dataprep}\scenarios_cov.do"

local args \`mod' \`i'
local dofile "${root}\stata\maximum_local_privacy_loss\risk_evaluation_estimation.do"

forvalues i = 1/$nsim {
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

