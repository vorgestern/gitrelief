
import std/[strtabs, strformat, osproc, streams, times]
import checksums/sha1
import npeg

export sha1

proc exec_path(command: string, args: openarray[string]): seq[string]=
    let p=startprocess(command, args=args, options={poUsePath})
    let pipe=outputstream(p)
    var line:  string
    while readline(pipe, line): result.add line
    close p

let TMonat{.used.}={"01": "Jan", "02": "Feb", "03": "Mär", "04": "Apr", "05": "Mai", "06": "Jun",
                    "07": "Jul", "08": "Aug", "09": "Sep", "10": "Okt", "11": "Nov", "12": "Dez"}.newstringtable

type
    filestatus=tuple[status: string, path: string, oldpath: string]
    LogCommit* =object
        hash*: SecureHash
        parents*: seq[SecureHash]
        author*: string
        date*: DateTime
        subject*: string
        details*: seq[string]
        files*: seq[filestatus]
        mergeinfo*: seq[string]

proc parse_log(L: seq[string]): seq[LogCommit]=
    type
        context=enum None, Header, Subject, Details, Files
        parsercontext=object
            st: context
            was: ptr seq[LogCommit]
    const loglineparser=peg("line", e: parsercontext):
        hash <- +{'0'..'9', 'a'..'f'}
        path <- +{33..255}
        commit <- "commit " * +@>hash:
            var parents: seq[SecureHash]
            for k in 2..<capture.len: parents.add parsesecurehash capture[k].s
            e.was[].add LogCommit(hash: parsesecurehash $1, parents: parents)
            e.st=Header
        merge <- "Merge:" * @>hash * @+>hash:
            # capture[0] beschreibt die ganze Zeile.
            # capture[1..] sind die Hashes.
            # Die hier genannten Hashes sind einfach die Kurzformen der in der commit-Zeile genannten.
            for k in 1..<capture.len: e.was[^1].mergeinfo.add capture[k].s
        authorname <- {33..128} * +{33..128}
        author <- "Author:" * @>authorname * @'<': e.was[^1].author= $1
        datestring <- {'0'..'9', '-'}[10] * @{'0'..'9', ':'}[8] * @ {'0'..'9', '-', '+'}[5]
        date <- "Date: " * @>datestring * !1:
            let ts=substr($1, 0, 18)
            e.was[^1].date=times.parse(ts, "yyyy-MM-dd HH:mm:ss")
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
        filestatus <- >{'A'..'Z'} * +{' ','\t'} * >+1: e.was[^1].files.add ($1, $2, "")
        filestatus_rename <- 'R' * >{'0'..'9'}[3] * @>path * @>path: e.was[^1].files.add ("R", $3, $2)
        sonst <- >(*1) * !1: echo "Nicht erwartet: ", $1
        line <- commit | merge | author | date | empty | comment | filestatus | filestatus_rename | sonst
    var e=parsercontext(st: None, was: addr result)
    for z in L:
        {.gcsafe.}:
            if loglineparser.match(z, e).ok:
                discard
            else:
                # error
                # e.zeile="??????"
                discard

proc gitlog*(num: int): tuple[commits: seq[LogCommit], cmd: string]=
    let args=block:
        var A= @["log", "--name-status", "--parents", "--date=iso-local"]
        if num>0: A.add fmt"-{num}"
        A
    let
        Lines=exec_path("git", args)
        cmd=block:
            var X="git"
            for a in args: X=X & " " & a
            X
    (parse_log Lines, cmd)
