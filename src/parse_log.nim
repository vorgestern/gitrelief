
import std/[strutils, strformat, tables, times, assertions]
import checksums/sha1
import npeg
import helper, parse_others

proc parse_log*(L: seq[string]): seq[Commit]=
        type
                context=enum None, Header, Subject, Details, Files
                parsercontext=object
                        st: context
                        was: ptr seq[Commit]
        const lineparser=peg("line", e: parsercontext):
                hash <- +{'0'..'9', 'a'..'f'}
                path <- +{33..255}
                commit <- "commit " * +@>hash:
                        var parents: seq[SecureHash]
                        for k in 2..<capture.len: parents.add parsesecurehash capture[k].s
                        e.was[].add Commit(hash: parsesecurehash $1, parents: parents)
                        e.st=Header
                merge <- "Merge:" * @>hash * @+>hash:
                        # capture[0] beschreibt die ganze Zeile.
                        # capture[1..] sind die Hashes.
                        # Die hier genannten Hashes sind einfach die Kurzformen der in der commit-Zeile genannten.
                        for k in 1..<capture.len: e.was[^1].mergeinfo.add capture[k].s
                authorname <- {33..128} * +{33..128}
                author <- "Author:" * @>authorname * @'<': e.was[^1].author= $1
                datestring <- {'0'..'9', '-'}[10] * @{'0'..'9', ':'}[8] * @ {'0'..'9', '-', '+'}[5]
                date <- "Date: " * @>datestring * !1:
                        let ts=substr($1, 0, 18)
                        e.was[^1].date=times.parse(ts, "yyyy-MM-dd HH:mm:ss")
                empty <- *{' ', '\t'} * !1:
                        e.st=case e.st
                        of Header:  Subject
                        of Subject: Details
                        of Details: Details
                        else: Files
                comment <- "    " * >+1:
                        case e.st
                        of Subject:
                                e.was[^1].subject= $1
                                e.st=Details
                        of Details: e.was[^1].details.add $1
                        else: discard
                filestatus_added <- 'A' * +{' ','\t'} * >+1: e.was[^1].files.add CommittedOperation(status: Added, path: $1)
                filestatus_modified <- 'M' * +{' ','\t'} * >+1: e.was[^1].files.add CommittedOperation(status: Modified, path: $1)
                filestatus_deleted <- 'D' * +{' ','\t'} * >+1: e.was[^1].files.add CommittedOperation(status: Deleted, path: $1)
                filestatus_renamed <- 'R' * >{'0'..'9'}[3] * @>path * @>path: e.was[^1].files.add CommittedOperation(status: Renamed, newpath: $3, oldpath: $2)
                filestatus_copied <- 'C' * >{'0'..'9'}[3] * @>path * @>path: e.was[^1].files.add CommittedOperation(status: Copied, newpath: $3, oldpath: $2)
                sonst <- >(*1) * !1: echo "Nicht erwartet: ", $1
                line <- commit | merge | author | date | empty | comment | filestatus_added | filestatus_modified | filestatus_deleted | filestatus_renamed | filestatus_copied | sonst
        var e=parsercontext(st: None, was: addr result)
        for z in L:
                {.gcsafe.}:
                        discard lineparser.match(z, e)
