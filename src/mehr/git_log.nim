
import std/[tables, strformat]
import std/[osproc, strutils, streams]
import std/strtabs
import npeg

# import helper

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
<p/>
{content}
</body>
</html>
"""

let TMonat={"01": "Jan", "02": "Feb", "03": "Mär", "04": "Apr", "05": "Mai", "06": "Jun",
            "07": "Jul", "08": "Aug", "09": "Sep", "10": "Okt", "11": "Nov", "12": "Dez"}.newstringtable

type
    filestatus=tuple[status: string, path: string]
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
        commit <- "commit " * >hash * ?@>hash * ?@>hash:
            let parents=case capture.len
            of 4: @[substr($2, 0, 8), substr($3, 0, 8)]
            of 3: @[substr($2, 0, 8)]
            else: @["000000000"]
            # echo "commits hash=",$1,", capture.len=",capture.len,", parents=",parents
            e.was[].add Commit(hash: substr($1, 0, 8), parents: parents)
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
            of Details: e.was[^1].details.add $1
            else: discard
        filestatus <- >{'A'..'Z'} * +{' ','\t'} * >+1:
            e.was[^1].files.add ($1, $2)
        sonst <- >(*1) * !1:
            echo "Nicht erwartet: ", $1
        line <- >commit | >author | >date | empty | >comment | >filestatus | >sonst
    var e=parsercontext(st: None, was: addr result)
    for z in L:
        {.gcsafe.}:
            if loglineparser.match(z, e).ok:
                discard
            else:
                # error
                # e.zeile="??????"
                discard

proc format_html(L: seq[Commit]): string=
    result="<table class='diff'>"
    var chash="000000000"
    for commit in L:
        var comments=htmlescape(commit.subject)
        for d in commit.details: comments.add "<br/>"&htmlescape(d)
        let parent=if commit.parents.len>0: commit.parents[0]
        else: "0000000"
        var files=""
        for index,(s,p) in commit.files:
            if index>0: files.add "<br/>"
            files.add fmt"{s} <a href='/action/git_diff?a={parent}&b={commit.hash}&c={chash}&path={p}'>{p}</a>"
        result.add "<tr><td>" & substr(commit.hash,0,7) & "</td><td>" & commit.author &
            "</td><td>" & commit.date & "</td><td>" & files & "</td><td>" & comments & "</td></tr>"
        chash=commit.hash
    result.add "</table>"

proc git_log*(Args: Table[string,string]): string=

    let gitargs=block:
        var
            A= @["log", "--name-status", "--parents", "--date=iso-local"]
        A.add "-"&Args.getordefault("num", "100")
        A

    # Starte git und sammele Ausgabezeilen ein.
    let p=startprocess("git", args=gitargs, options={poUsePath})
    let pipe=outputstream(p)
    var
        Loglines: seq[string]
        line:  string
    while readline(pipe, line): Loglines.add line

    # Bilde die Werte title, cmd, content und cssurl für die Auswertung der Schablone.
    let
        title="log_neu"
        cmd=block:
            var cmd="git"
            for a in gitargs: cmd=cmd & " " & a
            cmd
        cssurl="/gitrelief.css"
        content=block:
            format_html(parse_log Loglines)
    return fmt html_template
