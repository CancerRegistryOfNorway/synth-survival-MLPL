
local models = "${prefix}margins ${prefix}main ${prefix}inter_agestage ${prefix}inter_agestagesex ${prefix}inter_agestagesex3w ${prefix}inter_agestagesex3w_df8 ${prefix}dummy"

* Univariate:
do "${root}\stata\utility\jsd.do" "`models'"

* Bivariate:
do "${root}\stata\utility\pcd.do" "`models'"

* Multivariate (requires that XGBoost propensity score has been run):
do "${root}/stata/utility/plot_propensity_score.do"

* Specific:
do "${root}/stata/utility/5yr_surv.do" "`models'"


cd "${results}\utility\"
graph combine jsd.gph pcd.gph ${site}_propensity_score.gph 5yr_surv.gph, name(utility, replace) rows(2) xsize(12) ysize(8) iscale(*1.1)
cd "${root}"

cd "${results}\utility\"
graph combine jsd.gph pcd_lim.gph ${site}_propensity_score_lim.gph 5yr_surv_lim.gph, name(utility_lim, replace) rows(2) xsize(12) ysize(8) iscale(*1.1)
cd "${root}"

use "${results}\data\jsd_sum.dta", clear
merge 1:1 model using "${results}\data\pcd_sum.dta", nogen
merge 1:1 model using "${results}\data\pmse_sum.dta", nogen 
merge 1:1 model using "${results}\data\5yr_sum.dta", nogen 

lab define modlab 0 "Indep. marginals" 1 "Model 1" 2 "Model 2" 3 "Model 3" 4 "Model 4" 5 "Model 5" 6  "Resampling"
label val model modlab
decode model, gen(mod)

gen str = " & " + mod + " & "+ jsd + " & " + pcd + " & " + pmse + " & " + mean_diff + " \\"
keep str

export delimited using ${results}\export\utility_${site}.txt, delimiter(tab) novarnames replace