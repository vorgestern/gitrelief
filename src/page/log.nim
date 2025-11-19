
import std/[tables, strutils, strformat, parseutils, times]
import npeg
import mehr/helper
import git/processes

proc page_log*(Args: Table[string,string]): string=
        let
                num=block:
                        var X=0
                        let str=Args.getordefault("num", "100")
                        if parseint(str, X)<str.len: X=100
                        X
                (L,cmd)=                gitlog num
        let
                html_title=             $servertitle & " log"
                html_add100_top=        if L.len>=num: fmt"<td><a href='{url_log num+100}'>100 more</a></td>"
                                        else: ""
                html_add100_bottom=     if L.len>=num: fmt"<td><a href='{url_log num+100, num}'>100 more</a></td>"
                                        else: ""
                html_cmd=               htmlescape cmd
                html_content=block:
                        let ynow=year(now())
                        var yage_merk=0
                        var res="<table class='diff'>\n<tr><th>commit</th><th>who</th><th>when</th><th>affected</th><th>subject/details</th></tr>"
                        for index,commit in L:
                                # Vielfache von 100 erhalten eine Hinweiszeile, die auch als Sprungziel dient.
                                if index>0 and index mod 100==0: res.add "\n" & fmt"<tr><td><a id='top{index}'>{index}</a></td></tr>"
                                let comments=block:
                                        var s=htmlescape(commit.subject)
                                        for d in commit.details: s.add "<br/>"&htmlescape(d)
                                        s
                                let parent=if commit.parents.len>0: commit.parents[0] else: shanull
                                var files=""
                                for index,op in commit.files:
                                        if index>0: files.add "<br/>"
                                        let url=url_diff(parent, commit.hash, false, op)
                                        case op.status
                                        of Renamed, Copied: files.add fmt"{op.status} <a href='{url}'>{op.newpath}<br/>&nbsp;&nbsp;from {op.oldpath}</a>"
                                        else:               files.add fmt"{op.status} <a href='{url}'>{op.path}</a>"
                                let yage=ynow-year(commit.date)
                                if yage>yage_merk:
                                        let yclass=if yage mod 2==0: "yeven" else: "yodd"
                                        res.add "\n<tr class='newyear'><td/><td/><td class='" & yclass & "'><b>" & $year(commit.date) & "</b></td><td/><td/></tr>"
                                        yage_merk=yage
                                let df=commit.date.format("d. MMM HH:mm")
                                let tddate=block:
                                        if yage==0:             "<td>" & df & "</td>"
                                        elif yage mod 2==0:     "<td class='yeven'>" & df & "</td>"
                                        else:                   "<td class='yodd'>" & df & "</td>"
                                res.add "\n<tr><td>" & shaform(commit.hash) & "</td><td>" & commit.author & "</td>" & tddate & "<td>" & files & "</td><td>" & comments & "</td></tr>"
                        res.add "\n" & fmt"<tr><td><a id='top{L.len}'>{L.len}</a></td></tr>"
                        res.add "</table>"
                        res
        fmt staticread "../public/log.html"

                                # if commit.mergeinfo.len>0:
                                #     res.add "\n<tr><td colspan='5'>mergeinfo:"
                                #     for m in commit.mergeinfo: res.add " "&m
                                #     res.add "</td></tr>"
                                # if commit.parents.len>0:
                                #     res.add "\n<tr><td colspan='5'>parents:"
                                #     for m in commit.parents: res.add " " & $m
                                #     res.add "</td></tr>"
