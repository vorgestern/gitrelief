
import std/tables

proc git_diff*(A: Table[string,string]): string=
    result="""<html>
<head>
<meta charset="utf-8">
<link rel="stylesheet" href="/gitrelief.css">
<title></title>
</head>
<body><h1>Hier ist git_diff()</h1>
<p><a href='/'>Start</a></p>"""
    for k,v in A: result.add "<p>"&k&"="&v&"</p>"
    result.add "</body></html>"
