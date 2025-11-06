
import jesterfork
import mehr/[helper,git_diff,git_log,git_log_follow]
import std/[cmdline,paths,dirs,strutils,strformat]

# asyncdispatch

proc walkpublicdir(dir: Path): string=
        var dir1=dir
        normalizepathend(dir1, true)
        for path in walkdirrec(dir1):
                let p=replace(string path, string dir1, "")
                result.add fmt"{'\n'}<tr><td></td><td><a href='{p}'>{p}</a></td></tr>"

proc parsequery(query: string): Table[string,string]=
        var
                S: seq[HSlice[int,int]]
                p=0
        while p<query.len:
                let q=query.find('&', p)
                if q>p:
                        S.add p..q-1 # HSlice(p,q-1)
                        p=q+1
                elif q==p:
                        p=q+1
                else:
                        S.add p..query.len-1
                        p=query.len
        for k in S:
                let s=query[k]
                let q=s.find '='
                if q>0: result[s.substr(0,q-1)]=s.substr(q+1)
                else: result[s]=""

var
        port=8080
        publicdir="public"

let args=commandlineparams()
for k in 0..<args.len:
        echo $k," ",args[k]
        if args[k]=="--port":
                if k+1<args.len: port=parseint args[k+1]
        if args[k]=="--public":
                if k+1<args.len: publicdir=args[k+1]

settings:
        # appname="gitrelief" Dieser Name wird am Anfang von urls entfernt, er ist kein hostname.
        # bindaddr="gitrelief" Dies muss anscheinend eine numerische Adresse sein.
        port=Port(port)
        staticdir=publicdir

routes:
        get "/":
                var pwd=getcurrentdir()
                normalizepath(pwd)
                let pubdir=block:
                        {.gcsafe.}:
                                let a=walkpublicdir(Path publicdir)
                                fmt"<table>{a}</table>"
                var html=replace(root_html, "<td>pwd</td>", "<td>" & $pwd & "/</td>")
                html=replace(html, "localfiles", pubdir)
                resp Http200, html
        get "/gitrelief.css": resp Http200, gitrelief_css
        get "/action/git_log": resp git_log(parsequery request.query)
        get "/action/git_log_follow": resp git_log_follow(parsequery request.query)
        get "/action/git_diff":
                let A=parsequery(request.query)
                resp git_diff(A)
        # error Http404: resp Http404, "Looks you took a wrong turn somewhere."
        error Exception: resp Http500, "Exception caught: "&exception.msg
