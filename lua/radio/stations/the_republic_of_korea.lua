local stations = {
    {name = "CBS Music FM Radio", url = "http://aac.cbs.co.kr:1935/cbs939/_definst_/cbs939.stream/playlist.m3u8"},
    {name = "KBS Classic FM", url = "http://serpent0.duckdns.org:8088/kbsfm.pls"},
    {name = "Big B Radio - Kpop", url = "https://antares.dribbcast.com/proxy/kpop?mp=/s"},
    {name = "올드팝카페", url = "http://cast.oldpopcafe.net:7080/"},
    {name = "KBS World Chinese Radio", url = "http://101.79.244.199:1935/cocotv/_definst_/CH00002/playlist.m3u8"},
    {name = "SBS Power FM", url = "http://serpent0.duckdns.org:8088/sbsfm.pls"},
    {name = "트로트 주막", url = "http://live10.inlive.co.kr:10560/"},
    {name = "MBC FM", url = "http://serpent0.duckdns.org:8088/mbcsfm.pls"},
    {name = "MBC FM4U", url = "http://serpent0.duckdns.org:8088/mbcfm.pls"},
    {name = "CBS 표쥰FM", url = "http://aac.cbs.co.kr/cbs981/_definst_/cbs981.stream/playlist.m3u8"},
    {name = "Kbs해피Fm", url = "http://serpent0.duckdns.org:8088/kbs2radio.pls"},
    {name = "KBS Cool FM", url = "http://serpent0.duckdns.org:8088/kbs2fm.pls"},
    {name = "BOX : K-POP 케이팝", url = "https://ss-edge.joeycast.com/kpop.mp3"},
    {name = "KBS 1R", url = "http://serpent0.duckdns.org:8088/kbs1radio.pls"},
    {name = "Listenmoe Kpop", url = "https://listen.moe/kpop/stream"},
    {name = "트로트 넘버원", url = "http://sun3303.inlive.co.kr/live/listen.pls"},
    {name = "SBS Love FM", url = "http://serpent0.duckdns.org:8088/sbs2fm.pls"},
    {name = "KBS World German Radio", url = "http://101.79.244.199:1935/cocotv/_definst_/CH00005/playlist.m3u8"},
    {name = "Cbs Music", url = "http://aac.cbs.co.kr/cbs939/_definst_/cbs939.stream/playlist.m3u8"},
    {name = "MBC충북 표준FM", url = "http://211.33.246.4:32954/radio_stfm/myStream.sdp/chunklist_w392819215.m3u8"},
    {name = "MBC충북 FM4U", url = "http://211.33.246.4:32954/radio_fm/myStream.sdp/chunklist_w348337231.m3u8"},
    {name = "KBS World Japanese Radio", url = "http://101.79.244.199:1935/cocotv/_definst_/CH00007/playlist.m3u8"},
    {name = "TJB 파워 FM POWER FM", url = "http://1.245.74.5/radiolive/radio_64k/playlist.m3u8"},
    {name = "Korea Work TV", url = "http://live.worktv.or.kr:1935/live/wowtvlive1.sdp/playlist.m3u8"},
    {name = "KBS World Russian Radio", url = "http://101.79.244.199:1935/cocotv/_definst_/CH00009/playlist.m3u8"},
    {name = "Arirang Radio", url = "http://amdlive.ctnd.com.edgesuite.net/arirang_3ch/smil:arirang_3ch.smil/playlist.m3u8"},
    {name = "Fred Film Radio한국어", url = "https://s10.webradio-hosting.com/proxy/fredradiokr/stream"},
    {name = "Gugakfm", url = "https://mgugaklive.nowcdn.co.kr/gugakradio/gugakradio.stream/chunklist_w1653570079.m3u8"},
    {name = "Listenmoe K-Pop", url = "https://listen.moe/kpop/fallback"},
    {name = "안동MBC AM", url = "http://andong.webcasting.co.kr:1935/live/amlive/playlist.m3u8"},
    {name = "CBS 음악 FM", url = "https://zstream.win/radio/cbs/musicfm"},
    {name = "Ifm 경인방손", url = "http://180.131.1.27:1935/live/bora1/playlist.m3u8"},
    {name = "CBS 표준 FM", url = "http://aac.cbs.co.kr/cbs981/cbs981.stream/playlist.m3u8"},
    {name = "평양FM", url = "https://listen7.myradio24.com/69366"},
    {name = "KBS World Arabic Radio", url = "http://101.79.244.199:1935/cocotv/_definst_/CH00001/playlist.m3u8"},
    {name = "Floyd Server Rock Balladfrom 092505", url = "http://1.uicl.co.kr:8000/;"},
    {name = "EBS TV-1", url = "http://ebsonair.ebs.co.kr/groundwavefamilypc/familypc1m/playlist.m3u8"},
    {name = "Gugak FM", url = "https://mgugaklive.nowcdn.co.kr/gugakradio/gugakradio.stream/playlist.m3u8"},
    {name = "GFN 987 FM", url = "http://218.157.19.198:8000/;stream/1"},
    {name = "Http:2112214679:1935Livemp4:Busanmbclive-Fm-0415Playlistm3U8", url = "http://211.221.46.79:1935/live/mp4:BusanMBC.Live-FM-0415/playlist.m3u8"},
    {name = "Ebs Tune In", url = "https://ebsonair.ebs.co.kr/fmradiofamilypc/familypc1m/playlist.m3u8"},
    {name = "Arirang TV", url = "http://amdlive.ctnd.com.edgesuite.net/arirang_1ch/smil:arirang_1ch.smil/playlist.m3u8"},
    {name = "KBS World TV", url = "http://edge.linknetott.swiftserve.com/channelgroup5/cg542production/ch262/03.m3u8"},
    {name = "EBS TV-2", url = "http://ebsonair.ebs.co.kr/ebs2familypc/familypc1m/playlist.m3u8"},
    {name = "마포FM", url = "http://115.85.182.39/mapofm?type=.mp3"},
    {name = "비전트로트", url = "http://smrlsepfh.inlive.co.kr/live/listen.pls"},
    {name = "Pinoy Seoul Radio 1013 FM", url = "https://securestreams.autopo.st:1215/stream"},
    {name = "WOW CCM", url = "http://wowccm.iptime.org:8000/stream/1/"},
    {name = "JTV 매직FM", url = "https://61ff3340258d2.streamlock.net/jtv_radio/myStream/chunklist_w111659793.m3u8"},
    {name = "KBS World Spanish Radio", url = "http://101.79.244.199:1935/cocotv/_definst_/CH00010/playlist.m3u8"},
    {name = "EBS Tv-E", url = "http://ebsonair.ebs.co.kr/plus3familypc/familypc1m/playlist.m3u8"},
    {name = "TBN 울산교통방송", url = "http://radio2.tbn.or.kr:1935/ulsan/myStream/playlist.m3u8"},
    {name = "TBN 교통방송", url = "http://radio2.tbn.or.kr:1935/gyeongin/myStream/playlist.m3u8"},
    {name = "EBS Tv-Plus 2", url = "http://ebsonairios.ebs.co.kr/plus2familypc/familypc1m/playlist.m3u8"},
    {name = "Buddhist Broadcasting System TV", url = "http://bbstv.clouducs.com:1935/bbstv-live/livestream/playlist.m3u8"},
    {name = "Gwangju Foreign Language Network 987 - English", url = "http://218.157.19.198:8000/"},
    {name = "Buddhist True Network TV", url = "http://btn.nowcdn.co.kr/btn/btnlive01/playlist.m3u8"},
    {name = "KBS World French Radio", url = "http://101.79.244.199:1935/cocotv/_definst_/CH00004/playlist.m3u8"},
    {name = "KBS World Vietnamese Radio", url = "http://101.79.244.199:1935/cocotv/_definst_/CH00011/playlist.m3u8"},
    {name = "Gukak", url = "http://mgugaklive.nowcdn.co.kr/gugakradio/gugakradio.stream/playlist.m3u8"},
    {name = "안동MBC FM4U", url = "https://live.andongmbc.co.kr/live/fmlive/chunklist_w778150571.m3u8"},
    {name = "HUG", url = "http://stream.zeno.fm/0966xr1y8p8uv"},
    {name = "CPBC TV", url = "http://onair1.cpbc.co.kr:1935/tv/mp4:live720/playlist.m3u8"},
    {name = "Gukak TV", url = "http://mgugaklive.nowcdn.co.kr/gugakvideo/gugakvideo.stream/playlist.m3u8"},
    {name = "EBS Tv-Kids", url = "http://ebsonairios.ebs.co.kr/ebsufamilypc/familypc1m/playlist.m3u8"},
    {name = "EBS Tv-I", url = "http://ebsonairios.ebs.co.kr/plus1familypc/familypc1m/playlist.m3u8"},
    {name = "Befm", url = "http://befm905.live.smilecdn.com:1935/befm905_live/live/playlist.m3u8"},
    {name = "RADIO FOX STYLE", url = "http://stream.zeno.fm/leyjhheodeutv"},
}

return stations
