if `1' == 0{
	global interactions ""
	global interaction_3w ""
	global level = "margin"
	global name = "${prefix}margins"
	global df = 5
	global tvc = ""
	global stpm3_dftvc = ""
	global dfcont = 4
	global winsor = 5
}
else if `1' == 1{
	global interactions ""
	global interaction_3w ""
	global level = "main"
	global name = "${prefix}main"
	global df = 5
	global tvc = ""
	global stpm3_dftvc = ""
	global dfcont = 4
	global winsor = 5
}
else if `1' == 2{ 
	global interactions "age stage"
	global interaction_3w ""
	global level = "inter"
	global name = "${prefix}inter_agestage"
	global df = 5
	global tvc = "age stage"
	global stpm3_dftvc = "dftvc(2)"
	global dfcont = 4
	global winsor = 5
}
else if `1' == 3{
	global interactions "age stage sex"
	global interaction_3w ""
	global level = "inter"
	global name = "${prefix}inter_agestagesex"
	global df = 5
	global tvc = "age stage sex"
	global stpm3_dftvc = "dftvc(3)"
	global dfcont = 4
	global winsor = 5
}
else if `1' == 4{
	global interactions "age stage sex"
	global interaction_3w "age stage sex"
	global level = "inter"
	global name = "${prefix}inter_agestagesex3w"
	global df = 5
	global tvc = "age stage sex"
	global stpm3_dftvc = "dftvc(3)"
	global dfcont = 4
	global winsor = 5
}
else if `1' == 5{
	global interactions "age stage sex"
	global interaction_3w "age stage sex"
	global level = "inter"
	global name = "${prefix}inter_agestagesex3w_df8"
	global df = 8
	global tvc = "age stage sex"
	global stpm3_dftvc = "dftvc(6)"
	global dfcont = 6
	global winsor = 5
}