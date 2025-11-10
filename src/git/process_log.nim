
import std/[strtabs, strformat, osproc, streams]
import checksums/sha1
import npeg

export sha1

let TMonat={"01": "Jan", "02": "Feb", "03": "Mär", "04": "Apr", "05": "Mai", "06": "Jun",
            "07": "Jul", "08": "Aug", "09": "Sep", "10": "Okt", "11": "Nov", "12": "Dez"}.newstringtable

type
    filestatus=tuple[status: string, path: string, oldpath: string]
    LogCommit* =object
        hash*: SecureHash
        parents*: seq[SecureHash]
        author*: string
        date*: string
        subject*: string
        details*: seq[string]
        files*: seq[filestatus]

proc parse_log(L: seq[string]): seq[LogCommit]=
    type
        context=enum None, Header, Subject, Details, Files
        parsercontext=object
            st: context
            was: ptr seq[LogCommit]
    const loglineparser=peg("line", e: parsercontext):
        hash <- +{'0'..'9', 'a'..'f'}
        path <- +{33..255}
        commit_hpp <- "commit " * >hash * @>hash * @>hash:
            e.was[].add LogCommit(hash: parsesecurehash $1, parents: @[parsesecurehash $2, parsesecurehash $3])
            e.st=Header
        commit_hp <- "commit " * >hash * @>hash:
            e.was[].add LogCommit(hash: parsesecurehash $1, parents: @[parsesecurehash $2])
            e.st=Header
        commit_h <- "commit " * >hash * !1:
            e.was[].add LogCommit(hash: parsesecurehash $1, parents: @[])
            e.st=Header
        authorname <- {33..128} * +{33..128}
        author <- "Author:" * @>authorname * @'<': e.was[^1].author= $1
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
        filestatus <- >{'A'..'Z'} * +{' ','\t'} * >+1: e.was[^1].files.add ($1, $2, "")
        filestatus_rename <- 'R' * >{'0'..'9'}[3] * @>path * @>path: e.was[^1].files.add ("R", $3, $2)
        sonst <- >(*1) * !1: echo "Nicht erwartet: ", $1
        line <- commit_hpp | commit_hp | commit_h | author | date | empty | comment | filestatus | filestatus_rename | sonst
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
    let p=startprocess("git", args=args, options={poUsePath})
    let pipe=outputstream(p)
    var
        Lines: seq[string]
        line:  string
    while readline(pipe, line): Lines.add line
    let
        L=parse_log Lines
        cmd=block:
            var X="git"
            for a in args: X=X & " " & a
            X
    (L, cmd)
