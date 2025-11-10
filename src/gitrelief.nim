
import jesterfork
import mehr/[helper]
import page/[log,diff,follow,status]
import std/[cmdline,strutils]

# asyncdispatch

# Maßnahmen
# 1.    Wirf eine Ausnahme, wenn z.B. git_follow ohne path aufgerufen wird.
# 2.    Erzeuge für Ausnahmen sinnvolle Htmlseiten.
# 3. ok Nenne git_follow um in git/follow, weitere sinngemäß.
# 4. ok Stelle in git_follow immer die vollständige Entwicklung bis zum letzten commit dar.
#       Hebe den in a=hash übergebenen commit einfach durch Fettdruck hervor.
# 5.    Follow braucht ebenfalls 'next 100' Links.
# 6.    Gib in Logs die Jahreszahl sparsam aus.

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
        if args[k]=="--port"and k+1<args.len: port=parseint args[k+1]
        if args[k]=="--public" and k+1<args.len: publicdir=args[k+1]

settings:
        # appname="gitrelief" Dieser Name wird am Anfang von urls entfernt, er ist kein hostname.
        # bindaddr="gitrelief" Dies muss anscheinend eine numerische Adresse sein.
        port=Port(port)
        staticdir=publicdir

routes:
        get "/":           resp page_status(parsequery request.query, "public")
        get "/git/log":    resp page_log(parsequery request.query)
        get "/git/follow": resp page_follow(parsequery request.query)
        get "/git/diff":   resp page_diff(parsequery request.query)
        get "/gitrelief.css": resp Http200, gitrelief_css
        # error Http404: resp Http404, "Looks you took a wrong turn somewhere."
        error Exception: resp Http500, "Exception caught: "&exception.msg
