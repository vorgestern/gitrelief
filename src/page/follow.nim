
import std/[tables, strformat]
import std/[strutils, times]
import std/strtabs
import npeg

import mehr/helper
import git/processes

func htmlescape(s: string): string=replace(s, "<", "&lt;")

const html_template="""
<html>
<head>
<meta charset="utf-8">
<title>{htmlescape title}</title>
<link rel="stylesheet" href="{cssurl}">
</head>
<body>
<table>
<tr><th>Navigate</th><th>Command</th></tr>
<tr><td><a href='/'>Start</a></td><td>{htmlescape cmd}</td></tr>
</table>
<p>Following &nbsp;&nbsp;&nbsp;&nbsp;<b>{pathtofollow}</b></p>
{content}
</body>
</html>
"""

let TMonat {.used.}={"01": "Jan", "02": "Feb", "03": "Mär", "04": "Apr", "05": "Mai", "06": "Jun",
            "07": "Jul", "08": "Aug", "09": "Sep", "10": "Okt", "11": "Nov", "12": "Dez"}.newstringtable

proc format_html(L: seq[Commit], highlight=""): string=
    result="<table class='diff'>"
    for commitindex,commit in L:
        var comments=htmlescape(commit.subject)
        for d in commit.details: comments.add "<br/>"&htmlescape(d)
        let parent=if commit.parents.len>0: commit.parents[0] else: shanull
        var files=""
        for fileindex,op in commit.files:
            if fileindex>0: files.add "<br/>"
            let url=url_diff(parent, commit.hash, false, op)
            if op.status==Renamed:  files.add fmt"<a href='{url}'>{op.status}</a><br/>to {op.newpath}<br/>from {op.oldpath}"
            elif op.status==Added:  files.add fmt"<a href='{url}'>{op.status}</a><br/>{op.path}"
            elif commitindex==0:    files.add fmt"<a href='{url}'>{op.status}</a><br/>{op.path}"
            else:                   files.add fmt"<a href='{url}'>{op.status}</a>"
        let hx=shaform commit.hash
        let
            tr=if shamatch(commit.hash, highlight): "\n<tr class='highlight'>" else: "\n<tr>"
            tdanchor=fmt"<td><a id='tr_{hx}'/>{hx}</a></td>"
            tdauthor="<td>"&commit.author&"</td>"
            tddate="<td>" & commit.date.format("d. MMM HH:mm") & "</td>"
            tdaffected="<td>"&files&"</td>"
            tdcomments="<td>"&comments&"</td>"
        result.add tr & tdanchor & tdauthor & tddate & tdaffected & tdcomments & "</tr>"
    result.add "</table>"

proc page_follow*(Args: Table[string,string]): string=
    let
        pathtofollow=Args.getordefault("path", "???")
        num=parseint Args.getordefault("num", "100")
        commithash=Args.getordefault("highlight", "")
    let (L,cmd)=gitfollow(pathtofollow, num)
    let
        title="log_follow"
        cssurl="/gitrelief.css"
        content=format_html(L, commithash)
    return fmt html_template

# =====================================================================

when ismainmodule:
    # let ts="2025-11-10T17:39:33+01:00"
    let ts="2025-11-10T17:39:33"
    let dt=times.parse(ts, "yyyy-MM-dd'T'HH:mm:ss")
    echo "dt=",$dt
