
import std/[osproc, strutils, strformat, streams]
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

proc gitdiff*(a, b: SecureHash, paths: openarray[string]): tuple[diffs: seq[FileDiff], cmd: string] =
    var args= @["diff", "-U999999"]
    if a!=shanull and b!=shanull: args.add shaform(a) & ".." & shaform(b)
    elif a!=shanull: args.add shaform a
    if paths.len>0:
        args.add "--"
        for p in paths: args.add p
    (parse_diff(exec_path("git", args)), "git" & concat(args))

proc gitdiff_staged*(a, b: SecureHash, paths: openarray[string]): tuple[diffs: seq[FileDiff], cmd: string] =
    var args= @["diff", "-U999999", "--staged"]
    if a!=shanull and b!=shanull: args.add shaform(a) & ".." & shaform(b)
    elif a!=shanull: args.add shaform a
    if paths.len>0:
        args.add "--"
        for p in paths: args.add p
    (parse_diff(exec_path("git", args)), "git" & concat(args))

# =====================================================================
#               gitstatus

proc gitstatus*(): tuple[status: RepoStatus, cmd: string] =
    let args= @["status", "--porcelain", "-uall"]
    (parse_status(exec_path("git", args)), "git" & concat(args))

# =====================================================================
#               gitfollow

proc gitfollow*(path: string, num: int): tuple[result: seq[Commit], cmd: string]=
    let args=block:
        var X= @["log", "--follow", "--name-status", "--parents", "--date=iso-local"]
        X.add if num>0: "-" & $num else: "-100"
        X.add "--"
        X.add path
        X
    (parse_log exec_path("git", args), "git" & concat(args))

# =====================================================================
#               gitlog

proc gitlog*(num: int): tuple[commits: seq[Commit], cmd: string]=
    let args=block:
        var A= @["log", "--name-status", "--parents", "--date=iso-local"]
        if num>0: A.add fmt"-{num}"
        A
    (parse_log exec_path("git", args), "git" & concat(args))

# =====================================================================

proc gitcompletehash*(hash: string): SecureHash=
    let Lines=exec_path("git", ["rev-list", "--max-count=1", "--skip=#", hash])
    if Lines.len==1: parsesecurehash Lines[0]
    else:            shanull
proc gitstage*(path: string): string=exec_path_text("git", ["add", path])
proc gitunstage*(path: string): string=exec_path_text("git", ["restore", "--staged", path])

# =====================================================================
#               gitremotes

proc gitremotes*(): remoteinfo=parse_remote_v(exec_path("git", ["remote", "-v"]))

# =====================================================================
#               gitbranches_local
#               gitbranches_remote

proc parse_branches_remote(L: seq[string], remotename: string): seq[string]=
    let s=remotename & "/"
    for k in L:
        let k1=k.substr(2)
        if k1.startswith s: result.add k1.substr(s.len)
        else:
            echo "fail startswith '", k, "': ", s
            result.add "?? " & k

proc parse_branches_local(L: seq[string]): seq[string]=
    for k in L: result.add k.substr(2)

proc gitbranches_local*(): seq[string]= parse_branches_local(exec_path("git", ["branch", "-l"]))
proc gitbranches_remote*(remotename: string): seq[string]= parse_branches_remote(exec_path("git", ["branch", "-rl", remotename & "/*"]), remotename)

# =====================================================================
#               gitrevlist

# Ermittle die Liste der Hashes die von einem der inclbranches erreichbar sind,
# aber von keinem der exclbranches.
# Einfachste Anwendung: 
# gitrevlist(["datetime"], ["master"]) ermittelt die commits, die von dem Zweig 'datetime'
#     erreichbar, aber noch nicht in den Zweig 'master' gemergt wurden. Wenn diese Liste leer ist,
#     ist der Zweig 'datetime' volltändig in 'master' übernommen.
proc gitrevlist*(inclbranches, exclbranches: openarray[string]): seq[SecureHash]=
    var args= @["rev-list", "--topo-order", "--reverse"]
    for k in inclbranches: args.add k
    for k in exclbranches: args.add "^"&k
    let Lines=exec_path("git", args)
    for k in Lines: result.add parsesecurehash k

# So findet man auf der Kommandozeile den ältesten commit in datetime,
# der nicht in den master übernommen wurde.
# git rev-list --topo-order --reverse datetime ^master | head -1

# =====================================================================

func url_diff*(parent, commit: SecureHash, staged: bool, op: CommittedOperation): string=
    var X: seq[string]
    if parent!=shanull and commit!=shanull:
        X.add "a="&shaform parent
        X.add "b="&shaform commit
    elif parent!=shanull:
        X.add "a="&shaform parent
    if staged:
        X.add "staged"
    case op.status
    of Renamed:
        X.add "path="&op.newpath
        X.add "oldpath="&op.oldpath
    else:
        X.add "path="&op.path
    var url="/git/diff"
    for j,q in X:
        url.add if j==0: "?" else: "&"
        url.add q
    url
