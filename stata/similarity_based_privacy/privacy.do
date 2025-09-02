
local models = "${prefix}margins ${prefix}main ${prefix}inter_agestage ${prefix}inter_agestagesex ${prefix}inter_agestagesex3w ${prefix}inter_agestagesex3w_df8 ${prefix}dummy"

* Identical match share (IMS):
do "${root}\stata\similarity_based_privacy\ims.do" "`models'"

* NN-matching:
do "${root}\stata\similarity_based_privacy\nn_matching.do" "`models'"

* Distance to closest record (DCR):
do "${root}\stata\similarity_based_privacy\dcr.do" "`models'"

* identifiability score:
do "${root}\stata\similarity_based_privacy\id_score.do" "`models'"

use "${results}\data\ims_${site}_sum.dta", clear
merge 1:1 model using "${results}\data\dcr_${site}_sum.dta", nogen
merge 1:1 model using "${results}\data\id_score_${site}_sum.dta", nogen 

lab define modlab 0 "Indep. marginals" 1 "Model 1" 2 "Model 2" 3 "Model 3" 4 "Model 4" 5 "Model 5" 6  "Resampling"
label val model modlab
decode model, gen(mod)

drop model
gen str = " & " + mod + " & "+ ims + " & " + dcr + " & " + ids  + " \\"
keep str

export delimited using ${results}\export\privacy_${site}.txt, delimiter(tab) novarnames replace