import std/net
let ctx = newContext(verifyMode = CVerifyNone)
echo "ssl ctx ok"
var s = newSocket()
s.connect("192.168.1.1", Port(80), timeout = 3000)
echo "tcp ok"
s.close()
