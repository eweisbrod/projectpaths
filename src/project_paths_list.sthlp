{smcl}
{* *! version 1.1  21jan2026}{...}
{title:Title}

{p 4 8 2}
{cmd:project_paths_list} — Per-user registry of project roots (dotenv-like), with interactive fallback

{title:Syntax}

{p 8 12 2}
Resolve a project root (default mode):
{p_end}
{p 12 12 2}
{cmd:project_paths_list, project(}{it:key}{cmd:) [cd] [noprompt]}

{p 8 12 2}
Add or update a project root (upsert):
{p_end}
{p 12 12 2}
{cmd:project_paths_list, add project(}{it:key}{cmd:) path("}{it:dir}{cmd:")}

{p 8 12 2}
Remove a key:
{p_end}
{p 12 12 2}
{cmd:project_paths_list, remove project(}{it:key}{cmd:)}

{p 8 12 2}
List all registered keys:
{p_end}
{p 12 12 2}
{cmd:project_paths_list, list}

{p 8 12 2}
Show registry location:
{p_end}
{p 12 12 2}
{cmd:project_paths_list, where}

{title:Description}

{p 4 8 2}
{cmd:project_paths_list} stores project root directories in a per-user registry file located in the user's
{cmd:PERSONAL} Stata directory. In default mode ({cmd:project(key)}), it sets {cmd:$PROJROOT} and returns
the resolved root as {cmd:r(root)}.

{p 4 8 2}
Interactive fallback: If {cmd:project(key)} is requested but {it:key} is not found in the registry, and Stata
is running interactively, {cmd:project_paths_list} prompts you to enter the root directory path, saves it to
the registry, then continues. If the key exists but the stored directory no longer exists, it similarly prompts
for an updated path and updates the registry.

{p 4 8 2}
Batch-safe behavior: In batch mode (or when {cmd:noprompt} is specified), {cmd:project_paths_list} will never
prompt. If a key is missing or its stored path is invalid, it errors with a message explaining how to add/update
the key.

{title:Options}

{p 4 8 2}
{cmd:project(}{it:key}{cmd:)} specifies the project key. Keys are treated case-insensitively and may include
hyphens (e.g., {cmd:example-project}).

{p 4 8 2}
{cmd:cd} changes Stata's working directory to the resolved project root after resolving it.

{p 4 8 2}
{cmd:noprompt} disables interactive fallback prompts. Use this for batch/CI scripts.

{p 4 8 2}
{cmd:path("}{it:dir}{cmd:")} supplies the project root directory when using {cmd:add}.

{title:Stored data}

{p 4 8 2}
Registry file: {it:PERSONAL}/project_paths_registry.dta
{p_end}
{p 4 8 2}
Use {cmd:project_paths_list, where} to print the exact registry location.

{title:Examples}

{p 8 12 2}
One-line setup (interactive): prompts the first time, then persists:
{p_end}
{p 12 12 2}
{cmd:. project_paths_list, project(polymarket) cd}
{p_end}

{p 8 12 2}
Explicit add/update (no prompts):
{p_end}
{p 12 12 2}
{cmd:. project_paths_list, add project(polymarket) path("C:/_git/polymarket-earnings")}
{p_end}

{p 8 12 2}
Batch/CI safe: never prompts:
{p_end}
{p 12 12 2}
{cmd:. project_paths_list, project(polymarket) cd noprompt}
{p_end}

{p 8 12 2}
Use the resolved root:
{p_end}
{p 12 12 2}
{cmd:. di "$PROJROOT"}
{p_end}
{p 12 12 2}
{cmd:. use "$PROJROOT/data/raw/mydata.dta", clear}

{title:Author}

{p 4 8 2}
Eric Weisbrod (and contributors)
