
import std/[strformat, strutils]
import checksums/sha1

const root_html* ="""
<html>
<head>
<meta charset="utf-8">
<link rel="stylesheet" href="gitrelief.css">
<title></title>
</head>
<body>
<table class='head'>
<tr><td><h1>Start</h1></td><td><h1>Root</h1></td><td colspan='3'><h1>git ...</h1></td></tr>
<tr class='head'><td>&nbsp;</td><td>pwd</td>
    <td><a href="/git/log">Log</a></td>
    <td><a href="/git/diff">Diff</a></td>
    <td><a href="/git/diff?staged">Diff (staged)</a></td></tr>
</table>
<p>localfiles</p>
</body>
</html>
"""

const gitrelief_css* ="""
body {
    font-family: Courier;
    font-size: 18pt;
}
h1, h2, h3 {
    margin: 0
}
table.nolines {
    border-style: none;
}
table.nolines tr {
    border-style: none;
}
table.nolines tr td {
    border-style: none;
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
tr.head td {
    font-size:120%;
}

tr.highlight td {
    background-color: lightgray;
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

func url_diff*(parent,commit: string, staged: bool, path:string, oldpath:string = ""): string=
    var X: seq[string]
    if parent!="" and commit!="":
        X.add "a="&parent
        X.add "b="&commit
    elif parent!="":
        X.add "a="&parent
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

func url_diff*(parent, commit: SecureHash, staged: bool, path:string, oldpath:string = ""): string=
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

when ismainmodule:
    let shademo="934e2293ead91cad3ce2ac665e8673ce8d30a3d9"
    let hash1: SecureHash=parsesecurehash(shademo)
    assert(shamatch(hash1, shademo))
    for j in 0..40:
        assert(shamatch(hash1, shademo.substr(0,j)))
