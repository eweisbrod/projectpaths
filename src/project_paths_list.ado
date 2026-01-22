program define project_paths_list, rclass
    version 16.0
    /*
      Per-user project root registry stored in PERSONAL.

      Primary use (1-liner, Ctrl+D friendly):
        project_paths_list, project(<key>) [cd]

      If <key> is missing:
        - interactive: prompts for a path, saves it, continues
        - batch or noprompt: errors (won't hang)

      Registry management:
        project_paths_list, add    project(<key>) path("<dir>")
        project_paths_list, remove project(<key>)
        project_paths_list, list
        project_paths_list, where

      Options:
        cd        : cd to the project root after resolving
        noprompt  : never prompt; error instead (batch-safe)
    */

    syntax , ///
        [ PROJECT(string) ///
          PATH(string asis) ///
          ADD REMOVE LIST WHERE CD NOPROMPT ]

    // ---- locate PERSONAL and registry file (robust path handling) ----
    local personal_raw : sysdir PERSONAL
    local personal "`personal_raw'"
    // normalize slashes for consistency
    mata: st_local("personal", subinstr(st_local("personal"), char(92), "/", .))
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

    // normalize key: trim + lowercase (hyphens allowed)
    local k "`project'"
    mata: st_local("k", strlower(strtrim(st_local("k"))))

    // ----------------------------
    // REMOVE
    // ----------------------------
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

    // ----------------------------
    // ADD (upsert)
    // ----------------------------
    if "`add'" != "" {
        if `"`path'"' == "" {
            di as error "add requires path(""..."")"
            exit 198
        }

        local p `"`path'"'
        // normalize slashes
        mata: st_local("p", subinstr(st_local("p"), char(92), "/", .))

        // validate directory exists
        tempname ok
        mata: st_numscalar("`ok'", direxists("`p'"))
        if scalar(`ok') == 0 {
            di as error "Directory does not exist: `p'"
            exit 601
        }

        // upsert
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

    // ----------------------------
    // GET (default): resolve root, with interactive fallback
    // ----------------------------
    local root ""

    preserve
        use "`regfile'", clear
        keep if lower(key) == "`k'"

        if _N > 0 {
            keep in 1
            mata: st_local("root", st_sdata(1, "root"))
        }
    restore

    // If missing key: interactive prompt unless batch/noprompt
    if "`root'" == "" {
        if "`noprompt'" != "" | c(batch) {
            di as error "Unknown project key: `project'"
            di as error "Run interactively once to register it, or do:"
            di as error `"  project_paths_list, add project(`project') path(""..."" )"'
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

        // upsert new entry
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
        // normalize stored root
        mata: st_local("root", subinstr(st_local("root"), char(92), "/", .))

        // if stored path missing: prompt to update unless batch/noprompt
        tempname ok2
        mata: st_numscalar("`ok2'", direxists("`root'"))
        if scalar(`ok2') == 0 {
            if "`noprompt'" != "" | c(batch) {
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

            // upsert updated entry
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

    // Expose + optional cd
    global PROJROOT "`root'"
    return local root "`root'"

    if "`cd'" != "" {
        cd "`root'"
        di "`c(pwd)'"
    }
end
