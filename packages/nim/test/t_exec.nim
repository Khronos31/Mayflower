import std/[os, osproc, streams]
echo "hello from nim"
echo "execShellCmd rc=", execShellCmd("echo execShellCmd via $0")
let (o, c) = execCmdEx("echo execCmdEx ok; command -v sh")
echo o, "execCmdEx rc=", c
let p = startProcess(getCurrentDir() / "t.sh", options = {poStdErrToStdOut})
echo p.outputStream.readAll(), "startProcess rc=", p.waitForExit()
