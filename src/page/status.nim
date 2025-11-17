
import std/[tables, strformat, strutils, paths, dirs]
import git/processes
import mehr/helper

func htmlescape(s: string): string=replace(s, "<", "&lt;")

const html_template_status=staticread "../public/status.html"

proc walkpublicdir(dir: Path): string=
    var dir1=dir
    normalizepathend(dir1, true)
    for path in walkdirrec(dir1):
        let p=replace(string path, string dir1, "")
        result.add fmt"{'\n'}<tr><td></td><td><a href='{p}'>{p}</a></td></tr>"

proc format_html(Status: RepoStatus): tuple[a,b,c: string]=
    var Controlled="<h3>Staged</h3><table class='nolines'>"
    for index,entry in Status.staged:
        let diff="\n    <a href='" & url_diff(shanull, shanull, true, entry.path) & "'>diff</a>"
        let follow="\n    <a href='" & url_follow(entry.path) & "'>follow</a>"
        let unstage="\n    <a href='" & url_unstage(entry.path) & "'>unstage</a>"
        Controlled.add "\n" & fmt"<tr><td>{entry.status}</td><td>{diff}{follow}{unstage}</td><td>{entry.path}</td></tr>"
    Controlled.add "</table>"

    Controlled.add "<h3>Not staged</h3><table class='nolines'>"
    for index,entry in Status.unstaged:
        let diff="\n    <a href='" & url_diff(shanull, shanull, false, entry.path) & "'>diff</a>"
        let follow="\n    <a href='" & url_follow(entry.path) & "'>follow</a>"
        let stage="\n    <a href='" & url_stage(entry.path) & "'>stage</a>"
        Controlled.add "\n" & fmt"<tr><td>{entry.status}</td><td>{diff}{follow}{stage}</td><td>{entry.path}</td></tr>"
    Controlled.add "</table>"

    var NotControlled="<table class='nolines'>"
    for index,entry in Status.notcontrolled:
        let stage="<a href='" & url_stage(entry) & "'>stage</a>"
        NotControlled.add "\n" & fmt"<tr><td>{entry}</td><td>{stage}</td></tr>"
    NotControlled.add "</table>"

    var ParseError="<table class='nolines'>"
    for index,entry in Status.unparsed: ParseError.add fmt"<tr><td>{entry}</td></tr>"
    ParseError.add "</table></p>"
    (Controlled,NotControlled,ParseError)

# =====================================================================

proc page_status*(Args: Table[string,string], publicdir: string): string=
    let
        (Status,_)=gitstatus()
        R=gitremotes()
        pwd=block:
            var X=getcurrentdir()
            normalizepath(X)
            X
        remotenames=block:
            var X: seq[string]
            for k in keys(R): X.add k
            X
    let
        html_title= $servertitle & " status"
        (html_controlled,html_notcontrolled,html_failedtoparse)=format_html(Status)
        html_remoteurls=block:
            var X=""
            for (name,urls) in pairs(R):
                if urls.fetchurl!=urls.pushurl: X.add "<tr><td>" & htmlescape(name) & "</td><td>" & htmlescape(urls.fetchurl) & "</td><td>" & htmlescape(urls.pushurl) & "</td></tr>"
                else:  X.add "<tr><td>" & htmlescape(name) & "</td><td colspan='2'>" & htmlescape(urls.fetchurl) & "</td></tr>"
            X
        html_branches=block:
            var X="<tr><th/>"
            for k in remotenames: X.add "<th>remotes/" & htmlescape(k) & "</th>"
            X.add "</tr>\n<tr>\n<td>\n"
            for k in gitbranches_local(): X.add htmlescape(k) & "<br/>"
            X.add "</td>"
            for remote in remotenames:
                let rembranches=gitbranches_remote(remote)
                X.add "\n<td>"
                for b in rembranches: X.add htmlescape(b) & "<br/>"
                X.add "</td>"
            X.add "</tr>"
            X
        html_localfiles="<table class='nolines'>" & walkpublicdir(Path publicdir) & "</table>"

    return fmt html_template_status
