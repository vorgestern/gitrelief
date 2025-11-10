
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

<p><table class='nolines'>
<tr><td/><td>{htmlescape cmd}</td></tr>
<tr><td><h2>Local files</h2>{localfiles}</td><td>{content}</td></tr>
</table></p>
</body></html>
"""

proc walkpublicdir(dir: Path): string=
    var dir1=dir
    normalizepathend(dir1, true)
    for path in walkdirrec(dir1):
        let p=replace(string path, string dir1, "")
        result.add fmt"{'\n'}<tr><td></td><td><a href='{p}'>{p}</a></td></tr>"

proc format_html(Status: RepoStatus): string=
    result="<p><h2>Staged</h2><table>"
    for index,entry in Status.staged:
        result.add fmt"<tr><td>{entry.status}</td><td><a href='{url_diff shanull, shanull, true, entry.path}'>diff</a> <a href='{url_follow entry.path}'>follow</a></td><td>{entry.path}</td></tr>"
    result.add "</table></p>"
    result.add "<p><h2>Not staged</h2><table>"
    for index,entry in Status.unstaged:
        result.add fmt"<tr><td>{entry.status}</td><td><a href='{url_diff shanull, shanull, false, entry.path}'>diff</a> <a href='{url_follow entry.path}'>follow</a></td><td>{entry.path}</td></tr>"
    result.add "</table></p>"
    result.add "<p><h2>Not controlled</h2><table>"
    for index,entry in Status.notcontrolled:
        result.add fmt"<tr><td>{entry}</td></tr>"
    result.add "</table></p>"
    result.add "<p><h2>Failed to parse</h2><table>"
    for index,entry in Status.unparsed:
        result.add fmt"<tr><td>{entry}</td></tr>"
    result.add "</table></p>"

proc page_status*(Args: Table[string,string], publicdir: string): string=
    let
        (Status,cmd)=gitstatus()
        title="status"
        cssurl="/gitrelief.css"
        content=format_html(Status)
        pwd=block:
            var X=getcurrentdir()
            normalizepath(X)
            X
        localfiles="<table>" & walkpublicdir(Path publicdir) & "</table>"
    return fmt html_template
