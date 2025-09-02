global dataprep "${root}\stata\dataprep"
global adofiles "${root}\stata\adofiles"
global results "${root}\results"
global data "${root}\data"

adopath + "${adofiles}"

global StataExe S:\Stata\Stata18MP\StataMP-64.exe

* Plot options
set scheme white_tableau, perm
graph set window fontface "Aptos"