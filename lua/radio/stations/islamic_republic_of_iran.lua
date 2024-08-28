local stations = {
    {name = "Radio Eram", url = "http://37.59.47.192:8200/;stream.mp3"},
    {name = "Iraninternational", url = "http://n03.radiojar.com/dfnrphnr5f0uv?rj-ttl=5&rj-tok=AAABkZksJ5QApX29GRnNkHF2QA"},
    {name = "Al Quran Radio", url = "http://n03.radiojar.com/0tpy1h0kxtzuv?rj-ttl=5&rj-tok=AAABkZZlUs8ANMGrZBUvEIzbRQ"},
    {name = "Caltexmusic", url = "http://n07.radiojar.com/cp13r2cpn3quv?rj-ttl=5&rj-tok=AAABkZkikwUAojbjMwx2-y2Kjg"},
    {name = "Iran International HTTPS Stream", url = "http://n13.radiojar.com/iintl_c?rj-ttl=5&rj-tok=AAABkZZdLnEArBQQSu6zjDhUiQ"},
    {name = "Radio Iran International", url = "http://n0f.radiojar.com/dfnrphnr5f0uv?rj-ttl=5&rj-tok=AAABkZh4p8MA83sbsXOMNDImyQ"},
    {name = "Hamsafar", url = "http://n05.radiojar.com/pyea7q9h5ehvv?rj-ttl=5&rj-tok=AAABkZgzUxcA2t0OaTrRcmcNTw"},
    {name = "Radio Navahang", url = "https://navairan.com/;stream.nsv"},
    {name = "Iran On Air", url = "http://ice41.securenetsystems.net/KIRN"},
    {name = "Faz", url = "http://www.radiofaaz.com:8000/radiofaaz"},
    {name = "Enationfm", url = "http://dal4.ir.enationfm.stream:8308/;"},
    {name = "Radio Mojdeh", url = "http://ic2326.c1261.fast-serv.com/rm128"},
    {name = "Mohammedayyub", url = "https://qurango.net/radio/mohammed_ayyub"},
    {name = "امبدد", url = "http://auds1.intacs.com/adorationgospelfm"},
    {name = "ایران‎ Radio Liberty Iran Official Stream", url = "https://n0d.radiojar.com/cp13r2cpn3quv?rj-ttl=5&rj-tok=AAABkZih-uQAEsY6zOLMzxdzYw"},
    {name = "Radio Sarcheshme", url = "https://sarcheshmeh2-ssl.icdndhcp.com/stream"},
    {name = "Iribenghelab", url = "http://s0.cdn1.iranseda.ir:1935/liveedge/radio-monasebati/chunklist_w38298230.m3u8"},
    {name = "Iribkhalije Fars", url = "http://s0.cdn1.iranseda.ir:1935/liveedgeprovincial/radio-hormozgan/playlist.m3u8"},
    {name = "Iribsaba", url = "http://s1.cdn1.iranseda.ir:1935/liveedge/radio-saba/playlist.m3u8"},
    {name = "Iribvarzesh", url = "http://s1.cdn1.iranseda.ir:1935/liveedge/radio-varzesh/playlist.m3u8"},
    {name = "Iribesfahan", url = "http://s0.cdn1.iranseda.ir:1935/liveedgeprovincial/radio-esfahan/playlist.m3u8"},
    {name = "Radio Negah Roshan", url = "http://94.182.177.79:8000/stream.ogg"},
    {name = "Iribnamayesh", url = "http://s1.cdn1.iranseda.ir:1935/liveedge/radio-namayesh/playlist.m3u8"},
    {name = "Iribenglish", url = "http://s1.cdn1.iranseda.ir:1935/liveedge/radio-english/chunklist_w1656473412.m3u8"},
    {name = "Iribkhoozestan", url = "http://s0.cdn1.iranseda.ir:1935/liveedgeprovincial/radio-khoozestan/playlist.m3u8"},
    {name = "Iribfars", url = "http://s0.cdn1.iranseda.ir:1935/liveedgeprovincial/radio-fars/playlist.m3u8"},
    {name = "Iribava", url = "http://s1.cdn1.iranseda.ir:1935/liveedge/radio-nama-ava/playlist.m3u8"},
    {name = "Iribtalavat", url = "http://s0.cdn1.iranseda.ir:1935/liveedge/radio-talavat/chunklist_w2140215930.m3u8"},
    {name = "Iribyasooj", url = "http://s0.cdn1.iranseda.ir:1935/liveedgeprovincial/radio-yasuj/playlist.m3u8"},
    {name = "Iribpayam", url = "http://s1.cdn1.iranseda.ir:1935/liveedge/radio-payam/playlist.m3u8"},
    {name = "Radio-Mazandaran", url = "http://s0.cdn1.iranseda.ir:1935/liveedgeprovincial/radio-mazandaran/playlist.m3u8"},
    {name = "Iribbooshehr", url = "http://s0.cdn1.iranseda.ir:1935/liveedgeprovincial/radio-booshehr/playlist.m3u8"},
    {name = "Iribfarhang", url = "http://s1.cdn1.iranseda.ir:1935/liveedge/radio-farhang/playlist.m3u8"},
    {name = "Iribgoftegoo", url = "http://s1.cdn1.iranseda.ir:1935/liveedge/radio-goftego/chunklist_w755519715.m3u8"},
    {name = "Iribjavan", url = "http://s1.cdn1.iranseda.ir:1935/liveedge/radio-javan/playlist.m3u8"},
    {name = "Iribiran", url = "http://s1.cdn1.iranseda.ir:1935/liveedge/radio-iran/playlist.m3u8"},
    {name = "زيارت الزيارات", url = "http://s1.cdn1.iranseda.ir:1935/liveedge/radio-ziarat/chunklist_w2134049895.m3u8"},
    {name = "Iribsalamat", url = "http://s0.cdn1.iranseda.ir:1935/liveedge/radio-salamat/chunklist_w902576092.m3u8"},
    {name = "Iribtehran", url = "http://s1.cdn1.iranseda.ir:1935/liveedge/radio-tehran/playlist.m3u8"},
    {name = "Iribmaaref", url = "http://s1.cdn1.iranseda.ir:1935/liveedge/radio-maaref/chunklist_w315273789.m3u8"},
    {name = "Iribquran", url = "http://s1.cdn1.iranseda.ir:1935/liveedge/radio-quran/chunklist_w847745462.m3u8"},
    {name = "Radio Faaz", url = "https://free.rcast.net/230792"},
    {name = "Shabro", url = "http://sptt.ir:8000/radio.ogg."},
    {name = "Radioyar", url = "https://shoutcast.glwiz.com/RadioYAR.mp3"},
    {name = "Radiosimorgh", url = "https://stream-160.zeno.fm/jl8n7thgcdftv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJqbDhuN3RoZ2NkZnR2IiwiaG9zdCI6InN0cmVhbS0xNjAuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IkxCR1NMSHNPUTZLOHUyZFY5em91RHciLCJpYXQiOjE3MjQ4MzIzMjcsImV4cCI6MTcyNDgzMjM4N30.krtBfOyH0UNSUdy3SEsvs1wrENPhd5ITjqwlOAwpWnE"},
    {name = "Radiosimorgh Authentic Iranian Music", url = "https://stream-160.zeno.fm/9svfnobkrxrvv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiI5c3Zmbm9ia3J4cnZ2IiwiaG9zdCI6InN0cmVhbS0xNjAuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6InFVZ2gwV0p1UkFTcXBobl9lWmFaX1EiLCJpYXQiOjE3MjQ4MzA0ODIsImV4cCI6MTcyNDgzMDU0Mn0.UtYRdAPYY30JzEhlDre5F9f733sfV0m9JV-51jCGQvA"},
    {name = "WS3 Radio Tahran Arabic", url = "https://live.arabicradio.net/hls/arabic_high.m3u8"},
    {name = "Parsa", url = "https://parsa2-ssl.icdndhcp.com/stream"},
    {name = "Radio Negahe Roshan", url = "https://r.ngr1.ir/stream.ogg"},
    {name = "Iribeghtesad", url = "http://s1.cdn1.iranseda.ir:1935/liveedge/radio-eghtesad/playlist.m3u8"},
    {name = "قرآن، طعم آفتاب زنده", url = "http://s1.cdn2.iranseda.ir:1935/liveedge/radio-quran/chunklist_w1668184178.m3u8"},
    {name = "Radio Tehran", url = "https://live4.presstv.ir/irib/irib1/playlist.m3u8"},
    {name = "Radio Mojahed - رادیو مجاهد", url = "https://s2.radio.co/s830691c74/listen"},
    {name = "Radio Persian", url = "http://r.pgbu.ir:8000/live"},
    {name = "Go", url = "https://stream-167.zeno.fm/v5kxmagseg0uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJ2NWt4bWFnc2VnMHV2IiwiaG9zdCI6InN0cmVhbS0xNjcuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IkYwTjJsdFZHUUVPM0c5MjNiVEl3dXciLCJpYXQiOjE3MjQ4MTUzNDMsImV4cCI6MTcyNDgxNTQwM30.52LCpaT-9w7sPWwhDj93BteEQvuLvygYF1nFvE4XMwE"},
    {name = "آونگ کلاپ", url = "https://stream-176.zeno.fm/fpabqr8pd9zuv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJmcGFicXI4cGQ5enV2IiwiaG9zdCI6InN0cmVhbS0xNzYuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6InZPeTZzLWVRUzNtRWNsRGlRSk9KT2ciLCJpYXQiOjE3MjQ4NDMwMTEsImV4cCI6MTcyNDg0MzA3MX0.pKl8whR67_m7xbNYEZUUxMNM9esbykpnkMZ3tJXu3fc"},
    {name = "Radio Khatereh", url = "https://servidor22-5.brlogic.com:7160/live?source=website"},
}

return stations