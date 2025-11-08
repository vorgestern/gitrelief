
const root_html* ="""
<html>
<head>
<meta charset="utf-8">
<link rel="stylesheet" href="gitrelief.css">
<title></title>
</head>
<body>
<table class='head'>
<tr><td><h1>Start</h1></td><td><h1>Root</h1></td><td colspan='3'><h1>git ...</h1></td></tr>
<tr class='head'><td>&nbsp;</td><td>pwd</td>
    <td><a href="/git/log">Log</a></td>
    <td><a href="/action/git_diff">Diff</a></td>
    <td><a href="/action/git_diff?staged=1">Diff (staged)</a></td></tr>
</table>
<p>localfiles</p>
</body>
</html>
"""

const gitrelief_css* ="""
body {
    font-family: Courier;
    font-size: 18pt;
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
    padding:0 .5em 0;
}
th {
    padding:0 .5em 0;
    text-align: left;
}
table.diff tr td {
    white-space: pre;
    font-size: 70%;
}
tr.head td {
    font-size:120%;
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
