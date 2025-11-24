
import std/tables
import gitqueries

proc action_stage*(Args: Table[string,string]): string=
    if not Args.contains "path": return "Error"
    let path=Args["path"]
    let cmd {.used.}=gitstage(path)
    return "Ok"

proc action_unstage*(Args: Table[string,string]): string=
    if not Args.contains "path": return "Error"
    let path=Args["path"]
    let cmd {.used.}=gitunstage(path)
    return "Ok"
