
import jesterfork
import mehr/[helper,git_log,git_diff]
import std/[cmdline,paths,strutils]

# asyncdispatch

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
                resp Http200, replace(root_html, "<td>pwd</td>", "<td>" & $pwd & "/</td>")
        get "/gitrelief.css": resp Http200, gitrelief_css
        get "/action/git_log":
                let A=parsequery(request.query)
                # for k,v in A: echo "arg "&k&"="&v
                resp git_log(A)
        get "/action/git_diff":
                let A=parsequery(request.query)
                resp git_diff(A)
        # error Http404: resp Http404, "Looks you took a wrong turn somewhere."
        error Exception: resp Http500, "Exception caught: "&exception.msg
