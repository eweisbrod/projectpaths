```stata
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

    // Detect batch mode (non-interactive). In batch, never prompt.
    local is_batch = (strpos("`c(mode)'", "batch") > 0)

    // ---- locate PERSONAL and registry file (robust path handling) ----
    local personal_raw : sysdir PERSONAL
    local personal "`personal_raw'"
    mata: st_local("personal", subinstr(st_local("personal"), char(92), "/", .))
    if substr("`personal'", strlen("`personal'"), 1) != "/" {
        local personal "`personal'/"
    }

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

    // Normalize key: lowercase + trim (string-safe via Mata)
    local k "`project'"
    mata: st_local("k", strlower(strtrim(st_local("k"))))

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

        // normalize path slashes (Mata; handles backslashes cleanly)
        local p `"`path'"'
        mata: st_local("p", subinstr(st_local("p"), char(92), "/", .))

        // validate directory exists
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
    local root ""

    preserve
        use "`regfile'", clear
        quietly keep if lower(key) == "`k'"
        if _N > 0 {
            // st_sdata works for strL; local root = root[1] does NOT
            quietly keep in 1
            mata: st_local("root", st_sdata(1, "root"))
        }
    restore

    // If missing key, prompt (interactive) unless noprompt/batch
    if "`root'" == "" {
        if "`noprompt'" != "" | `is_batch' {
            di as error "Unknown project key: `project'"
            di as error `"Add it with: project_paths_list, add project(`project') path(""..."" )"'
            exit 111
        }

        local p ""
        window stopbox input "Project Paths" ///
            "Project '`project'' not found. Enter root directory path:" p
        if `"`p'"' == "" exit 198

        mata: st_local("p", subinstr(st_local("p"), char(92), "/", .))
        tempname okm
        mata: st_numscalar("`okm'", direxists("`p'"))
        if scalar(`okm') == 0 {
            di as error "Directory does not exist: `p'"
            exit 601
        }

        // Save it (upsert) to registry
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

        local root "`p'"
    }
    else {
        // normalize stored root slashes
        mata: st_local("root", subinstr(st_local("root"), char(92), "/", .))

        // validate stored root exists; if not, prompt to update unless noprompt/batch
        tempname ok2
        mata: st_numscalar("`ok2'", direxists("`root'"))
        if scalar(`ok2') == 0 {
            if "`noprompt'" != "" | `is_batch' {
                di as error "Stored project root no longer exists on this machine: `root'"
                exit 601
            }

            local p ""
            window stopbox input "Project Paths" ///
                "Stored path for '`project'' is missing. Enter UPDATED root directory path:" p
            if `"`p'"' == "" exit 198

            mata: st_local("p", subinstr(st_local("p"), char(92), "/", .))
            tempname ok3
            mata: st_numscalar("`ok3'", direxists("`p'"))
            if scalar(`ok3') == 0 {
                di as error "Directory does not exist: `p'"
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
                    di as error "Could not update registry file: `regfile'"
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
```
