
const root_html* ="""
<html>
<head>
<meta charset="utf-8">
<link rel="stylesheet" href="gitrelief.css">
<title></title>
</head>
<body>
<table><tr><td><h1>Start</h1></td><td>pwd</td></tr></table>
<p><a href="/action/git_log">Log</a></p>
<p><a href="/action/git_diff">Diff</a></p>
<p><a href="/action/git_diff?staged=1">Diff (staged)</a></p>
<p>localfiles</p>
</body>
</html>
"""

const gitrelief_css* ="""
body {
    font-family: Courier;
}
table {
    border-style: solid;
    border-width: 1px;
    border-collapse: collapse;
}
td, tr {
    border-style: dashed;
    border-width: 1px;
    border-color:lightgray;
    vertical-align: top;
    font-size: 80%;
    padding:0 .5em 0;
}
table.diff tr td {
    white-space: pre;
}

td.Acmp {
    width:50em;
    white-space: pre;
    color: red;
    /*
    text-overflow: ellipsis;
    white-space: nowrap;
    overflow: hidden; */
}
td.Acmp span {
        /*  span mit fester Breite */
            display: inline-block;
            width: 3em;
        color: black;
        background-color: #f88;
        padding: 0 0.5em 0 0;
}
td.Bcmp {
    color: green;
    width:50em;
    white-space: pre;
}
td.Bcmp span {
        /*  span mit fester Breite */
            display: inline-block;
            width: 3em;
        color: black;
        background-color: #8f8;
        padding: 0 0.5em 0 0;
}
td.Ncmp {
    color:black;
    white-space: pre;
}
td.Ncmp span {
        /*  span mit fester Breite */
            display: inline-block;
            width: 3em;
        color: black;
        background-color: white;
        padding: 0 0.5em 0 0;
}
"""
