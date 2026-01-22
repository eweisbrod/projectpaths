# projectpaths (Stata)

A tiny Stata utility that gives you **dotenv-like project roots** without hardcoding absolute paths in do-files.

The package maintains a **per-user registry** of project root directories and exposes a single “one-liner” you can put at the top of any do-file:

```stata
project_paths_list, project(my-project) cd
````

* If `my-project` is not registered yet (interactive Stata), it will **prompt you once** for the root path and save it.
* After that, it just works on that machine.


---

## Install

From GitHub (recommended):

```stata
cap ado uninstall projectpaths
net install projectpaths, from("https://raw.githubusercontent.com/eweisbrod/projectpaths/main/src/") replace
```

Verify:

```stata
which project_paths_list
help project_paths_list
project_paths_list, where
```

---

## What it stores (per user)

A registry file is stored in your Stata `PERSONAL` directory:

* `PERSONAL/project_paths_registry.dta`

You can see the exact locations on your machine with:

```stata
project_paths_list, where
```

This registry is **not** meant to be committed to your paper/repo. It is **machine-specific**, like a `.env` file.

---

## Typical workflow (recommended)

### 1) Put this at the top of every project do-file (one line)

```stata
project_paths_list, project(polymarket) cd
```

That’s it.

* First time on a new machine: Stata pops up a dialog asking for the root path (e.g., `C:/_git/polymarket-earnings`), saves it, and continues.
* Subsequent runs: no dialog; it simply sets `$PROJROOT` and optionally `cd`s there.

### 2) Use `$PROJROOT` in paths

```stata
use "$PROJROOT/data/raw/mydata.dta", clear
save "$PROJROOT/data/derived/mydata_clean.dta", replace
```

---

## Explicit “add/update” (optional)

If you want to register a path without relying on the automatic prompt:

```stata
project_paths_list, add project(polymarket) path("C:/_git/polymarket-earnings")
```

List everything you’ve registered:

```stata
project_paths_list, list
```

Remove a key:

```stata
project_paths_list, remove project(polymarket)
```

---

## Batch / CI / non-interactive runs

In batch mode, popup dialogs can hang a job. To guarantee **no prompts**, use `noprompt`:

```stata
project_paths_list, project(polymarket) cd noprompt
```

If the key is missing or the stored path is invalid, the command will error with instructions for registering it.

---

## Naming projects (keys)

* Keys are **case-insensitive**.
* Keys may include **hyphens**, e.g. `example-project`.

Examples:

```stata
project_paths_list, project(example-project) cd
project_paths_list, add project(example-project) path("D:/work/example-project")
```

---

## Suggested coauthor guidance

If you’re collaborating, tell coauthors:

1. Install `projectpaths` once.
2. Run the project do-file.
3. If prompted, paste their local project root path.
4. Never hardcode absolute paths into shared do-files; always use `$PROJROOT`.

---

## Troubleshooting

### “command project_paths_list not found”

Reinstall and confirm Stata can locate the command:

```stata
net install projectpaths, from("https://raw.githubusercontent.com/eweisbrod/projectpaths/main/src/") replace
which project_paths_list
```

### “Unknown project key …”

Run interactively once (without `noprompt`) so you can register it:

```stata
project_paths_list, project(mykey) cd
```

Or add explicitly:

```stata
project_paths_list, add project(mykey) path("C:/path/to/project")
```

### “Stored project root no longer exists…”

Run interactively (no `noprompt`) and it will prompt you to update the path.

---

## License

MIT (see `LICENSE`).


