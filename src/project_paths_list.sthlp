{smcl}
{* *! version 1.0  19jan2026}{...}
{title:Title}

{p 4 8 2}
{cmd:project_paths_list} — Per-user registry of project roots (dotenv-like paths)

{title:Syntax}

{p 8 12 2}
{cmd:project_paths_list, project(}{it:key}{cmd:) [cd]}

{p 8 12 2}
{cmd:project_paths_list, add project(}{it:key}{cmd:) path("}{it:dir}{cmd:")}

{p 8 12 2}
{cmd:project_paths_list, remove project(}{it:key}{cmd:)}

{p 8 12 2}
{cmd:project_paths_list, list}

{p 8 12 2}
{cmd:project_paths_list, where}

{title:Description}

{p 4 8 2}
Stores and retrieves project root directories in a per-user registry file located in the user's
{cmd:PERSONAL} Stata directory. In {cmd:project(key)} mode it sets {cmd:$PROJROOT} and returns {cmd:r(root)}.

{title:Examples}

{p 8 12 2}
{cmd:. project_paths_list, add project(polymarket) path("C:/_git/polymarket-earnings")}

{p 8 12 2}
{cmd:. project_paths_list, list}

{p 8 12 2}
{cmd:. project_paths_list, project(polymarket) cd}

{p 8 12 2}
{cmd:. di "$PROJROOT"}

{title:Stored data}

{p 4 8 2}
Registry file: {it:PERSONAL}/project_paths_registry.dta
Use {cmd:project_paths_list, where} to print the exact location.

{title:Author}

{p 4 8 2}
Eric Weisbrod (and contributors)
