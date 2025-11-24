
import std/[tables, strutils, strformat, parseutils, times]
import gitqueries, helper

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
                html_content=format_commits(L, Args.getordefault("path", ""))
        fmt staticread "../public/log.html"

                                # if commit.mergeinfo.len>0:
                                #     res.add "\n<tr><td colspan='5'>mergeinfo:"
                                #     for m in commit.mergeinfo: res.add " "&m
                                #     res.add "</td></tr>"
                                # if commit.parents.len>0:
                                #     res.add "\n<tr><td colspan='5'>parents:"
                                #     for m in commit.parents: res.add " " & $m
                                #     res.add "</td></tr>"
