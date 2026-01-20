program define project_paths_list, rclass
    version 16.0
    /*
      Per-user project root registry stored in PERSONAL.

      Usage:
        project_paths_list, project(<key>) [cd]
        project_paths_list, add    project(<key>) path("<dir>")
        project_paths_list, remove project(<key>)
        project_paths_list, list
        project_paths_list, where
    */

    syntax , ///
        [ PROJECT(string) ///
          PATH(string asis) ///
          ADD REMOVE LIST WHERE CD ]

    // ---- locate PERSONAL and registry file (robust path handling) ----
    local personal_raw : sysdir PERSONAL
    local personal `"`=subinstr(`"`personal_raw'"',"\","/",.)'"'
    if substr("`personal'", strlen("`personal'"), 1) != "/" local personal "`personal'/"

    local regfile "`personal'project_paths_registry.dta"

    // ---- ensure PERSONAL directory exists ----
    tempname okd
    mata: st_numscalar("`okd'", direxists("`personal'"))
    if scalar(`okd') == 0 {
        capture mkdir "`personal'"
        mata: st_numscalar("`okd'", direxists("`personal'"))
        if scalar(`okd') == 0 {
            di as error "Could not create or access PERSONAL directory: `personal'"
            exit 603
        }
    }

    // ---- ensure registry exists ----
    capture confirm file "`regfile'"
    if _rc {
        preserve
            quietly clear
            quietly set obs 0
            quietly gen str80 key = ""
            quietly gen strL  root = ""
            capture quietly save "`regfile'", replace
            if _rc {
                restore
                di as error "Could not create registry file: `regfile'"
                exit 603
            }
        restore
    }

    // ---- WHERE ----
    if "`where'" != "" {
        di as txt "PERSONAL: `personal'"
        di as txt "Registry : `regfile'"
        return local personal "`personal'"
        return local regfile  "`regfile'"
        exit
    }

    // ---- LIST ----
    if "`list'" != "" {
        preserve
            use "`regfile'", clear
            sort key
            list key root, noobs abbreviate(40)
        restore
        exit
    }

    // For add/remove/get require project()
    if "`project'" == "" {
        di as error "You must supply project(<key>) (or use list/where)."
        exit 198
    }

    // Normalize key: lowercase + trim (string-safe)
    local k `"`=lower(strtrim(`"`project'"'))'"'

    // ---- REMOVE ----
    if "`remove'" != "" {
        preserve
            use "`regfile'", clear
            quietly count if lower(key) == "`k'"
            if r(N) == 0 {
                di as error "Project key not found: `project'"
                restore
                exit 111
            }
            drop if lower(key) == "`k'"
            capture save "`regfile'", replace
            if _rc {
                restore
                di as error "Could not update registry file: `regfile'"
                exit 603
            }
        restore
        di as txt "Removed: `project'"
        exit
    }

    // ---- ADD (upsert) ----
    if "`add'" != "" {
        if `"`path'"' == "" {
            di as error "add requires path(""..."")"
            exit 198
        }

        // normalize path slashes
        local p `"`=subinstr(`"`path'"',"\","/",.)'"'

        // validate directory exists (Windows-safe)
        tempname ok
        mata: st_numscalar("`ok'", direxists("`p'"))
        if scalar(`ok') == 0 {
            di as error "Directory does not exist: `p'"
            exit 601
        }

        preserve
            use "`regfile'", clear
            drop if lower(key) == "`k'"

            set obs `=_N+1'
            replace key  = "`k'"   in L
            replace root = `"`p'"' in L

            capture save "`regfile'", replace
            if _rc {
                restore
                di as error "Could not update registry file: `regfile'"
                exit 603
            }
        restore

        di as txt "Saved: `project' -> `p'"
        return local root "`p'"
        exit
    }

    // ---- GET (default): retrieve root for project() ----
    preserve
        use "`regfile'", clear
        keep if lower(key) == "`k'"
        if _N == 0 {
            restore
            di as error "Unknown project key: `project'"
            di as error "Add it with: project_paths_list, add project(`project') path(""..."")"
            exit 111
        }
        local root = root[1]
    restore

    // validate stored root still exists
    local root `"`=subinstr(`"`root'"',"\","/",.)'"'
    tempname ok2
    mata: st_numscalar("`ok2'", direxists("`root'"))
    if scalar(`ok2') == 0 {
        di as error "Stored project root no longer exists on this machine: `root'"
        exit 601
    }

    global PROJROOT "`root'"
    return local root "`root'"

    if "`cd'" != "" {
        cd "`root'"
        di "`c(pwd)'"
    }
end
