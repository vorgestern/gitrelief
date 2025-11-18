
import std/[strformat, strutils]
import checksums/sha1

func htmlescape*(s: string): string=replace(s, "<", "&lt;")

func shamatch*(sha: SecureHash, h: string): bool=h.len>0 and h.len<=40 and cmpignorecase(substr($sha, 0, h.len-1), h)==0
func shaform*(sha: SecureHash): string=substr($sha, 0, 9)
const shanull* =parsesecurehash "0000000000000000000000000000000000000000"

var servertitle*: cstring="gitrelief"

func url_log*(num: int, top: int= -1): string=
    if top<0: "/git/log?num=" & $num
    else:     "/git/log?num=" & $num & "#top" & $top

func url_diff*(parent, commit: SecureHash, staged: bool, path:string, oldpath:string=""): string=
    var X: seq[string]
    if parent!=shanull and commit!=shanull:
        X.add "a="&shaform parent
        X.add "b="&shaform commit
    elif parent!=shanull:
        X.add "a="&shaform parent
    if staged:
        X.add "staged"
    if oldpath!="" and path!="":
        X.add "path="&path
        X.add "oldpath="&oldpath
    elif oldpath=="":
        X.add "path="&path
    var url="/git/diff"
    for j,q in X:
        url.add if j==0: "?" else: "&"
        url.add q
    url

func url_follow*(path: string, highlightcommit: SecureHash=shanull): string=
    if highlightcommit==shanull: fmt"/git/follow?path={path}"
    else:                        fmt"/git/follow?path={path}&highlight={highlightcommit}#tr_{shaform highlightcommit}"

func url_follow*(path: string, highlightcommit=""): string=
    if highlightcommit=="": fmt"/git/follow?path={path}"
    else:                   fmt"/git/follow?path={path}&highlight={highlightcommit}#tr_{highlightcommit}"

func url_unstage*(path: string):string =
    "/git/unstage?a=1&path=" & path

func url_stage*(path: string):string =
    "/git/stage?z=1&path=" & path

proc url_branches*(m, b: string):string =
    if m!="" and b!="": fmt"/git/branches?m={m}&b={b}"
    elif m!="":         fmt"/git/branches?m={m}"
    elif b!="":         fmt"/git/branches?b={b}"
    else:               fmt"/git/branches"

func concat*(A: openarray[string]): string=
    var X=""
    for a in A: X=X & " " & a
    X

when ismainmodule:
    let shademo="934e2293ead91cad3ce2ac665e8673ce8d30a3d9"
    let hash1: SecureHash=parsesecurehash(shademo)
    assert(shamatch(hash1, shademo))
    for j in 0..40:
        assert(shamatch(hash1, shademo.substr(0,j)))
