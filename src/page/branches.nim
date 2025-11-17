
import std/[tables, strformat, strutils, times, paths, dirs, sequtils, sugar]
import git/processes
import mehr/helper

proc resolvecommits(SB: ShowBranch): seq[tuple[tags: string, commit: Commit]]=
    collect(newseq()):
        for tc in SB.commits: (tc.tags, gitcommit tc.hash)

proc page_branches*(Args: Table[string,string]): string=
    let
        mastername=if Args.contains "m": Args["m"] else: ""
        branchname=if Args.contains "b": Args["b"] else: ""
        branchnames=gitbranches_local()
    let
        html_title="branches"
        html_selectbranches=block:
            var X=""
            for b in branchnames:
                let b1=htmlescape b
                let td2=if b!=mastername: fmt"<td class='re'><a href='{url_branches b, branchname}'>select</a></td>"
                else:                     "<td>A="&htmlescape(b)&"</td>"
                let td3=if b!=branchname: fmt"<td class='re'><a href='{url_branches mastername, b}'>select</a></td>"
                else:                     "<td>B="&htmlescape(b)&"</td>"
                X.add "\n" & fmt"<tr><td>{b1}</td>{td2}{td3}</tr>"
            X
        html_showbranches=if mastername=="" or branchname=="":
            if mastername=="" and branchname=="": "<p>Select A and B to show relationship between two branches"
            elif mastername=="": "<p>Select A to show relationship between two branches"
            else: "<p>Select B to show relationship between two branches"
        else:
            let
                (SB, cmd)=gitshowbranches([mastername, branchname])
                B=SB.branches
                T=resolvecommits SB
            var X="<h2>Branches</h2>\n" & cmd & "\n<table class='showbranch'>"
            for jb in 0..<B.len:
                X.add "<tr>"
                for kb in 0..<B.len:
                    X.add if kb==jb: "<td>" & $kb & "</td>" else: "<td/>"
                X.add "<th/><th>" & B[jb] & "</th>"
                X.add "</tr>"
            for k in T:
                X.add "<tr>"
                for t in k.tags: X.add "<td>" & t & "</td>"
                X.add "<td>" & shaform(k.commit.hash) & "</td>"
                X.add "<td>" & datestring(k.commit) & "</td>"
                X.add "<td>" & htmlescape(k.commit.author) & "</td>"
                X.add "<td>" & htmlescape(k.commit.subject)
                for line in k.commit.details: X.add "<br/>" & htmlescape(line)
                X.add "</td></tr>"
            X.add "</table>"
            X
    return fmt staticread "../public/branches.html"
