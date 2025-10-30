
import jesterfork
import mehr/[helper,git_log,git_diff]
import strutils

# asyncdispatch

proc parseargs(query: string): Table[string,string]=
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
                let q=s.find('=')
                if q>0: result.add(s.substr(0,q-1), s.substr(q+1))
                else: result.add(s, "")

settings:
        # appname="gitrelief" Dieser Name wird am Anfang von urls entfernt, er ist kein hostname.
        # bindaddr="gitrelief" Dies muss anscheinend eine numerische Adresse sein.
        port=Port(8080)
        staticdir="public"

routes:
        get "/": resp Http200, root_html
        get "/gitrelief.css": resp Http200, gitrelief_css
        get "/action/git_log":
                let A=parseargs(request.query)
                for k,v in A: echo "arg "&k&"="&v
                resp git_log(A)
        get "/action/git_diff":
                let A=parseargs(request.query)
                resp git_diff(A)
        # error Http404: resp Http404, "Looks you took a wrong turn somewhere."
        error Exception: resp Http500, "Exception caught: "&exception.msg
