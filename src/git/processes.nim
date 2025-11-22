
import std/[osproc, strformat, streams, paths]
import checksums/sha1
import mehr/helper
import parsers

export sha1
export parsers

proc exec_path(command: string, args: openarray[string]): seq[string]=
    let p=startprocess(command, args=args, options={poUsePath})
    let pipe=outputstream(p)
    var line:  string
    while readline(pipe, line): result.add line
    close p

proc exec_path_text(command: string, args: openarray[string]): string=
    let p=startprocess(command, args=args, options={poUsePath})
    let pipe=outputstream(p)
    var line:  string
    while readline(pipe, line): result.add line & "\n"
    close p

# =====================================================================

proc gitdiff*(a, b: SecureHash, staged: bool, paths: openarray[string]): tuple[diffs: seq[FileDiff], cmd: string] =
    var args= @["diff", "-U999999", "--full-history"]
    if staged: args.add "--staged"
    if a!=shanull and b!=shanull: args.add shaform(a) & ".." & shaform(b)
    elif a!=shanull: args.add shaform a
    if paths.len>0:
        args.add "--"
        for p in paths: args.add p
    (parse_diff(exec_path("git", args)), "git" & concat(args))

proc gitstatus*(): tuple[status: RepoStatus, cmd: string] =
    let args= @["status", "--porcelain", "-uall"]
    (parse_status(exec_path("git", args)), "git" & concat(args))

proc gitstatus_v2*(): tuple[status: RepoStatus_v2, cmd: string] =
    let args= @["status", "-b", "--porcelain=v2", "-uall"]
    (parse_status_v2(exec_path("git", args)), "git" & concat(args))

proc gitfollow*(path: Path, num: int): tuple[result: seq[Commit], cmd: string]=
    let args=block:
        var X= @["log", "--follow", "--name-status", "--parents", "--first-parent", "--date=iso-local"]
        X.add if num>0: "-" & $num else: "-100"
        X.add "--"
        X.add $path
        X
    (parse_log exec_path("git", args), "git" & concat(args))

proc gitlog*(num: int): tuple[commits: seq[Commit], cmd: string]=
    let args=block:
        var A= @["log", "--name-status", "--parents", "--first-parent", "--date=iso-local"]
        if num>0: A.add fmt"-{num}"
        A
    (parse_log exec_path("git", args), "git" & concat(args))

proc gitcommit*(hash: SecureHash): Commit=
    let X=parse_log exec_path("git", ["log", "--name-status", "--parents", "--date=iso-local", $hash, "-1"])
    return if X.len==1: X[0]
    else: Commit()

proc gitcommit*(hash: string): Commit=
    let X=parse_log exec_path("git", ["log", "--name-status", "--parents", "--date=iso-local", hash, "-1"])
    return if X.len==1: X[0]
    else: Commit()

proc gitcompletehash*(hash: string): SecureHash=
    let Lines=exec_path("git", ["rev-list", "--max-count=1", "--skip=#", hash])
    if Lines.len==1: parsesecurehash Lines[0]
    else:            shanull

proc gitstage*(path: string): string=exec_path_text("git", ["add", path])

proc gitunstage*(path: string): string=exec_path_text("git", ["restore", "--staged", path])

proc gitremotes*(): remoteinfo=parse_remote_v(exec_path("git", ["remote", "-v"]))

proc gitbranches_local*(): seq[string]= parse_branches_local(exec_path("git", ["branch", "-l"]))

proc gitbranches_remote*(remotename: string): seq[string]= parse_branches_remote(exec_path("git", ["branch", "-rl", remotename & "/*"]), remotename)

# Ermittle die Liste der Hashes die von einem der inclbranches erreichbar sind,
# aber von keinem der exclbranches.
# Einfachste Anwendung: 
# gitrevlist(["datetime"], ["master"]) ermittelt die commits, die von dem Zweig 'datetime'
#     erreichbar, aber noch nicht in den Zweig 'master' gemergt wurden. Wenn diese Liste leer ist,
#     ist der Zweig 'datetime' volltändig in 'master' übernommen.
proc gitrevlist*(inclbranches, exclbranches: openarray[string]): seq[SecureHash]=
    var args= @["rev-list", "--topo-order"] # "--reverse"
    for k in inclbranches: args.add k
    for k in exclbranches: args.add "^"&k
    let Lines=exec_path("git", args)
    for k in Lines: result.add parsesecurehash k

# So findet man auf der Kommandozeile den ältesten commit in datetime,
# der nicht in den master übernommen wurde.
# git rev-list --topo-order --reverse datetime ^master | head -1

proc gitshowbranches*(branchnames: openarray[string]): tuple[result: ShowBranch, cmd: string]=
    var args= @["show-branch", "--date-order", "--color=never", "--sha1-name"]
    for b in branchnames: args.add b
    let cmd=block:
        var X="git"
        for k in args: X.add " "&k
        X
    (parse_show_branches(exec_path("git", args)), cmd)
