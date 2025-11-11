
import std/[tables, strutils, strformat, parseutils, times]
import npeg
import mehr/helper
import git/process_log

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
<a id='top'/>
<tr><th>Navigate</th><th>Command</th><th>Modify</th></tr>
<tr><td><a href='/'>Start</a></td><td>{htmlescape cmd}</td>{add100_top}</tr>
</table>
<p/>
{content}
<p>
<table>
<tr><th>Navigate</th><th>Command</th><th>Modify</th></tr>
<tr><td><a href='#top'>Top</a></td><td>{htmlescape cmd}</td>{add100_bottom}</tr>
</table>
</body>
</html>
"""

proc format_html(L: seq[LogCommit]): string=
    result="<table class='diff'>\n<tr><th>commit</th><th>who</th><th>when</th><th>affected</th><th>subject/details</th></tr>"
    for index,commit in L:
        if index>0 and index mod 100==0:
            result.add "\n" & fmt"<tr><td><a id='top{index}'>{index}</a></td></tr>"
            # Vielfache von 100 erhalten eine Hinweiszeile, die auch als Sprungziel dient.
        var comments=htmlescape(commit.subject)
        for d in commit.details: comments.add "<br/>"&htmlescape(d)
        let parent=if commit.parents.len>0: commit.parents[0] else: shanull
        var files=""
        for index,(s,p,old) in commit.files:
            if index>0: files.add "<br/>"
            if old=="": files.add fmt"{s} <a href='{url_diff parent, commit.hash, false, p, old}'>{p}</a>"
            else:       files.add fmt"{s} <a href='{url_diff parent, commit.hash, false, p, old}'>{p}<br/>&nbsp;&nbsp;from {old}</a>"
        # if commit.mergeinfo.len>0:
        #     result.add "\n<tr><td colspan='5'>mergeinfo:"
        #     for m in commit.mergeinfo: result.add " "&m
        #     # result.add "; parents"
        #     # result.add $commit.parents
        #     result.add "</td></tr>"
        result.add "\n<tr><td>" & shaform(commit.hash) & "</td><td>" & commit.author &
            "</td><td>" & commit.date.format("d. MMM HH:mm") & "</td><td>" & files & "</td><td>" & comments & "</td></tr>"
    result.add "\n" & fmt"<tr><td><a id='top{L.len}'>{L.len}</a></td></tr>"
    result.add "</table>"

proc page_log*(Args: Table[string,string]): string=
    let num=block:
        var X=0
        let str=Args.getordefault("num", "100")
        if parseint(str, X)<str.len: X=100
        X
    let (L,cmd)=gitlog num
    let
        title="log"
        add100_top=if L.len>=num: fmt"<td><a href='{url_log num+100}'>100 more</a></td>" else: ""
        add100_bottom=if L.len>=num: fmt"<td><a href='{url_log num+100, num}'>100 more</a></td>" else: ""
        cssurl="/gitrelief.css"
        content=format_html(L)
    return fmt html_template
