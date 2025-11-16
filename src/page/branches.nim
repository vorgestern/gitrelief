
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
<h2>Local Branches</h2>
<table>
<tr><th>branch</th><th>A</th><th>B</th></tr>
{html_localbranches}
</table>

<p/>
<h2>Branches (neue Ansicht)</h2>
{html_showbranches}

<p/>
<h2>Branches (bisherige Ansicht)</h2>
{html_content}
</body></html>
"""

proc page_branches*(Args: Table[string,string]): string=
    let
        mastername=if Args.contains "m": Args["m"] else: ""
        branchname=if Args.contains "b": Args["b"] else: ""
        branchnames=gitbranches_local()
    let
        html_cssurl="/gitrelief.css"
        html_title="status"
        html_cmd=""
        html_showbranches=block:
            let (SB, cmd)=gitshowbranches([mastername, branchname])
            var X="<p>" & cmd & "</p><p>"
            for k in SB.branches: X.add "&nbsp;"&k
            X.add "</p><table>"
            for k in SB.commits: X.add "<tr><td>" & k.tags & "</td><td>" & k.hash & "</td><td>" & k.subject & "</td></tr>"
            X.add "</table>"
            X
        html_localbranches=block:
            var X=""
            for b in branchnames:
                let b1=htmlescape b
                let td2=if b!=mastername: fmt"<td class='re'><a href='{url_branches b, branchname}'>select</a></td>"
                else:                     "<td>A="&htmlescape(b)&"</td>"
                let td3=if b!=branchname: fmt"<td class='re'><a href='{url_branches mastername, b}'>select</a></td>"
                else:                     "<td>B="&htmlescape(b)&"</td>"
                X.add "\n" & fmt"<tr><td>{b1}</td>{td2}{td3}</tr>"
            X
    let
        branchinfo=block:
            var T="\n<tr>"
            for b in branchnames:
                T.add "<td>"
                let A=block:
                    var X=if b=="master": gitrevlist(["master"], [])
                    else:
                        let X1=gitrevlist([b], ["master"])
                        if X1.len>0: X1
                        else:
                            let X2=gitrevlist([b], [])
                            if X2.len>0: X2[0..0]
                            else: X2
                    if X.len>10: X[0..9]
                    else: X
                for hash in A:
                    let commit=gitcommit(hash)
                    var comments=htmlescape(commit.subject)
                    for d in commit.details: comments.add "<br/>"&htmlescape(d)
                    let inf=commit.date.format("d. MMM HH:mm") & " <b>" & htmlescape(commit.author) & "</b><br/>" & comments
                    T.add inf&"<br/>"
                T.add "</td>"
            T & "</tr>"
        html_content=block:
            var X="<table>"
            X.add "<tr>"
            for b in branchnames: X.add "<th>" & htmlescape(b) & "</th>"
            X.add "</tr>"
            X.add branchinfo
            X.add "</table>"
            X
    return fmt html_template
