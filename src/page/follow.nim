
import std/[tables, strformat, strutils, strtabs, times, paths]
import gitqueries, helper

type
        dirinfo=tuple[name, path: string]

func pathparts(p: Path): tuple[dirs: seq[dirinfo], file: string]=
        let X {.used.}=splitfile(p)
        result.file= $X.name & X.ext
        var dir99=X.dir
        while $dir99!="" and $dir99!="/":
                let (h,t)=splitpath dir99
                if $t=="" or $t=="/": break
                result.dirs.insert (name: $t, path: $dir99 & "/")
                dir99=h

func format_pathtofollow(p: Path, num: int, highlight=""): string=
        if $p=="": return "<i>Missing query ?path=...</i>"
        let (Diri,File)=pathparts(p)
        result="Following &nbsp;&nbsp;&nbsp;&nbsp;<b>"
        for (name,path) in Diri: result.add fmt"<a href='{url_follow path, num, highlight}'>{name}</a>/"
        result.add File & "</b>"

proc page_follow*(Args: Table[string,string]): string=
        let
                pathtofollow=Path Args.getordefault("path", "")
                num=parseint Args.getordefault("num", "100")
                commithash=Args.getordefault("highlight", "")
                (leading, isfile)=block:
                        let (P,F,_)=splitfile(pathtofollow)
                        if $F!="": ($P&"/", true)
                        else: ($P&"/", false)
        let
                (L,html_cmd)=gitfollow(pathtofollow, num)
                thereismore=if L.len<num: false else: true
                html_title= "&#x1D509; " & $servertitle
                html_pathtofollow=format_pathtofollow(pathtofollow, num, commithash)
                html_plus100_top=if thereismore: fmt"<a href='{url_follow $pathtofollow, num+100, commithash}'>100 more</a>" else: ""
                html_plus100_bottom=html_plus100_top
                html_content=format_commits(L, leading, isfile, commithash)
        return fmt staticread "../public/follow.html"

# =====================================================================

when ismainmodule:
        echo "=================="
        if false:
                # let ts="2025-11-10T17:39:33+01:00"
                let ts="2025-11-10T17:39:33"
                let dt=times.parse(ts, "yyyy-MM-dd'T'HH:mm:ss")
                echo "dt=",$dt
        if true:
                let P=Path "src/Tabellen/Gruppen/Sonstiges.lua"
                echo "P=",$P
                echo "X=",$pathparts(P)
                echo "X1=",$pathparts(P)
