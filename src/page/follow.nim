
import std/[tables, strformat, strutils, strtabs, times, paths]
import npeg
import helper
import git/processes

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

func path_short(path, leading: string, followfile: bool): string=
    if followfile: return ""
    if leading.len>0 and path.startswith(leading): " " & path.substr(leading.len)
    else: " " & path

func format_table(L: seq[Commit], leading: string, followfile: bool, highlight=""): string=
    result="<table class='diff'>"
    for commitindex,commit in L:
        var comments=htmlescape(commit.subject)
        for d in commit.details: comments.add "<br/>"&htmlescape(d)
        let parent=if commit.parents.len>0: commit.parents[0] else: shanull
        var files=""
        for fileindex,op in commit.files:
            if fileindex>0: files.add "<br/>"
            let url=url_diff(parent, commit.hash, false, op)
            if op.status==Renamed:  files.add fmt"<a href='{url}'>{op.status}</a> to {path_short op.newpath, leading, false}<br/>from {path_short op.oldpath, leading, false}"
            elif op.status==Copied: files.add fmt"<a href='{url}'>{op.status}</a> to {path_short op.newpath, leading, false}<br/>from {path_short op.oldpath, leading, false}"
            elif op.status==Added:  files.add fmt"<a href='{url}'>{op.status}</a>{path_short op.path, leading, false}"
            elif commitindex==0:    files.add fmt"<a href='{url}'>{op.status}</a>{path_short op.path, leading, false}"
            else:                   files.add fmt"<a href='{url}'>{op.status}</a>{path_short op.path, leading, followfile}"
        let hx=shaform commit.hash
        let
            tr=if shamatch(commit.hash, highlight): "\n<tr class='highlight'>" else: "\n<tr>"
            tdanchor=fmt"<td><a id='tr_{hx}'/>{hx}</a></td>"
            tdauthor="<td>"&commit.author&"</td>"
            tddate="<td>" & commit.date.format("d. MMM HH:mm") & "</td>"
            tdaffected="<td>"&files&"</td>"
            tdcomments="<td>"&comments&"</td>"
        result.add tr & tdanchor & tdauthor & tddate & tdaffected & tdcomments & "</tr>"
    result.add "</table>"

proc page_follow*(Args: Table[string,string]): string=
    let
        pathtofollow=Path Args.getordefault("path", "")
        num=parseint Args.getordefault("num", "100")
        commithash=Args.getordefault("highlight", "")
        (leading, isfile)=block:
            let (P,F,_)=splitfile(pathtofollow)
            # echo "compute leading: ", P, " ", F, " ", E
            if $F!="": ($P&"/", true)
            else: ($P&"/", false)
    # echo "leading: ", leading
    # echo "isfile: ", isfile
    let
        (L,html_cmd)=gitfollow(pathtofollow, num)
        thereismore=if L.len<num: false else: true
        html_title= $servertitle & " follow"
        html_pathtofollow=format_pathtofollow(pathtofollow, num, commithash)
        html_plus100_top=if thereismore: fmt"<a href='{url_follow $pathtofollow, num+100, commithash}'>100 more</a>" else: ""
        html_plus100_bottom=html_plus100_top
        html_content=format_table(L, leading, isfile, commithash)
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
        echo "X1=",$pathparts1(P)
