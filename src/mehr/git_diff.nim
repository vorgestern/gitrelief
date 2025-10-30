
import std/tables

proc git_diff*(A: Table[string,string]): string=
    result="<h1>Hier ist git_diff()</h1>"
    for k,v in A: result.add("<p>"&k&"="&v&"</p>")
