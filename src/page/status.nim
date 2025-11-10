
import std/[tables, strformat, strutils]
import mehr/helper
import git/processes

func htmlescape(s: string): string=replace(s, "<", "&lt;")

const html_template="""
<html>
<head>
<meta charset="utf-8">
<link rel="stylesheet" href="{cssurl}">
<title>{htmlescape title}</title>
</head>
<body>
<table>
<tr><th>Navigate</th><th>Command</th></tr>
<tr><td><a href='/'>Start</a></td><td>{htmlescape cmd}</td></tr>
</table>
{content}
</body></html>
"""

proc format_html(Status: RepoStatus): string=
    result.add "<p><h2>Staged</h2><table>"
    for index,entry in Status.staged:
        result.add fmt"<tr><td>{entry.status}</td><td><a href=''>diff</a> <a href=''>follow</a></td><td>{entry.path}</td></tr>"
    result.add "</table></p>"

    result.add "<p><h2>Not staged</h2><table>"
    for index,entry in Status.unstaged:
        result.add fmt"<tr><td>{entry.status}</td><td><a href=''>diff</a> <a href=''>follow</a></td><td>{entry.path}</td></tr>"
    result.add "</table></p>"
    result.add "<p><h2>Not controlled</h2><table>"
    for index,entry in Status.notcontrolled:
        result.add fmt"<tr><td>{entry}</td></tr>"
    result.add "</table></p>"
    result.add "<p><h2>Failed to parse</h2><table>"
    for index,entry in Status.unparsed:
        result.add fmt"<tr><td>{entry}</td></tr>"
    result.add "</table></p>"

proc git_status*(Args: Table[string,string]): string=
    let (Status,cmd)=gitstatus()
    let
        title="status"
        cssurl="/gitrelief.css"
        content=format_html(Status)
    return fmt html_template
