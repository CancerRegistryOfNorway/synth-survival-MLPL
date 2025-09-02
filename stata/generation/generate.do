********************************************************************************
* Generate synthetic data using "${root}\stata\generation\generate_dataset.do"
* with models as defined in "${root}\stata\models.do"
*
* Generates multiple datasets in paralell stata sessions as long as there is 
* free capacity. 

local args \`mod' \`i'
local dofile "${root}\stata\generation\generate_dataset.do"

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

