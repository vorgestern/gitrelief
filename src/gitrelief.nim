
import jesterfork
import htmlgen
import mehr/[helper,git_log]

# asyncdispatch

settings:
        # appname="gitrelief" Dieser Name wird am Anfang von urls entfernt, er ist kein hostname.
        # bindaddr="gitrelief" Dies muss anscheinend eine numerische Adresse sein.
        port=Port(8080)
        staticdir="public"

routes:
        get "/": resp Http200, root_html
        get "/gitrelief.css": resp Http200, gitrelief_css
        get "/action/git_log": resp git_log()
        # error Http404: resp Http404, "Looks you took a wrong turn somewhere."
        error Exception: resp Http500, "Exception caught: "&exception.msg
