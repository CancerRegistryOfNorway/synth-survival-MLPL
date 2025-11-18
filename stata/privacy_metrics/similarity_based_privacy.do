********************************************************************************
* Collects results from python script. 

* Identical match share (IMS):
do "${root}\stata\privacy\ims.do"

* Distance to closest record (DCR):
do "${root}\stata\privacy\dcr.do" 

* identifiability score:
do "${root}\stata\privacy\id_score.do" 

use "${results}\data\ims_${site}_sum.dta", clear
merge 1:1 model using "${results}\data\dcr_${site}_sum.dta", nogen
merge 1:1 model using "${results}\data\id_score_${site}_sum.dta", nogen 

lab define modlab 0 "Indep. marginals" 1 "Model 1" 2 "Model 2" 3 "Model 3" 4 "Model 4" 5 "Model 5" 6  "Resampling"
label val model modlab
decode model, gen(mod)

drop model
gen str = " & " + mod + " & "+ ims + " & " + dcr + " & " + id_score  + " \\"
keep str

export delimited using ${results}\export\privacy_${site}.txt, delimiter(tab) novarnames replace
