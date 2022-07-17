*!version 1.0.0  28may2021
/*
purpose : 

	-isis- implements the iterative sure independence screening
	using -lasso-, -stepbic-, or -stepbic-.  It is useful in
	ultra-high-dimensional setting.

	-isis- can be further incorperated into a partialling-out or
	double-selection estimator in the high-dimensional GLM
	estimation.
	

syntax : 
	isis depvar controls [if] [in] [fw/iw],	///
		model(model_spec)		/// 
		method(method_spec)		///
		[always(varlist)		/// 
		maxiter(integer 5)		///
		verbose]			// undocumented

	where 
		o. depvar is a varname for the dependent variable.

		o. controls is a varlist for the controls

		o. Option -model()- specifies the model type. This option is
			required.

			where -model_spec- is one of 
				linear 
				logit
				poisson

		o. Option -method()- specifies the model selection technique.
			This option is required.

			-method_spec- is one of
			  	stepbic	
				steptest
				lasso, lasso_spec

			-lasso_spec- is one of
				cv
				plugin
				adaptive
				bic


		o. always() specifies the variables will be always included in
			the model. The default is none.

		o. maxiter() specifies the maximum number of iteration.  the
			default is 5.


		o. verbose displays the iteration log in detail
	    
*/
					//-----------------------------------//
					// main program
					//-----------------------------------//
