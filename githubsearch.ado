program githubsearch

	syntax anything , [language(str) save(str) in(str) all created(str) 		///
	pushed(str) debug append replace quiet Number(numlist max=1)] 
	
	// defaults language is Stata
	// --------------------------
	if "`language'" == "all" {
		local savelang `language'
		local language  //nothing!
	}
	else if missing("`language'") {
		local savelang stata
		local language "+language:stata"
	}
	else {
		local savelang `language'
		local language "+language:`language'"
	}
	
	// date
	if !missing("`created'") {
		local created "+created:`created'"
	}
	if !missing("`pushed'") {
		local created "+pushed:`pushed'"
	}
	
	// search domain
	if missing("`in'") {
		local in "name,description"
		local savein "name,description"
	}
	else if "`in'" == "all" {
		local in "name,description,readme"
		local savein all
	}
	else if "`in'" != "name" & "`in'" != "description" & "`in'" != "readme" & 	///
	"`in'" != "all" & "`in'" != "name,description" & "`in'" != 					///
	"description,name" & "`in'" != "name,description,readme" 					///
	& "`in'" != "description,name,readme" & !missing("`in'") {
		di as err "in(`in') is unacceptable"
		err 198
	}
	
	preserve
	quietly clear
	
	tempfile data
	
	qui generate str address = ""
	qui generate str name = ""
	qui generate int installable = . 
	qui generate str language = ""
	qui generate int star = . 
	qui generate int fork = . 
	qui generate str created = ""
	qui generate str updated = ""
	qui generate str pushed = ""
	qui generate int kb = .
	qui generate int watchers = . 
	qui generate str description = ""
	qui generate str homepage = ""
	
	*quietly copy "https://api.github.com/search/repositories?q=`anything'`language'+size:%3C1+in:description,readme,name&per_page=100" "sth.json", replace
	*quietly copy "https://api.github.com/search/repositories?q=`anything'`language'+in:name,description,readme&per_page=100" "sth.json", replace
	*di as err "{p}https://api.github.com/search/repositories?q=`anything'`language'+in:`in'&per_page=100"
	
	if !missing("`debug'") {
		di as err "{p}https://api.github.com/search/repositories?q=`anything'`language'`created'`pushed'+in:`in'&sort=stars&order=desc&per_page=100" _n
		copy "https://api.github.com/search/repositories?q=`anything'`language'`created'`pushed'+in:`in'&sort=stars&order=desc&per_page=100" "base.json", replace
	}
	tempfile api tmp
	tempname hitch knot
	capture qui copy "https://api.github.com/search/repositories?q=`anything'`language'`created'`pushed'+in:`in'&sort=stars&order=desc&per_page=100" `api', replace

	if _rc != 0 {
		di as err "{p}the GitHub API is not responsive right now. Try again in " ///
		"10 or 20 seconds. this can happen if you search GitHub very frequent..."
		exit
	}
	file open `hitch' using "`api'", read
	qui file open `knot' using "`tmp'", write replace
	file read `hitch' line
	
	if !missing("`debug'") {
		di as txt `"Line:`line'"' _n(3)
	}
	
	// check the number of results
	// --------------------------------
	tokenize `"`macval(line)'"' , parse(",")
	local 1 : display substr(`"`macval(1)'"',16,.)
	local found `1'
	
	// if the results are more than 100 
	// --------------------------------
	if `1' > 100 {
		local warning 1
		di as txt "({p}your search has yeilded {bf:`1'} results, but "			///
		"GitHub API can return maximum of 100 results. Narrow your search "		///
		"using {bf:language}, {bf:in}, {bf:created}, and {bf:pushed} options...)" _n
	}
	
	local line : subinstr local line "[" "", all
	local line : subinstr local line "]" "", all
	local line : subinstr local line "{" "", all
	local line : subinstr local line "}" "", all
		
	local n = 0
	while r(eof) == 0 {
		tokenize `"`macval(line)'"' , parse(",")
		while !missing(`"`macval(1)'"') | !missing(`"`macval(2)'"') | !missing(`"`macval(3)'"')  {
				if !missing("`debug'") {
					di as err `"1:`macval(1)'"'`"2:`macval(2)'"' `"3:`macval(3)'"' "4>>" `"4:`macval(4)'"'	`"5:`macval(5)'"'
				}
				
				if `"`macval(1)'"' == `","' {
					macro shift
				}
				else if `"`macval(1)'"' == "name" { 
					local 2 : di substr(`"`macval(2)'"', 2,.)
					local l : di length(`"`macval(2)'"')
					local 2 : di substr(`"`macval(2)'"', 2,`l'-2)
					local n `++n'
					quietly set obs `n'
					quietly replace name = `"`macval(2)'"' in `n'
					macro shift
				}
				else if `"`macval(1)'"' == "full_name" { 
					local 2 : di substr(`"`macval(2)'"', 2,.)	
					local l : di length(`"`macval(2)'"')
					local 2 : di substr(`"`macval(2)'"', 2,`l'-2)
					quietly replace address = `"`macval(2)'"' in `n'
					
					// confirm that it is installable
					// ------------------------------					
					capture quietly githubconfirm `2'
					local cal : di mod(`n',10)
					
					if `found' > 10 {
						if "`cal'" == "0" & missing("`quiet'") | 				///
						"`n'" == "1" & missing("`quiet'") {
							di as txt "`n'" _c
						}
						else {
							di as txt "." _c
						}
					}	
					
					if "`r(installable)'" == "1" {
						quietly replace installable = 1 in `n'
					}
					else {
						quietly replace installable = 0 in `n'
					}
					macro shift
				}
				else if `"`macval(1)'"' == "description"  { 
					local l : di length(`"`macval(2)'"')
					if `"`macval(2)'"' != ":null" & `l' > 3 {							
						local 2 : di substr(`"`macval(2)'"', 2,.)
						local l : di length(`"`macval(2)'"')
						local 2 : di substr(`"`macval(2)'"', 2,`l'-2)
						quietly replace description = `"`macval(2)'"' in `n'					
					}	
					else {
						quietly replace description = "" in `n'
					}
					macro shift
				}
				else if `"`macval(1)'"' == "created_at" { 					
					local 2 : di substr(`"`macval(2)'"', 2,.)
					local 2 : subinstr local 2 "T" " at "
					local 2 : subinstr local 2 "Z" ""
					quietly replace created = `"`macval(2)'"' in `n'
					macro shift
				}
				else if `"`macval(1)'"' == "updated_at" { 					
					*local 2 : di substr(`"`macval(2)'"', 3,10)
					local 2 : di substr(`"`macval(2)'"', 2,.)
					local 2 : subinstr local 2 "T" " at "
					local 2 : subinstr local 2 "Z" ""
					quietly replace updated = `"`macval(2)'"' in `n'
					macro shift
				}
				else if `"`macval(1)'"' == "pushed_at" { 					
					local 2 : di substr(`"`macval(2)'"', 2,.)
					local 2 : subinstr local 2 "T" " at "
					local 2 : subinstr local 2 "Z" ""
					quietly replace pushed = `"`macval(2)'"' in `n'
					macro shift
				}
				else if `"`macval(1)'"' == "homepage" { 
					local l : di length(`"`macval(2)'"')
					if `"`macval(2)'"' != ":null" & `l' > 3 {
						local 2 : di substr(`"`macval(2)'"', 2,.)
						local l : di length(`"`macval(2)'"')
						local 2 : di substr(`"`macval(2)'"', 2,`l'-2)
						quietly replace homepage = `"`macval(2)'"' in `n'
					}	
					else {
						quietly replace homepage = "" in `n'
					}
					macro shift
				}
				else if `"`macval(1)'"' == "size" { 
					local 2 : di substr(`"`macval(2)'"', 2,.)
					quietly replace kb = `2' in `n'
					macro shift
				}
				else if `"`macval(1)'"' == "language" { 
					local l : di length(`"`macval(2)'"')
					if `"`macval(2)'"' != ":null" & `l' > 3 {
						local 2 : di substr(`"`macval(2)'"', 2,.)
						local l : di length(`"`macval(2)'"')
						local 2 : di substr(`"`macval(2)'"', 2,`l'-2)
						quietly replace language = `"`macval(2)'"' in `n'
					}
					else {
						local 2 : di substr(`"`macval(2)'"', 2,.)
						quietly replace language = "" in `n'
					}	
					macro shift
				}
				else if `"`macval(1)'"' == "stargazers_count" { 
					local 2 : di substr(`"`macval(2)'"', 2,.)
					quietly replace star = `2' in `n'
					macro shift
				}
				else if `"`macval(1)'"' == "forks_count" { 
					local 2 : di substr(`"`macval(2)'"', 2,.)
					quietly replace fork = `2' in `n'
					macro shift
				}
				else if `"`macval(1)'"' == "watchers" { 
					local 2 : di substr(`"`macval(2)'"', 2,.)	
					quietly replace watchers = `2' in `n'
					macro shift
				}
				else {
					macro shift
				}
				if !missing("`debug'") {
					di as txt `"::`macval(1)'"' _n(3)
				}
			}
			file read `hitch' line
		}
		file close `hitch'		
		file close `knot'
		


	
	// -----------------------------------------------------------------------
	// Variable correction
	// =======================================================================
	qui generate double time_admitted = clock(created, "YMD#hms")
	qui format time_admitted %tc
	qui drop created
	quietly rename time_admitted created
	
	qui generate double time_admitted = clock(updated, "YMD#hms")
	qui format time_admitted %tc
	qui drop updated
	quietly rename time_admitted updated
	
	qui generate double time_admitted = clock(pushed, "YMD#hms")
	qui format time_admitted %tc
	qui drop pushed
	quietly rename time_admitted pushed
	
	// convert language to factor variable
	*qui encode language, generate(type)
	*qui drop language
	*qui rename type language
	
	//generate score
	quietly gen score = (watchers*5 + star*5 + fork) - 5
	quietly replace score = 0 if score < 0
	
	// sort the data based on installable and score 
	quietly gsort - installable - score
	
	// -----------------------------------------------------------------------
	// Save the results
	// =======================================================================
	if !missing("`save'") {
		if missing("`append'") {
			quietly save `save', `replace'
		}
		else {
			capture findfile `"`save'.dta"'
			if _rc == 0 {
				qui append using `"`save'.dta"'
				capture duplicates drop address, force
				qui save `"`save'.dta"', replace
			}
			else {
				qui save `"`save'.dta"', replace
			}
		}
	}
	
	// -----------------------------------------------------------------------
	// Drawing the output table
	// =======================================================================
	if missing("`quiet'") {
		githuboutput `anything', in("`in'") `all' number(`number')
	}	

	restore
end

  
