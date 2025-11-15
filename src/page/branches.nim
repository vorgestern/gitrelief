
import std/[tables, strformat, strutils, times, paths, dirs, sequtils, sugar]
import git/processes
import mehr/helper

func htmlescape(s: string): string=replace(s, "<", "&lt;")

const html_template="""
<html>
<head>
<meta charset="utf-8">
<link rel="stylesheet" href="{html_cssurl}">
<title>{html_title}</title>
</head>
<body>
<table>
<tr><th>Navigate</th><th>Command</th></tr>
<tr><td><a href='/'>Start</a></td><td>{html_cmd}</td></tr>
</table>
<p/>
{html_content}
</body></html>
"""

proc page_branches*(Args: Table[string,string]): string=
    let
        branchnames=gitbranches_local()
        branchinfo=block:
            var T="\n<tr>"
            for b in branchnames:
                T.add "<td>"
                let A=gitrevlist([b], [])[0..3]
                for hash in A:
                    let commit=gitcommit(hash)
                    var comments=htmlescape(commit.subject)
                    for d in commit.details: comments.add "<br/>"&htmlescape(d)
                    let inf=commit.date.format("d. MMM HH:mm") & " <b>" & htmlescape(commit.author) & "</b><br/>" & comments
                    T.add inf&"<br/>"
                T.add "</td>"
            T & "</tr>"
    let
        html_cssurl="/gitrelief.css"
        html_title="status"
        html_cmd=""
        html_content=block:
            var X="<table>"
            X.add "<tr>"
            for b in branchnames: X.add "<th>" & htmlescape(b) & "</th>"
            X.add "</tr>"
            X.add branchinfo
            X.add "</table>"
            X
    return fmt html_template
