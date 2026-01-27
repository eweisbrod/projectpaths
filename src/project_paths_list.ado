program define project_paths_list, rclass
    version 16.0
    /*
      Per-user project root registry stored in PERSONAL.

      Usage:
        project_paths_list, project(<key>) [cd] [noprompt]
        project_paths_list, add    project(<key>) path("<dir>")
        project_paths_list, remove project(<key>)
        project_paths_list, list
        project_paths_list, where

      Interactive behavior:
        - If project(<key>) is missing (or stored path is invalid) and Stata is interactive,
          prompt for the path, save it, and continue.
        - If running in batch mode or noprompt is specified, never prompt; error instead.
    */

    syntax , ///
        [ PROJECT(string) ///
          PATH(string asis) ///
          ADD REMOVE LIST WHERE CD NOPROMPT ]

    // Detect batch mode (non-interactive): c(mode) contains "batch" in batch runs
    local is_batch = (strpos("`c(mode)'", "batch") > 0)

    // ---- locate PERSONAL and registry file (robust path handling) ----
    local personal_raw : sysdir PERSONAL
    local personal "`personal_raw'"
    local personal = subinstr("`personal'", "\", "/", .)
    if substr("`personal'", strlen("`personal'"), 1) != "/" {
        local personal "`personal'/"
    }

    local regfile "`personal'project_paths_registry.dta"

    // ---- ensure PERSONAL directory exists ----
    capture confirm file "`personal'/."
    if _rc {
        capture mkdir "`personal'"
        capture confirm file "`personal'/."
        if _rc {
            di as error "Could not create or access PERSONAL directory:"
            di as error "`personal'"
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
                di as error "Could not create registry file:"
                di as error "`regfile'"
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

    // Normalize key: lowercase + trim
    local k = strlower(strtrim("`project'"))

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
                di as error "Could not update registry file:"
                di as error "`regfile'"
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

        local p `"`path'"'
        local p = subinstr(`"`p'"', "\", "/", .)

        capture confirm file "`p'/."
        if _rc {
            di as error "Directory does not exist:"
            di as error "`p'"
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
                di as error "Could not update registry file:"
                di as error "`regfile'"
                exit 603
            }
        restore

        di as txt "Saved: `project' -> `p'"
        return local root "`p'"
        exit
    }

    // ---- GET (default): retrieve root for project() ----
    local root ""

    preserve
        use "`regfile'", clear
        quietly keep if lower(key) == "`k'"
        if _N > 0 {
            quietly keep in 1
            local root = root[1]
        }
    restore

    // If missing key, prompt unless noprompt or batch
    if "`root'" == "" {
        if "`noprompt'" != "" | `is_batch' {
            di as error "Unknown project key: `project'"
            di as error "Register it (interactive) or run:"
            di as error "  project_paths_list, add project(<key>) path(""C:/path/to/project"")"
            exit 111
        }

        di
