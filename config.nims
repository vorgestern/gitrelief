
switch("path", "httpbeast_fork/src")
switch("path", "jester_fork")
switch("path", "npeg")
switch("path", "checksums/src")
switch("path", "src")
switch("warning", "UnusedImport:off")

# Diese Einstellung brauchte es zunächst noch, damit man die Npeg-Parser benutzen kann.
# switch("threads", "off")
# Später stellte sich heraus, dass man die Eigenschaft {.gcsafe.} auch einem Block zuschreiben kann.
# Wenn man den Parser in einem {.gcsafe.}-Block verwendet, lässt sich das Programm ebenfalls kompilieren.
# {.gcsafe.}:
#     let r=logentryparser.match(cl, e)
#     if not r.ok:
#         e.datum=""
#         e.zeit=""
#         e.subject=cl

# Allerdings sollte der Parser (der sich const deklarieren lässt) sowieso immer gcsafe sein.
# Der Compiler scheint das in der gegenwärtigen Implementierung von npeg nicht erkennen zu können.

--outdir:"bb"
--nimcache:"bb/nimcache"

task starter, "starter release build":
        setcommand "c", "startergui/startergui.nim"
