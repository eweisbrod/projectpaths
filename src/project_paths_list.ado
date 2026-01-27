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
        
      Notes:
        - Project names can contain hyphens (e.g., my-project)
        - Paths work on Windows (C:/path) and Mac (/Users/path)
        - Uses Mata's direxists() for directory validation
    */

    syntax , ///
        [ PROJECT(string asis) ///
          PATH(string asis) ///
          ADD REMOVE LIST WHERE CD NOPROMPT ]

    // Detect batch mode (non-interactive)
    local is_batch = (strpos("`c(mode)'", "batch") > 0)

    // ---- locate PERSONAL and registry file ----
    local personal : sysdir PERSONAL
    
    // Normalize path separators using Mata (handles special chars safely)
    mata: st_local("personal", subinstr(st_local("personal"), "\", "/", .))
    
    // Ensure trailing slash
    if substr("`personal'", -1, 1) != "/" {
        local personal "`personal'/"
    }

    local regfile "`personal'project_paths_registry.dta"

    // ---- ensure PERSONAL directory exists ----
    mata: st_local("_dircheck", strofreal(direxists(st_local("personal"))))
    if `_dircheck' == 0 {
        capture mkdir "`personal'"
        mata: st_local("_dircheck", strofreal(direxists(st_local("personal"))))
        if `_dircheck' == 0 {
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
    if `"`project'"' == "" {
        di as error "You must supply project(<key>) (or use list/where)."
        exit 198
    }

    // Normalize key: lowercase + trim (use Mata to handle special chars)
    local k `"`project'"'
    // Remove surrounding quotes if present
    mata: st_local("k", strtrim(strlower(st_local("k"))))

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
            di as error "add requires path()"
            exit 198
        }

        // Get path and normalize slashes using Mata
        local p `"`path'"'
        mata: st_local("p", subinstr(st_local("p"), "\", "/", .))
        
        // Remove trailing slash if present (for consistency)
        if substr("`p'", -1, 1) == "/" {
            local p = substr("`p'", 1, strlen("`p'") - 1)
        }

        // Validate directory exists using Mata
        mata: st_local("_dircheck", strofreal(direxists(st_local("p"))))
        if `_dircheck' == 0 {
            di as error "Directory does not exist:"
            di as error "`p'"
            exit 601
        }

        preserve
            use "`regfile'", clear
            drop if lower(key) == "`k'"
            set obs `=_N+1'
            replace key  = "`k'"  in L
            replace root = "`p'"  in L
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

    // If key not found, prompt or error
    if "`root'" == "" {
        if "`noprompt'" != "" | `is_batch' {
            di as error "Unknown project key: `project'"
            di as error "Register it with:"
            di as error `"  project_paths_list, add project(`project') path("C:/path/to/project")"'
            exit 111
        }

        di as txt "Project not found: `project'"
        di as txt "Enter root directory path (or press Enter to cancel):"
        display _request(_p)
        local p = strtrim(`"`_p'"')
        
        if `"`p'"' == "" {
            di as error "Cancelled."
            exit 1
        }

        // Normalize slashes
        mata: st_local("p", subinstr(st_local("p"), "\", "/", .))
        
        // Validate directory
        mata: st_local("_dircheck", strofreal(direxists(st_local("p"))))
        if `_dircheck' == 0 {
            di as error "Directory does not exist:"
            di as error "`p'"
            exit 601
        }

        // Save to registry
        preserve
            use "`regfile'", clear
            drop if lower(key) == "`k'"
            set obs `=_N+1'
            replace key  = "`k'"   in L
            replace root = "`p'"   in L
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

    // Normalize stored root path
    mata: st_local("root", subinstr(st_local("root"), "\", "/", .))
    
    // Validate stored root still exists
    mata: st_local("_dircheck", strofreal(direxists(st_local("root"))))
    if `_dircheck' == 0 {
        di as error "Stored project root no longer exists on this machine:"
        di as error "`root'"
        exit 601
    }

    global PROJROOT "`root'"
    return local root "`root'"

    if "`cd'" != "" {
        cd "`root'"
        di "`c(pwd)'"
    }
end
