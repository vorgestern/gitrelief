
import std/[tables, strformat, strutils]
import std/[paths,dirs]
import git/processes
import mehr/helper

func htmlescape(s: string): string=replace(s, "<", "&lt;")

const html_template="""
<html>
<head>
<meta charset="utf-8">
<link rel="stylesheet" href="{cssurl}">
<title>{htmlescape title}</title>
</head>
<body>

<p><table class='head'>
<tr><td><h1>Start</h1></td><td><h1>Root</h1></td><td colspan='3'><h1>git ...</h1></td></tr>
<tr class='head'><td>&nbsp;</td><td>{pwd}</td>
    <td><a href="/git/log">Log</a></td>
    <td><a href="/git/diff">Diff</a></td>
    <td><a href="/git/diff?staged">Diff (staged)</a></td></tr>
</table></p>

<p><table class='status'>
<tr><th class='status1'><h2>Public Files</h2></th><th class='status2'><h2>Status</h2></th><th class='status1'><h2>Not controlled</h2></th><th class='status2'><h2>Failed to Parse</h2></th></tr>
<tr><td class='status1'>{localfiles}</td><td class='status2'>{controlled}</td><td class='status1'>{notcontrolled}</td><td class='status2'>{failedtoparse}</td></tr>
</table></p>

<table class='status'>
<tr><td class='status1'><h2>Remotes</h2>
<table>
<tr><th>name</th><th>fetch</th><th>push</th></tr>
{remoteurls}
</table>
</td>

<td class='status2'><h2>Branches</h2>
<table>
{branches}
</table>
</td></tr></table>
</body></html>
"""

proc walkpublicdir(dir: Path): string=
    var dir1=dir
    normalizepathend(dir1, true)
    for path in walkdirrec(dir1):
        let p=replace(string path, string dir1, "")
        result.add fmt"{'\n'}<tr><td></td><td><a href='{p}'>{p}</a></td></tr>"

proc format_html(Status: RepoStatus): tuple[a,b,c: string]=
    var A="<h3>Staged</h3><table class='nolines'>"
    for index,entry in Status.staged:
        let diff="\n    <a href='" & url_diff(shanull, shanull, true, entry.path) & "'>diff</a>"
        let follow="\n    <a href='" & url_follow(entry.path) & "'>follow</a>"
        let unstage="\n    <a href='" & url_unstage(entry.path) & "'>unstage</a>"
        A.add "\n" & fmt"<tr><td>{entry.status}</td><td>{diff}{follow}{unstage}</td><td>{entry.path}</td></tr>"
    A.add "</table>"

    A.add "<h3>Not staged</h3><table class='nolines'>"
    for index,entry in Status.unstaged:
        let diff="\n    <a href='" & url_diff(shanull, shanull, false, entry.path) & "'>diff</a>"
        let follow="\n    <a href='" & url_follow(entry.path) & "'>follow</a>"
        let stage="\n    <a href='" & url_stage(entry.path) & "'>stage</a>"
        A.add "\n" & fmt"<tr><td>{entry.status}</td><td>{diff}{follow}{stage}</td><td>{entry.path}</td></tr>"
    A.add "</table>"

    var B="<table>"
    for index,entry in Status.notcontrolled:
        let stage="<a href='" & url_stage(entry) & "'>stage</a>"
        B.add "\n" & fmt"<tr><td>{entry}</td><td>{stage}</td></tr>"
    B.add "</table>"

    var C="<table class='nolines'>"
    for index,entry in Status.unparsed: C.add fmt"<tr><td>{entry}</td></tr>"
    C.add "</table></p>"
    (A,B,C)

# =====================================================================

proc page_status*(Args: Table[string,string], publicdir: string): string=
    let
        (Status,_)=gitstatus()
        title="status"
        cssurl="/gitrelief.css"
        (controlled,notcontrolled,failedtoparse)=format_html(Status)
        pwd=block:
            var X=getcurrentdir()
            normalizepath(X)
            X
        localfiles="<table>" & walkpublicdir(Path publicdir) & "</table>"

    let
        R=gitremotes()
    let
        remotenames=block:
            var X: seq[string]
            for k in keys(R): X.add k
            X
        remoteurls=block:
            var X=""
            for (name,urls) in pairs(R):
                if urls.fetchurl!=urls.pushurl: X.add "<tr><td>" & htmlescape(name) & "</td><td>" & htmlescape(urls.fetchurl) & "</td><td>" & htmlescape(urls.pushurl) & "</td></tr>"
                else:  X.add "<tr><td>" & htmlescape(name) & "</td><td colspan='2'>" & htmlescape(urls.fetchurl) & "</td></tr>"
            X
    let
        branches=block:
            var X="<tr><th>(local)</th>"
            for k in remotenames: X.add "<th>remotes/" & htmlescape(k) & "</th>"
            X.add "</tr>\n<tr>\n<td>\n"
            for k in gitbranches_local(): X.add htmlescape(k) & "<br/>"
            X.add "</td>"
            for remote in remotenames:
                let rembranches=gitbranches_remote(remote)
                X.add "\n<td>"
                for b in rembranches: X.add htmlescape(b) & "<br/>"
                X.add "</td>"
            X.add "</tr>"
            X

    return fmt html_template
