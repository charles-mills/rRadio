local stations = {
    {name = "Cáritas AM 680", url = "http://200.1.201.244:8000/680AM"},
    {name = "CFA Radio", url = "https://rds3.desdeparaguay.net:8002/cfa"},
    {name = "Exa FM", url = "https://14553.live.streamtheworld.com:443/XHPSFMAAC.aac"},
    {name = "Monumental 1080 AM", url = "https://us-b4-p-e-pb13-audio.cdn.mdstrm.com/live-audio-aw/62d81ca6a459e4082203c95b?aid=62d818a924cf7908229cd029&pid=CpsaMpVyXqFayU0J5TfkF50gFMp0NTXA&sid=IF8OF2Y8VlNG9RozAdYBkxvSQ02iLQkf&uid=5kSZvgbxGqXQ0hOi6kBhBPO4HdNtfunb&es=us-b4-p-e-pb13-audio.cdn.mdstrm.com&ote=1724771581613&ot=xVC8dIEgU0idcnXnja1PGQ&proto=https&pz=us&cP=128000&awCollectionId=62d818a924cf7908229cd029&liveId=62d81ca6a459e4082203c95b&listenerId=5kSZvgbxGqXQ0hOi6kBhBPO4HdNtfunb"},
    {name = "Ñanduti 1020 AM", url = "https://cp9.serverse.com/proxy/naduti1020/stream"},
    {name = "Radio ABC Cardinal 730 AM", url = "http://sc.abc.com.py:8000/stream"},
    {name = "Radio Aspen Paraguay", url = "https://tigocloud.desdeparaguay.net/movaspen/movaspen.stream/playlist.m3u8?k=cab33b6f9bb8d7e340d2a8ce8d4476e4576ce92fbc993b81666e7db795dc1da7&exp=1664206557"},
    {name = "RADIO DRAC REMIX MUSIC FM", url = "https://stream-174.zeno.fm/qtbt6vqrta0uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJxdGJ0NnZxcnRhMHV2IiwiaG9zdCI6InN0cmVhbS0xNzQuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IkdJYlg4UTdyUlBtTkNrV0I4X1RrR2ciLCJpYXQiOjE3MjQ2NjgzMjIsImV4cCI6MTcyNDY2ODM4Mn0.xXR26zK9s7PH-NtP-zGtsrfKHtK8A5gE0lKKuDjhBsE"},
    {name = "RADIO DRAC REMIX MUSIC FM", url = "https://stream-174.zeno.fm/qtbt6vqrta0uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJxdGJ0NnZxcnRhMHV2IiwiaG9zdCI6InN0cmVhbS0xNzQuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6Inp3dmt4dEhwUkZtWWwwb1dyZUZBbkEiLCJpYXQiOjE3MjQ2NzE5MTIsImV4cCI6MTcyNDY3MTk3Mn0.EI-8VhnwMk9UAp5ebAIXEh0WS4DRpj_UHsz1HSuBDzk"},
    {name = "RADIO EXITOS DE AYER", url = "http://stream-161.zeno.fm/hvnh6d5uebruv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJodm5oNmQ1dWVicnV2IiwiaG9zdCI6InN0cmVhbS0xNjEuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6Im9sVng1My0zUW9LOVloNXkwY1NHcFEiLCJpYXQiOjE3MjQ3MDA4NjQsImV4cCI6MTcyNDcwMDkyNH0.8zI5XvFgiet5HTuzbxPMhpGQjrzWpjplOcmzaz3krWY"},
    {name = "RADIO MARIA PARAGUAY", url = "http://dreamsiteradiocp.com:8090/stream"},
    {name = "Radio Nacional Del Paraguay 920 AM", url = "http://audio.radionacional.gov.py:8085/920"},
    {name = "Radio OBEDIRA Online", url = "https://s17.ssl-stream.com/proxy/obedira?mp=/live"},
    {name = "Radio Paz De Dios", url = "http://stream-176.zeno.fm/t3enydk3z98uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJ0M2VueWRrM3o5OHV2IiwiaG9zdCI6InN0cmVhbS0xNzYuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IlRlQlRVN1RjU1JLTmQxbzVUNEpLa3ciLCJpYXQiOjE3MjQ2ODQ4NzAsImV4cCI6MTcyNDY4NDkzMH0.A9GH_QK0fraScug33VKEkXZiWyYvwkShfGu_8ewGzJI"},
    {name = "Radio Tu Voz", url = "https://radiotuvoz.online/listen/radio_tu_voz_/radio.mp3"},
    {name = "RADIO VALLENATOS CLÁSICOS", url = "http://stream-169.zeno.fm/z07vyxbqz8quv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJ6MDd2eXhicXo4cXV2IiwiaG9zdCI6InN0cmVhbS0xNjkuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IkFLUWVzY1R4UUp1OFBGb2toUGdDTEEiLCJpYXQiOjE3MjQ2ODg5NDQsImV4cCI6MTcyNDY4OTAwNH0.fFnY5PUdOMPNDE_d05QEhQ8CRDDR4-82FwEI0Fu5lsE"},
    {name = "Super Radio", url = "https://c32.radioboss.fm:8139/stream"},
    {name = "Tereré Mix Paraguay", url = "https://stream-158.zeno.fm/a0z8gjrlucluv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJhMHo4Z2pybHVjbHV2IiwiaG9zdCI6InN0cmVhbS0xNTguemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IkJOaUtNZEp3UUdHWUxhbnBSdXQzYlEiLCJpYXQiOjE3MjQ2NzA2NTEsImV4cCI6MTcyNDY3MDcxMX0.Grka1E9s-0uyCN3iPfFtdfRtQorU-n2yeTJ9m_jPRw0"},
}

return stations
