
import std/[strformat, strutils]
import checksums/sha1

const gitrelief_css* ="""
body {
    font-family: Courier;
    font-size: 18pt;
}
h1, h2, h3 {
    margin: 0
}

table.status {
    border-style: none;
}
table.status tr {
    border-style: none;
}
table.status tr td {
    border-style: none;
}
/*table.status tr td:nth-child(odd) {
    border-style: none;
    background-color: lightgray;
}*/
th.status1, td.status1 {
    border-style: none;
    background-color: lightgray;
}
th.status2, td.status2 {
    border-style: none;
    background-color: white;
}

table.nolines {
    border-style: none;
}
table.nolines tr {
    border-style: none;
}
table.nolines tr td {
    border-style: none;
    background-color: white;
}

table.showbranch tr td {
    padding: 0 0.2em 0;
    /* background-color: yellow; */
    white-space: pre;
}

table.showbranch tr td:nth-last-child(1) {
    /* background-color: lightgray; */
    white-space: normal;
    padding:0 .5em 0;
}

table.showbranch tr td:nth-last-child(2) {
    /* background-color: lightgray; */
    white-space: normal;
    padding:0 .5em 0;
}

table {
    border-style: solid;
    border-width: 1px;
    border-collapse: collapse;
}
td, tr {
    border-style: dashed;
    border-width: 1px;
    border-color:lightgray;
    vertical-align: top;
    padding:0 .5em 0;
}
th {
    padding:0 .5em 0;
    text-align: left;
}
table.diff tr td {
    white-space: pre;
    font-size: 70%;
}

/* table.diff tr td:first-of-type {
    font-family: cursive;
    color: white;
    background-color: green;
}*/
/*table.diff tr td:nth-child(3) {
    border-left: 5px solid white;
}*/
td.yeven {
    border-left: 5px solid red;
}
td.yodd {
    border-left: 5px solid yellow;
}

tr.head td {
    font-size:120%;
}

tr.highlight td {
    background-color: lightgray;
}

tr.newyear {
    font-size: 200%;
}

td.re {
    text-align: right;
}

td.Acmp {
    width:50em;
    white-space: pre;
    color: red;
    /*
    text-overflow: ellipsis;
    white-space: nowrap;
    overflow: hidden; */
}
td.Acmp span {
        /*  span mit fester Breite */
            display: inline-block;
            width: 3em;
        color: black;
        background-color: #f88;
        padding: 0 0.5em 0 0;
}
td.Bcmp {
    color: green;
    width:50em;
    white-space: pre;
}
td.Bcmp span {
        /*  span mit fester Breite */
            display: inline-block;
            width: 3em;
        color: black;
        background-color: #8f8;
        padding: 0 0.5em 0 0;
}
td.Ncmp {
    color:black;
    white-space: pre;
}
td.Ncmp span {
        /*  span mit fester Breite */
            display: inline-block;
            width: 3em;
        color: black;
        background-color: white;
        padding: 0 0.5em 0 0;
}
"""

func shamatch*(sha: SecureHash, h: string): bool=h.len>0 and h.len<=40 and cmpignorecase(substr($sha, 0, h.len-1), h)==0
func shaform*(sha: SecureHash): string=substr($sha, 0, 9)
const shanull* =parsesecurehash "0000000000000000000000000000000000000000"

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
