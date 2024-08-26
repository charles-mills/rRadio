local stations = {
    {name = "90.7 Magic FM", url = "http://listen.rba.co.rw:8080/;"},
    {name = "90.7 Magic FM", url = "http://listen.rba.co.rw:8080/;"},
    {name = "Bachwezi radio ", url = "http://stream-173.zeno.fm/4vcb1euurnhvv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiI0dmNiMWV1dXJuaHZ2IiwiaG9zdCI6InN0cmVhbS0xNzMuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6Ikp6VUxidkxsUWplVE5sVjQxd3JUQWciLCJpYXQiOjE3MjQ2Mjc2MTgsImV4cCI6MTcyNDYyNzY3OH0.Grs_FeO8hFpT_eRK6OE9gIm3vnxVTSlBncFD4a4bzzs"},
    {name = "Bachwezi radio ", url = "http://stream-173.zeno.fm/4vcb1euurnhvv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiI0dmNiMWV1dXJuaHZ2IiwiaG9zdCI6InN0cmVhbS0xNzMuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6InQyc3oxWWhHVFVpU3dXQXFiWkFERFEiLCJpYXQiOjE3MjQ2NjExMDMsImV4cCI6MTcyNDY2MTE2M30.8AUnwU2xogqkcZTWx2v7wUFoBr3EwNha8cJNaWZ5i5k"},
    {name = "Country FM 105.7", url = "https://stream-151.zeno.fm/y25a3n443rhvv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJ5MjVhM240NDNyaHZ2IiwiaG9zdCI6InN0cmVhbS0xNTEuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IkVicHIweE5UU0tLUGplTV9ieElGOGciLCJpYXQiOjE3MjQ2NjM4ODEsImV4cCI6MTcyNDY2Mzk0MX0.6gtSeYniIEs8H-QtImdxq31DRbe5l3eXWPLZV-Shjmk"},
    {name = "DFM Radio ", url = "https://stream-176.zeno.fm/mtrcigb9yhitv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJtdHJjaWdiOXloaXR2IiwiaG9zdCI6InN0cmVhbS0xNzYuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6ImJveHpELVlRUmVXcENiQV9LM3kyYXciLCJpYXQiOjE3MjQ2NzQ4NTMsImV4cCI6MTcyNDY3NDkxM30.M4WI7JsM8eS1-BVdZlDX3htKmp2be9YleH6S_LLadDU"},
    {name = "DFM Radio (RW)", url = "https://stream-176.zeno.fm/fygodpmrgcquv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJmeWdvZHBtcmdjcXV2IiwiaG9zdCI6InN0cmVhbS0xNzYuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6ImxzMmRONUstU3RpY0xzNVhWNTlKY2ciLCJpYXQiOjE3MjQ2NzA4NjgsImV4cCI6MTcyNDY3MDkyOH0.Rc1Sn3iJZGmTcFqAbXmnmtD-CJIIMHqN7Sm6zNs7vB4"},
    {name = "DFM Radio Rwanda ", url = "https://stream-176.zeno.fm/fygodpmrgcquv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJmeWdvZHBtcmdjcXV2IiwiaG9zdCI6InN0cmVhbS0xNzYuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6InhLaFJQREw3UkVXMVVpc1JQMTQ1dEEiLCJpYXQiOjE3MjQ2NzkwNTIsImV4cCI6MTcyNDY3OTExMn0.x3ySAPZszKbygbDZTyB4vWCbdLcIFoGWXoNdl3JiEyQ"},
    {name = "Gendana n'igihe radio ", url = "http://stream-172.zeno.fm/1ev107turnhvv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiIxZXYxMDd0dXJuaHZ2IiwiaG9zdCI6InN0cmVhbS0xNzIuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6InhhY29mYlNmVGtXdnA2cEkya09ydlEiLCJpYXQiOjE3MjQ2NjYwNzIsImV4cCI6MTcyNDY2NjEzMn0.RRH98Zf9SWZq03IOZRxfAeHDrCknQ_FEeuKSfcDRsKA"},
    {name = "Gendana n'igihe radio ", url = "http://stream-172.zeno.fm/1ev107turnhvv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiIxZXYxMDd0dXJuaHZ2IiwiaG9zdCI6InN0cmVhbS0xNzIuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6Im9zNVZjQmEyVFlxUjJKRVRtcEhQV0EiLCJpYXQiOjE3MjQ2NTk0MTUsImV4cCI6MTcyNDY1OTQ3NX0.mzPgMlC0mqy9M6HbKNKekX9EBDswRF2o_F7i4jU-8y8"},
    {name = "Heaven FM Radio Rwanda", url = "http://stream-176.zeno.fm/eequgfw72hhvv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJlZXF1Z2Z3NzJoaHZ2IiwiaG9zdCI6InN0cmVhbS0xNzYuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6InpYeDZfaU00Uzd5SmxoaXhtdmQ0aFEiLCJpYXQiOjE3MjQ2NjI1MTAsImV4cCI6MTcyNDY2MjU3MH0.8pzOoaTeUlpxlKFoFp0uoWsImD65Qlg0YNONd0_R9y4"},
    {name = "KT Radio (96.7 MHz FM, Kigali)", url = "http://197.243.1.130:8006/k2dlivemp3"},
    {name = "Magic FM", url = "http://listen.rba.co.rw:8080/"},
    {name = "Radio 1", url = "http://80.241.215.175:5000/;"},
    {name = "RADIO MARIA RWANDA", url = "http://dreamsiteradiocp.com:8044/stream"},
    {name = "Radio Rwanda", url = "http://listen.rba.co.rw:8000/;"},
    {name = "Radio10 Rwanda (87.6 MHz FM, Kigali)", url = "http://radio10-876fm.ice.infomaniak.ch/radio10-kigali.mp3"},
    {name = "Royal FM", url = "http://80.241.215.175:3000/;"},
    {name = "Royal FM 94.3 Rwanda", url = "http://80.241.215.175:3000/;"},
    {name = "Royal FM 94.3 Rwanda", url = "http://80.241.215.175:3000/;"},
}

return stations