program isis
	if (replay()) {
		Display
	}
	else {
		Estimate `0'
	}
end

					//-----------------------------------//
					// Display
					//-----------------------------------//
program Display
	di
					//  title
	local title as txt "`e(title)'"
					//  model
	local model as txt "model : " as res "`e(model)'"

					// method
	local method as txt "method: " as res "`e(selcmd)' `e(selopt_simple)'"

	local col = 39
					//  nobs
	local nobs _col(`col') as txt "Number of obs" _col(67) "="	///
		_col(69) as res %10.0fc e(N)

					// maxiter
	local maxiter _col(`col') as txt "Max number of iterations" 	///
		_col(67) "=" _col(69) as res %10.0fc e(maxiter)

					// iter
	local iter _col(`col') as txt "Actual number of iterations" 	///
		_col(67) "=" _col(69) as res %10.0fc e(iter)

					//  number of controls
	local k_controls _col(`col') as txt "Number of controls"	///
		_col(67) "=" _col(69) as res %10.0fc e(k_controls)

					//  number of selected controls
	local k_controls_sel _col(`col') as txt	///
		"Number of selected controls"   ///
		_col(67) "=" _col(69) as res %10.0fc e(k_controls_sel)

					//  screen size
	local screen_size _col(`col') as txt "Screen size" 	///
		_col(67) "=" _col(69) as res %10.0fc e(screen_size)
	
	tempname b
	mat `b' = e(b)


	di `title' `nobs'
	di `maxiter'
	di `iter'
	di  `screen_size'
	di `model' `k_controls' 
	di `method' `k_controls_sel'
	di
	_coef_table, bmatrix(`b')
end

					//-----------------------------------//
					//  estimate
					//-----------------------------------//
program Estimate
					// parse syntax
	tempvar mytouse
	ParseSyntax `mytouse': `0'	

					// compute
	Compute, depvar(`r(depvar)')	///
		controls(`r(controls)')	///
		always(`r(always)')	///
		model(`r(model)')	///
		selcmd(`r(selcmd)')	///
		selopt(`r(selopt)')	///
		maxiter(`r(maxiter)')	///
		wgt(`r(wgt)')		///
		mytouse(`mytouse')	///
		verbose(`r(verbose)')
	
end

					//-----------------------------------//
					// ParseSyntax
					//-----------------------------------//
program ParseSyntax, rclass
					// main syntax
	_on_colon_parse `0'
	local mytouse `s(before)'
	local 0 `s(after)'

	syntax varlist(numeric fv) 	///
		[if] [in] [iw fw]	///
		, model(passthru)	///
		method(string)		///
		[always(passthru)	///
		maxiter(passthru)	///
		verbose]

					// parse vars	
	ParseVars, vars(`varlist') `always'
	local depvar `s(depvar)'
	local controls `s(controls)'
	local always `s(always)'

					// touse
	marksample touse
	markout `touse' `depvar' `controls' `always'
	qui gen byte `mytouse' = `touse'

					// parse model 
	ParseModel, `model'
	local model `s(model)'

					// parse method
	ParseMethod `method'
	local selcmd `s(selcmd)'
	local selopt `s(selopt)'

					// maxiter
	ParseMaxiter, `maxiter'
	local maxiter `s(maxiter)'

					// weight
	local wgt [`weight'`exp']

					// verbose
	if (`"`verbose'"' != "") {
		local verbose noi
	}
	else {
		local verbose 
	}

					// return result
	ret local depvar `depvar'
	ret local controls `controls'
	ret local always `always'
	ret local model `model'
	ret local selcmd `selcmd'
	ret local selopt `selopt'
	ret local maxiter `maxiter'
	ret local wgt `wgt'
	ret local verbose `verbose'
end

					//-----------------------------------//
					//  parse vars
					//-----------------------------------//
program ParseVars, sclass
	syntax , vars(varlist fv numeric)	///
		[always(varlist numeric fv)]

	fvexpand `vars'
	local varlist `r(varlist)'
					// split depvar and controls
	gettoken depvar controls: varlist
	_fv_check_depvar `depvar'

					// controls
	if (`"`controls'"' == "") {
		di as err "must specify control variables"
		exit 198
	}
					// always
	if (`"`always'"' != "") {
		fvexpand `always'
		local always `r(varlist)'
		local controls : list controls - always
	}

	sret local depvar `depvar'
	sret local controls `controls'
	sret local always `always'
end

					//-----------------------------------//
					//  parse model
					//-----------------------------------//
program ParseModel, sclass
	syntax , model(string)

	if (`"`model'"' != "linear" 		///
		& `"`model'"' != "logit" 	///
		& `"`model'"' != "poisson") {

		di as err "option {bf:model()} must be one of "		///
			"{bf:linear}, {bf:logit}, or {bf:poisson}"
		exit 198
	}	

	sret local model `model'
end

					//-----------------------------------//
					// parse method
					//-----------------------------------//
program ParseMethod, sclass
	syntax namelist(name=selcmd)	///
		[, bic			///
		plugin			///
		adaptive		///
		cv]

	local selopt `bic' `plugin' `adaptive' `cv'
	local k_selopt : list sizeof selopt
					// selcmd
	if (`"`selcmd'"' != "lasso" 		///
		& `"`selcmd'"' != "stepbic"	///
		& `"`selcmd'"' != "steptest") {
		di as err "option {bf:method()} allows only one of "	///
			"{bf:lasso}, {bf:stepbic}, or {bf:steptest}"
		exit 198
	}

					//  set lasso 
	if (`"`selcmd'"' == "lasso") {
		if (`k_selopt' > 1 | `k_selopt' == 0) {
			di as err "option {bf:method(lasso, )} allows " ///
				"only one of {bf:cv}, {bf:adaptive}, "	///
				"{bf:bic}, or {bf:plugin}"
			exit 198
		}

		local selopt selection(`selopt')
	}

	if (`"`selcmd'"' != "lasso" & `k_selopt' != 0) {
		di as err "options {bf:cv}, {bf:adaptive}, "	///
			"{bf:bic} and {bf:plugin} not allowed " ///
			"in {bf:method(`selcmd')}"
		exit 198
	}

	sret local selcmd `selcmd'
	sret local selopt `selopt'
end
					//-----------------------------------//
					// parse maxiter
					//-----------------------------------//
program ParseMaxiter, sclass
	syntax [, maxiter(integer 5)]

	if (`maxiter' <=0 | `maxiter' >= 31) {
		di as err "option {bf:maxiter()} must be a positive "	///
			"integer less than 31"
		exit 198
	}

	sret local maxiter `maxiter'
end
					//-----------------------------------//
					// compute
					//-----------------------------------//
program Compute
	syntax, depvar(string)		///
		controls(string)	///
		model(string)		///
		selcmd(string)		///
		maxiter(string)		///
		mytouse(string)		///
		[always(string)		///
		selopt(string)		///
		wgt(string)		///
		verbose(passthru)]

					// preseve START			
	preserve

	/* ----------------------------------------------------------- */
	// initial conditions setup
					// standardize controls and always
	Normalize, controls(`controls') always(`always')

					// set d = screen size
	SetD, model(`model') mytouse(`mytouse')
	local d = `s(d)'
	local ds `s(ds)'

					// set M0 
	SetM0, always(`always')
	local m0 `s(m0)'

	/* ----------------------------------------------------------- */
	// do the loop

	DoLoop, depvar(`depvar')	///
		controls(`controls')	///
		model(`model')		///
		selcmd(`selcmd')	///
		maxiter(`maxiter')	///
		mytouse(`mytouse')	///
		always(`always')	///
		selopt(`selopt')	///
		wgt(`wgt')		///
		d(`d')			///
		m0(`m0')		///
		`verbose'
	local set_m `r(set_m)'
	local iter `r(iter)'
					// preserve END
	restore
					// post result 
	PostResult, set_m(`set_m')	///
		depvar(`depvar') 	///
		model(`model')		///
		controls(`controls')	///
		selcmd(`selcmd')	///
		mytouse(`mytouse')	///
		wgt(`wgt')		///
		always(`always')	///
		selopt(`selopt')	///
		maxiter(`maxiter')	///
		iter(`iter')		///
		d(`d')			///
		ds(`ds')
end

					//-----------------------------------//
					//  normalize controls
					//-----------------------------------//
program Normalize
	syntax, controls(string) 	///
		[always(string)]

	foreach var in `controls' `always' {
		qui sum `var'
		qui replace `var' = `var' - r(mean)
		qui replace `var' = `var'/r(sd)
	}
end
					//-----------------------------------//
					// set D = the screen size
					//-----------------------------------//
program SetD, sclass
	syntax, model(string)	///
		mytouse(string)

	qui count if `mytouse'
	local N = r(N)

	if (`"`model'"' == "linear") {
		local d = floor( `N'/log(`N') )
		local ds "floor( `N'/log(`N') )"
	}
	else if (`"`model'"' == "logit") {
		local d = floor( `N'/(log(`N')*4) )
		local ds "floor( `N'/(log(`N')*4) )"
	}
	else if (`"`model'"' == "poisson") {
		local d = floor( `N'/(log(`N')*2) )
		local ds "floor( `N'/(log(`N')*2) )"
	}

	sret local d = `d'
	sret local ds `ds'
end
					//-----------------------------------//
					// set M0
					//-----------------------------------//
program SetM0, sclass
	syntax, [always(string)]
	
	sret local m0 `always'
end

					//-----------------------------------//
					// Do loop
					//-----------------------------------//
program	DoLoop, rclass
	syntax, depvar(string)		///
		controls(string)	///
		model(string)		///
		selcmd(string)		///
		maxiter(string)		///
		mytouse(string)		///
		d(string)		///
		[always(string)		///
		m0(string)		///
		selopt(string)		///
		wgt(string)		///
		verbose(passthru)]
	
	/* ----------------------------------------------------------- */
	// do the loop

	forvalues l = 1/`maxiter' {
		local iter = `l'
		
		di
		di as txt "Iteration `l':"
					// 1. set m(l-1)
		local m_prev `set_m'

					// 2. CMMLE
		Cmmle, depvar(`depvar') 	///
			model(`model')		///
			mytouse(`mytouse')	///
			wgt(`wgt')		///
			controls(`controls') 	///
			always(`always')	///
			m_prev(`m_prev') 	///
			l(`l')			///
			maxiter(`maxiter')	///
			d(`d')			///
			`verbose'
		local set_a `s(set_a)'

					// 3. machine-learning on union
		SelML, depvar(`depvar')		///
			always(`always')	///
			model(`model')		///
			selcmd(`selcmd')	///
			selopt(`selopt')	///
			set_a(`set_a')		///
			m_prev(`m_prev')	///
			wgt(`wgt')		///
			mytouse(`mytouse')	///
			`verbose'

		local set_m `s(set_m)'
		local all_set_m `all_set_m' || `set_m'

					// 4. determin if stop
		IfStop, all_set_m(`all_set_m') set_m(`set_m') d(`d')
		local stop = `s(stop)'
		if (`s(stop)') {
			continue, break
		}
	}

	di	
	if (`stop') {
		di as txt "Model selection converged."
	}
	else {
		di as txt "Maximum number of iteration attained."
	}

	ret local set_m `set_m'
	ret local iter `iter'
end
					//-----------------------------------//
					//  CMMLE
					//-----------------------------------//
/* 
	conditional marginal maximum likelihood estimation
*/
program Cmmle
	syntax, depvar(string) 		///
		model(string)		///
		controls(string) 	///
		l(string)		///
		d(string)		///
		mytouse(string)		///
		wgt(string)		///
		maxiter(string)		///
		[always(string)		///
		m_prev(string) 		///
		verbose(string)]	

					// candidate vars
	local candi : list controls - m_prev
	local candi : list candi - always

					// display iteration log
	di as txt _col(4) "CMMLE over `:list sizeof candi' variables"
	if (`"`verbose'"' != "") {
		di as txt "{p 8 12 2}previous selected model: `m_prev'{p_end}"
		di as txt "{p 8 12 2}candidate variables: `candi'{p_end}"
	}

					// estimation commands
	if ("`model'" == "linear") {
		local estcmd regress
	}
	else {
		local estcmd `model'
	}

					// beta vector for candi set
	tempname beta_candi

					// estimate cmmle for each candi var

	foreach var of local candi {
		cap `estcmd' `depvar' `m_prev' `var' if `mytouse' `wgt'

		if (!_rc) {
			matrix `beta_candi' = nullmat(`beta_candi') \ _b[`var']
			local rownames `rownames' `var'
		}
	}
	matrix rownames `beta_candi' = `rownames'

					// pick vars
	mata : pick_vars(`"`beta_candi'"', `d', "`m_prev'", `l', `maxiter')

	local set_a `s(set_a)'

	di as txt _col(4) "SIS picked `:list sizeof set_a' variables"	

	if ("`verbose'" != "") {
		di as txt "{p 8 12 2}set A: `set_a'{p_end}"
	}
end
					//-----------------------------------//
					// select model further using ML
					//-----------------------------------//
program	SelML, sclass
	syntax, depvar(string)	///
		model(string)	///
		selcmd(string)	///
		set_a(string)	///
		mytouse(string)	///
		wgt(string)	///
		[m_prev(string) ///
		always(string)	///
		selopt(string)	///
		verbose(string)]


	local candi : list set_a | m_prev
	local candi : list candi | always

	if ("`selcmd'"' == "lasso") {
					// lasso

		cap `verbose' lasso `model' `depvar' (`always') `candi'	///
			if `mytouse' `wgt', `selopt' 
		local rc = _rc

		if (!`rc') {
			local set_m `e(allvars_sel)'	
		}
		else {
			exit `rc'
		}
	}
	else {
					// stepwise bic or testing

		if ("`model'" == "linear") {
			local est_model regress
		}
		else {
			local est_model `model'
		}

		cap `verbose' `selcmd', always(`always'): 	///
			`est_model' `depvar' `always' `candi' if `mytouse' `wgt'
		local rc = _rc
		if (!`rc') {
			local set_m `r(included)'	
		}
		else {
			exit `rc'	
		}
	}

	local tmp `always' `candi'
	local k_tmp : list sizeof tmp

	di as txt _col(4) "`selcmd' selected `:list sizeof set_m' "	///
		"variables among `k_tmp' controls" 

	sret local set_m `set_m'
end

					//-----------------------------------//
					// if stop
					//-----------------------------------//
program	IfStop, sclass
	syntax, all_set_m(string) 	///
		d(string)		///
		[set_m(string)] 	
	

	local k_m : list sizeof set_m

	if (`k_m' >= `d') {
		sret local stop = 1
		exit 
		// NotReached
	}

	if (`k_m' == 0) {
		sret local stop = 1
		exit 
	}

	_parse expand all tmp : all_set_m
	local K = `all_n' - 1
	forvalues i = 1/`K' {
		local equal : list all_`i' === set_m
		if (`equal') {
			sret local stop = 1
			exit 
			// NotReached
		}
	}

	sret local stop = 0
end

					//-----------------------------------//
					//  post result
					//-----------------------------------//
program PostResult, eclass		
	syntax, depvar(string) 		///
		model(string)		///
		controls(string)	///
		selcmd(string)		///
		mytouse(string)		///
		wgt(string)		///
		maxiter(string)		///
		d(string)		///
		ds(string)		///
		iter(string)		///
		[always(string)		///
		set_m(string)		///
		selopt(string)]	
	
	local allvars : list controls | always
	local p = `:list sizeof allvars'
	local k_selected = `:list sizeof set_m'

	if (`"`model'"' == "linear") {
		local estcmd regress
	}
	else {
		local estcmd `model'
	}

	qui `estcmd' `depvar' `set_m' if `mytouse' `wgt'
	local N = e(N)
	eret local allvars `allvars'
	eret local allvars_sel `set_m'
	eret local screen_size_lb `ds'
	eret scalar screen_size = `d'
	eret scalar k_controls = `p'
	eret scalar k_controls_sel = `k_selected'
	eret local model `model'
	eret local depvar `depvar'
	eret local selcmd `selcmd'
	eret local selopt `selopt'
	if (`"`selopt'"' != "") {
		local 0 , `selopt'
		syntax , SELection(string)
		eret local selopt_simple `selection'
	}
	eret local title "Sure independence screening"
	eret scalar N = `N'
	eret scalar maxiter = `maxiter'
	eret scalar iter = `iter'
	eret local cmd_extend isis
					// display
	Display
end	
/*-----------------------------------------------------------------------------
	mata utilities		
-----------------------------------------------------------------------------*/
					//-----------------------------------//
					//  pick vars
					//-----------------------------------//
mata :
mata set matastrict on

void pick_vars(				///
	string scalar	_bs,		///
	real scalar	_d,		///
	string scalar	_m_prev,	///
	real scalar	_l,		///
	real scalar	_maxiter)
{
	string matrix 	vars, set_a
	real matrix	b
	real colvector	idx
	real scalar	k, k_prev

	b = abs(st_matrix(_bs))
	vars = st_matrixrowstripe(_bs)
	vars = vars[., 2]

	idx = order(b, -1)

	if (_m_prev != "") {
		k_prev = length(tokens(_m_prev))
	}
	else {
		k_prev = 0
	}

	
	if (_l == 1 & _maxiter >1 ) {
		k = floor(2*_d/3)
	}
	else if (_l == 1 & _maxiter == 1 ) {
		k = floor(_d)
	}
	else {
		k = _d - k_prev
	}

	if (k > length(b)) {
		k = length(b)
	}

	set_a = vars[idx][1..k]
	st_global("s(set_a)", invtokens(set_a'))
}


end
