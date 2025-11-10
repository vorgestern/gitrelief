
import std/[tables, strformat]
import std/[osproc, strutils, streams]
import std/strtabs
import npeg

import mehr/helper

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

let TMonat={"01": "Jan", "02": "Feb", "03": "Mär", "04": "Apr", "05": "Mai", "06": "Jun",
            "07": "Jul", "08": "Aug", "09": "Sep", "10": "Okt", "11": "Nov", "12": "Dez"}.newstringtable

type
    FileOp=enum Other, Modified, Deleted, Added, Renamed
    filestatus=tuple[status: FileOp, path: string, oldpath: string]
    Commit=object
        hash: string
        parents: seq[string]
        author: string
        date: string
        subject: string
        details: seq[string]
        files: seq[filestatus]

proc parse_log(L: seq[string]): seq[Commit]=
    type
        context=enum None, Header, Subject, Details, Files
        parsercontext=object
            st: context
            was: ptr seq[Commit]
    const loglineparser=peg("line", e: parsercontext):
        hash <- +{'0'..'9', 'a'..'f'}
        path <- +{33..255}
        commit_pp <- "commit " * >hash * @>hash * @>hash:
            e.was[].add Commit(hash: substr($1, 0, 8), parents: @[substr($2, 0, 8), substr($3, 0, 8)])
            e.st=Header
        commit_p <- "commit " * >hash * @>hash:
            e.was[].add Commit(hash: substr($1, 0, 8), parents: @[substr($2, 0, 8)])
            e.st=Header
        commit <- "commit " * >hash * !1:
            e.was[].add Commit(hash: substr($1, 0, 8), parents: @["00000000"])
            e.st=Header
        authorname <- {33..128} * +{33..128}
        author <- "Author:" * @>authorname * @'<':
            e.was[^1].author= $1
        datestring <- {'0'..'9', '-'}[10] * @{'0'..'9', ':'}[8] * @ {'0'..'9', '-', '+'}[5]
        date <- "Date: " * @>datestring * !1:
            let
                # y=substr($1, 0, 3)
                m=substr($1, 5, 6)
                d=substr($1, 8, 9)
                H=substr($1, 11, 12)
                M=substr($1, 14, 15)
            e.was[^1].date= fmt"{d}. {TMonat[m]} {H}:{M}"
        empty <- *{' ', '\t'} * !1:
            e.st=case e.st
            of Header:  Subject
            of Subject: Details
            of Details: Details
            else: Files
        comment <- "    " * >+1:
            case e.st
            of Subject:
                e.was[^1].subject= $1
                e.st=Details
            of Details: e.was[^1].details.add $1
            else: discard
        filestatus <- >{'A', 'M', 'D'} * +{' ','\t'} * >+1:
            let stat=case $1
            of "M": Modified
            of "D": Deleted
            of "A": Added
            else: Other
            e.was[^1].files.add (stat, $2, "")
        filestatus_rename <- 'R' * {'0'..'9'}[3] * '\t' * >path * '\t' * >path:
            e.was[^1].files.add (Renamed, $2, $1)
        sonst <- >(*1) * !1:
            echo "Nicht erwartet: ", $1
        line <- commit_pp | commit_p | commit | author | date | empty | comment | filestatus | filestatus_rename | sonst
    var e=parsercontext(st: None, was: addr result)
    for z in L:
        {.gcsafe.}:
            if loglineparser.match(z, e).ok:
                discard
            else:
                # error
                # e.zeile="??????"
                discard

proc format_html(L: seq[Commit], highlight=""): string=
    result="<table class='diff'>"
    for commitindex,commit in L:
        var comments=htmlescape(commit.subject)
        for d in commit.details: comments.add "<br/>"&htmlescape(d)
        let parent=if commit.parents.len>0: commit.parents[0] else: "0000000"
        var files=""
        for fileindex,(stat,p,old) in commit.files:
            if fileindex>0: files.add "<br/>"
            if stat==Renamed:       files.add fmt"<a href='{url_diff(parent, commit.hash, false, p)}'>{stat}</a><br/>to {p}<br/>from {old}"
            elif stat==Added:       files.add fmt"<a href='{url_diff(parent, commit.hash, false, p)}'>{stat}</a><br/>{p}"
            elif commitindex==0:    files.add fmt"<a href='{url_diff(parent, commit.hash, false, p)}'>{stat}</a><br/>{p}"
            else:                   files.add fmt"<a href='{url_diff(parent, commit.hash, false, p)}'>{stat}</a>"
        let
            tr=if commit.hash==highlight: "\n<tr class='highlight'>" else: "\n<tr>"
            tdanchor=fmt"<td><a id='tr_{substr(commit.hash,0,7)}'/>{substr(commit.hash,0,7)}</a></td>"
            tdauthor="<td>"&commit.author&"</td>"
            tddate="<td>"&commit.date&"</td>"
            tdaffected="<td>"&files&"</td>"
            tdcomments="<td>"&comments&"</td>"
        result.add tr & tdanchor & tdauthor & tddate & tdaffected & tdcomments & "</tr>"
    result.add "</table>"

proc git_log_follow*(Args: Table[string,string]): string=

    let gitargs=block:
        var X= @["log", "--follow", "--name-status", "--parents", "--date=iso-local"]
        if Args.contains "path":
            if Args.contains "a":
                var arg=Args["a"]   # &"^"
                if Args.contains "b": arg.add ".."&Args["b"]
                X.add arg
            elif Args.contains "b":
                X.add ".."&Args["b"]
            if Args.contains "num": X.add "-" & Args["num"]
            else: X.add "-100"
            X.add "--"
            X.add Args["path"]
        X

    # Starte git und sammele Ausgabezeilen ein.
    let p=startprocess("git", args=gitargs, options={poUsePath})
    let pipe=outputstream(p)
    var
        Loglines: seq[string]
        line:  string
    while readline(pipe, line): Loglines.add line
    let
        title="log_follow"
        cmd=block:
            var X="git"
            for a in gitargs: X=X & " " & a
            X
        pathtofollow=Args.getordefault("path", "???")
        cssurl="/gitrelief.css"
        content=format_html(parse_log Loglines, Args.getordefault("highlight", ""))
    return fmt html_template
