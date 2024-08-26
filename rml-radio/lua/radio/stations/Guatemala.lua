local stations = {
    {name = "Así Fue Mi Vida", url = "https://sh4.radioonlinehd.com:8581/stream"},
    {name = "Computer Forensic Radio", url = "https://radio.forensedigital.gt:8020/stream"},
    {name = "Criollisima GT", url = "https://radio.forensedigital.gt:8060/stream"},
    {name = "Emaús Radio", url = "https://sh2.radioonlinehd.com:8141/;"},
    {name = "EMAUS RADIO", url = "https://sh2.radioonlinehd.com:8141/;"},
    {name = "Emisoras Unidas San Marcos", url = "https://stream-144.zeno.fm/xzvgzbfm8ueuv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJ4enZnemJmbTh1ZXV2IiwiaG9zdCI6InN0cmVhbS0xNDQuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6ImV1aGtydkc2UUY2RWhGWmV6SE9xMmciLCJpYXQiOjE3MjQ2OTE3MjEsImV4cCI6MTcyNDY5MTc4MX0.YiZOaI_qIp8BuIlic2mpG6ZZZoM16bn4vefiiieJvTQ"},
    {name = "Estéreo La Voz Del Gran Rey", url = "https://sonic.radiostreaminglatino.com:10878/;"},
    {name = "Estéreo Salvación", url = "https://server.radiogs.org/8092/stream"},
    {name = "Estéreo Santa Sion", url = "https://radio015.gt.gt/radio/8000/live.mp3"},
    {name = "Estéreo Torre Fuerte", url = "https://server.radiogs.org/8296/stream"},
    {name = "Eventos Catolicos Radio 940 AM", url = "https://stream-161.zeno.fm/1g9cduy10bruv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiIxZzljZHV5MTBicnV2IiwiaG9zdCI6InN0cmVhbS0xNjEuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IkV2a25QMWVpU2ItVjZEQVh6RlBDY1EiLCJpYXQiOjE3MjQ3MDQ4MzUsImV4cCI6MTcyNDcwNDg5NX0.hv8TSP49tIWrSVuD3-NLi9n8_y4Ze4QQ103kpYi05Zk"},
    {name = "Exa FM Guatemala", url = "https://stream-158.zeno.fm/czdkk32qduhvv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJjemRrazMycWR1aHZ2IiwiaG9zdCI6InN0cmVhbS0xNTguemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IkcxWnV6bWpLVFZHdmVSUnJBbkQ0M0EiLCJpYXQiOjE3MjQ3MDExMjMsImV4cCI6MTcyNDcwMTE4M30.oR6G6YwKjXt7a6zcPwJ4LwLsfOAM-l-8cMQNuUogsGc"},
    {name = "Felove Biblia En Quiché", url = "http://radio.produccionescasaverde.com:8788/autodj"},
    {name = "Gaiteros De Guatemala", url = "https://radio.forensedigital.gt:8030/stream"},
    {name = "Hacker Por Cristo Network", url = "https://radio.forensedigital.gt:8010/stream"},
    {name = "Ke Buena Guatemala", url = "https://stream-162.zeno.fm/m5p5sfrywhhvv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJtNXA1c2ZyeXdoaHZ2IiwiaG9zdCI6InN0cmVhbS0xNjIuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IjYtN19MU3VGUjBxM1JUSHBKSmZRdWciLCJpYXQiOjE3MjQ0MjM0MzMsImV4cCI6MTcyNDQyMzQ5M30.ZmzFfw-T7DjpOMG93m4oGwmfK5yQC2VT-FT21MFtCxY"},
    {name = "Observatorio OGDI Guatemala", url = "https://radio.forensedigital.gt:8000/stream"},
    {name = "Oriòn Stereo", url = "https://ss.redradios.net:8046/stream"},
    {name = "Palabra Miel", url = "http://juventudpalabramiel.org:8000/radio"},
    {name = "Rabito Valle", url = "https://servidor34.brlogic.com:7230/live"},
    {name = "Radio Actitud", url = "https://ss.redradios.net:8002/stream?type=.mp3"},
    {name = "Radio Camino Santidad", url = "http://audio.livecastnet.com:1290/stream"},
    {name = "Radio Católica", url = "https://diocesisdeescuintla.com/RadioCatolica"},
    {name = "Radio Cultural - Guatemala", url = "https://play10.tikast.com/proxy/tgnonline?mp=/stream"},
    {name = "Radio Cultural TGN", url = "https://stream.infinityhdstream.com/7054/stream"},
    {name = "RADIO ESLA", url = "http://stream-175.zeno.fm/wdr15uyuezzuv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJ3ZHIxNXV5dWV6enV2IiwiaG9zdCI6InN0cmVhbS0xNzUuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6Ik5HMXIyWGNQUVVtbG5ENEFpS1Z6VEEiLCJpYXQiOjE3MjQ1MjA1MTMsImV4cCI6MTcyNDUyMDU3M30.XZvPJKSJ-wu-kgtYIUS2aWmxBA_nrk7F3CLdkYdwMJ0"},
    {name = "Radio FGER 1420 AM", url = "https://aler.org:8445/fgerenlinea"},
    {name = "Radio Guate Digital", url = "https://radioguatedigital.com/live/"},
    {name = "Radio Infinita", url = "https://streams.radio.co/see730c7ab/listen"},
    {name = "RADIO MARIA GUATEMALA", url = "http://dreamsiteradiocp.com:8072/stream"},
    {name = "Radio Mesiánica", url = "https://felovemesianica-radiofelove.radioca.st/stream"},
    {name = "Radio Planeta Guatemala", url = "https://cast.az-streamingserver.com/proxy/lhufblaq?mp=/stream"},
    {name = "Radio Universidad", url = "https://stream-162.zeno.fm/xqbz7b86a0quv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJ4cWJ6N2I4NmEwcXV2IiwiaG9zdCI6InN0cmVhbS0xNjIuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6InQyNkM5dnpVUzZDdmQzellHWlM3VnciLCJpYXQiOjE3MjQ3MDYwODksImV4cCI6MTcyNDcwNjE0OX0.mu4ClpnF6nAVu32RYE6u1Ec539bE6JhbgxfGqFC2h7U"},
    {name = "Rhema Stereo", url = "https://radio.fiberstreams.com:2000/stream/8710"},
    {name = "SINAI WORKSHOP", url = "https://radio.forensedigital.gt:8070/stream"},
}

return stations