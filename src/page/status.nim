
import std/[tables, strformat, strutils, paths, dirs]
import gitqueries, helper

proc walkpublicdir(dir: Path): string=
        var dir1=dir
        normalizepathend(dir1, true)
        for path in walkdirrec(dir1):
                let p=replace(string path, string dir1, "")
                result.add fmt"{'\n'}<tr><td></td><td><a href='{p}'>{p}</a></td></tr>"

func format_repostatus(Status: RepoStatus_v2): tuple[a,b: string]=
        var Controlled="<h3>Staged</h3><table class='nolines'>"
        for index,entry in Status.staged:
                let diff="\n    <a href='" & url_diff(shanull, shanull, true, entry.path, entry.oldpath) & "'>diff</a>"
                let follow="\n    <a href='" & url_follow(entry.path) & "'>follow</a>"
                let unstage="\n    <a href='" & url_unstage(entry.path) & "'>unstage</a>"
                Controlled.add "\n" & fmt"<tr><td>{entry.status}</td><td>{diff}{follow}{unstage}</td><td>{entry.path}</td></tr>"
        Controlled.add "</table>"
        Controlled.add "<h3>Not staged</h3><table class='nolines'>"
        for index,entry in Status.unstaged:
                let diff="\n    <a href='" & url_diff(shanull, shanull, false, entry.path, entry.oldpath) & "'>diff</a>"
                let follow="\n    <a href='" & url_follow(entry.path) & "'>follow</a>"
                let stage="\n    <a href='" & url_stage(entry.path) & "'>stage</a>"
                Controlled.add "\n" & fmt"<tr><td>{entry.status}</td><td>{diff}{follow}{stage}</td><td>{entry.path}</td></tr>"
        Controlled.add "</table>"
        if Status.unmerged.len>0:
                Controlled.add "<h3>Not merged</h3><table class='nolines'>"
                for index,entry in Status.unmerged:
                        let path=entry
                        let follow="\n    <a href='" & url_follow(path) & "'>follow</a>"
                        Controlled.add "\n" & fmt"<tr><td>Unmerged</td><td>{follow}</td><td>{path}</td></tr>"
                Controlled.add "</table>"
        var NotControlled=""
        if Status.unparsed.len>0:
                NotControlled.add "<h3 class='error'>Parse Errors</h3><table class='nolines'>"
                for index,entry in Status.unparsed: NotControlled.add fmt"<tr><td>{entry}</td></tr>"
                NotControlled.add "</table>"
        NotControlled.add "<h3>Not ignored</h3><table class='nolines'>"
        for index,entry in Status.notcontrolled:
                let stage="<a href='" & url_stage(entry) & "'>stage</a>"
                NotControlled.add "\n" & fmt"<tr><td>{entry}</td><td>{stage}</td></tr>"
        NotControlled.add "</table>"

        (Controlled,NotControlled)

# =====================================================================

proc page_status*(Args: Table[string,string], publicdir: string): string=
        let
                (Status,_)=gitstatus_v2()
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
                html_currentbranch=htmlescape Status.currentbranch
                html_currentcommit=shaform Status.currentcommit
                html_publicfiles="<table class='nolines'>" & walkpublicdir(Path publicdir) & "</table>"
                (html_controlled,html_notcontrolled)=format_repostatus Status
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

        return fmt staticread "../public/status.html"
