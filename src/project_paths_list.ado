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
    mata: st_local("personal", subinstr(st_local("personal", ""), char(92), "/", .))
    if substr("`personal'", strlen("`personal'"), 1) != "/" {
        local personal "`personal'/"
    }

    local regfile "`personal'project_paths_registry.dta"

    // ---- ensure PERSONAL directory exists ----
    tempname okd
    mata: st_numscalar("`okd'", direxists(st_local("personal", "")))
    if scalar(`okd') == 0 {
        capture mkdir "`personal'"
        mata: st_numscalar("`okd'", direxists(st_local("personal", "")))
        if scalar(`okd') == 0 {
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

    // Normalize key: lowercase + trim (Mata-safe, allows hyphens)
    local k "`project'"
    mata: st_local("k", strlower(strtrim(st_local("k", ""))))

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
    // Use Stata string functions instead of Mata
    local p = subinstr(`"`p'"', "\", "/", .)

    // Use Stata's confirm file/direxists instead of Mata
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
            mata: st_local("root", st_sdata(1, "root"))
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

        di as txt "Project not found: `project'"
        di as txt "Enter root directory path (or press Enter to cancel):"
        di as txt "> " _request(_p)
        local p = trim(`"`p'"')
        
        if `"`p'"' == "" {
            di as error "Cancelled."
            exit 1
        }

        mata: st_local("p", subinstr(st_local("p", ""), char(92), "/", .))
        tempname okm
        mata: st_numscalar("`okm'", direxists(st_local("p", "")))
        if scalar(`okm') == 0 {
            di as error "Directory does not exist:"
            di as error "`p'"
            exit 601
        }

        // Save it (upsert)
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

        local root "`p'"
    }
    else {
        // Normalize stored root slashes and validate
        mata: st_local("root", subinstr(st_local("root", ""), char(92), "/", .))

        tempname ok2
        mata: st_numscalar("`ok2'", direxists(st_local("root", "")))
        if scalar(`ok2') == 0 {
            if "`noprompt'" != "" | `is_batch' {
                di as error "Stored project root no longer exists:"
                di as error "`root'"
                exit 601
            }

            di as txt "Stored path missing for: `project'"
            di as txt "Current (invalid) path: `root'"
            di as txt "Enter UPDATED root directory path (or press Enter to cancel):"
            di as txt "> " _request(_p)
            local p = trim(`"`p'"')
            
            if `"`p'"' == "" {
                di as error "Cancelled."
                exit 1
            }

            mata: st_local("p", subinstr(st_local("p", ""), char(92), "/", .))
            tempname ok3
            mata: st_numscalar("`ok3'", direxists(st_local("p", "")))
            if scalar(`ok3') == 0 {
                di as error "Directory does not exist:"
                di as error "`p'"
                exit 601
            }

            // Update registry (upsert)
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

            local root "`p'"
        }
    }

    // Expose resolved root
    global PROJROOT "`root'"
    return local root "`root'"

    if "`cd'" != "" {
        cd "`root'"
        di "`c(pwd)'"
    }
end
