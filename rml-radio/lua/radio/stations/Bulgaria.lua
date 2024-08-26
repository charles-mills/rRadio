local stations = {
    {name = "1 Rock Bulgaria", url = "http://31.13.223.148:8000/1_rock.mp3"},
    {name = "ARABESKİN MERKEZİ FM BULGARİA", url = "https://canli.arabeskinmerkezi.com/9180/stream"},
    {name = "ARHEA ORG", url = "http://stream-153.zeno.fm/na6nbx6qqwzuv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJuYTZuYng2cXF3enV2IiwiaG9zdCI6InN0cmVhbS0xNTMuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IkMyeHdpYXFOUldxbW5qUUhDdDlTd1EiLCJpYXQiOjE3MjQ2ODMwNTMsImV4cCI6MTcyNDY4MzExM30.K2rEpmZdP-QcQBax-YB12YQFlzpczakGH6a8muByUvI"},
    {name = "AVTO RADIO", url = "https://25433.live.streamtheworld.com/AVTORADIOAAC_H.aac?dist=PREDAVATEL"},
    {name = "Avtoradio", url = "https://25693.live.streamtheworld.com/AVTORADIOAAC_L.aac?dist=onlineradiobox"},
    {name = "Bad Rock Radio 1", url = "https://play-radio0.jump.bg:7028/live"},
    {name = "Bad Rock Radio-Classic Rock", url = "https://radio.jump.bg:7489/live"},
    {name = "Badrock Classic Rock", url = "https://play-radio0.jump.bg:7489/live"},
    {name = "Badrock Radio", url = "https://radio.jump.bg:7028/live"},
    {name = "Badrock Radio National", url = "https://radiocp.jump.bg/proxy/stan1?mp=/live"},
    {name = "Bar Friends Pernik", url = "http://79.98.108.170:8278/autodj"},
    {name = "Bg Estrada", url = "https://25453.live.streamtheworld.com:443/BG_ESTRADAAAC_L.aac?dist=onlineradiobox"},
    {name = "BG Radio", url = "http://stream.radioreklama.bg/bgradio128"},
    {name = "BNR - Hristo Botev", url = "http://stream.bnr.bg:8012/hristo-botev.aac"},
    {name = "BNR Burgas", url = "http://stream.bnr.bg:8037/radio-burgas.aac"},
    {name = "BNR Horizont", url = "https://play.global.audio/testb.aac?dist=RADIOPLAY"},
    {name = "BNR Radio Shumen", url = "http://stream.bnr.bg:8033/radio-shumen.aac"},
    {name = "BNR Stara Zagora", url = "http://82.103.99.99:8000/radiosz"},
    {name = "BNR Varna", url = "http://broadcast.masters.bg:8000/live"},
    {name = "Braille FM", url = "https://radio.jump.bg:7181/live"},
    {name = "Btv Radio", url = "https://cdn.bweb.bg/radio/btv-radio.mp3"},
    {name = "Bumerang FM", url = "http://185.20.88.1:8010/"},
    {name = "Casino Web Radio", url = "http://79.98.108.170:8026/live"},
    {name = "Cherveniat Papagal", url = "https://stream-151.zeno.fm/80qzq207rm0uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiI4MHF6cTIwN3JtMHV2IiwiaG9zdCI6InN0cmVhbS0xNTEuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IkxaSFhnNG41UlAyTENZRFR3VmdaeWciLCJpYXQiOjE3MjQ2ODExNDcsImV4cCI6MTcyNDY4MTIwN30.2T7j6nt-bRaHCjO0HQlEKyb3PbrUVuDXpxff8gZ-mmw"},
    {name = "City Bulgaria", url = "http://31.13.223.148:8000/city.mp3"},
    {name = "City Latin", url = "https://play.global.audio/citylatin.aac"},
    {name = "City Radio Bulgaria", url = "https://play.global.audio/city.opus"},
    {name = "Coda Radio By Metropolis", url = "https://metropolis.bg:8443/codaradio"},
    {name = "Dan Pen Radio", url = "https://server.danpenradio.net/listen/danpen_radio/radio.mp3"},
    {name = "Dance With Me", url = "http://g5.turbohost.eu:8002/stream320"},
    {name = "DARIK", url = "https://darikradio.by.host.bg:8000/S2-128"},
    {name = "Darik Nostalgie", url = "https://darikradio.by.host.bg:8000/Nostalgie"},
    {name = "Darik Radio", url = "https://darikradio.by.host.bg:8000/S2-128"},
    {name = "Deep Lounge", url = "https://radio.jump.bg/proxy/georgi18/stream"},
    {name = "Deep Radio Europe", url = "http://79.98.108.174:8000/stream"},
    {name = "DJ Zone House", url = "http://162.244.80.106:11181/stream"},
    {name = "Easy Radio", url = "http://live.easyradio.bg/192"},
    {name = "Easyradio", url = "http://live.easyradio.bg/aac"},
    {name = "Eilo Earth And Beat", url = "https://eilo.org/earthbeat"},
    {name = "Eilo Radio - Progressive Radio", url = "https://eilo.org/streamer.php?ch=progressive"},
    {name = "EILO Techno Radio", url = "https://eilo.org/streamer.php?ch=techno"},
    {name = "EILO Trance Radio", url = "https://eilo.org/streamer.php?ch=trance"},
    {name = "Energy 00S", url = "https://play.global.audio:80/energy-00s.aac"},
    {name = "Energy 90S", url = "https://play.global.audio/energy-90s"},
    {name = "Energy Bulgaria", url = "http://149.13.0.80/nrj128"},
    {name = "Extreme Deep House", url = "http://whsh4u-panel.com:14113/stream"},
    {name = "Extreme Deep House Radio", url = "https://whsh4u-panel.com/proxy/yfryujzw/stream"},
    {name = "Focus", url = "https://focusradio.dataserv.cc/1"},
    {name = "Fresh Bulgaria", url = "http://31.13.223.148:8000/fresh.mp3"},
    {name = "Hot Dance", url = "http://listen.hotget.net:810/"},
    {name = "Hot Hits FM", url = "https://live.hothitsfm.com/stream"},
    {name = "Jazz FM", url = "https://cdn.bweb.bg/radio/jazz-fm.mp3"},
    {name = "KATRA FM", url = "http://www.katrafm.com:8000/live"},
    {name = "Kiss", url = "https://bss2.neterra.tv/kiss/kiss_0.m3u8"},
    {name = "KOLEDNOTO RADIO", url = "https://play.global.audio/radio1-koleda.aac"},
    {name = "Lele Male", url = "http://79.98.108.170:8332/;"},
    {name = "Luxor Web Radio", url = "http://79.98.108.170:8078/autodj"},
    {name = "MAGIC FM", url = "https://bss1.neterra.tv/magicfm/magicfm.m3u8"},
    {name = "Magic Party", url = "https://bss2.neterra.tv/magicparty/magicparty_0.m3u8"},
    {name = "Maxx FM Bulgaria", url = "https://play.radiomaxxfm.com/maxx-lo"},
    {name = "Maya Burgas", url = "http://rnmediagroup.com:9000/;"},
    {name = "Maya Varna", url = "http://rnmediagroup.com:10000/;"},
    {name = "Metro Country Rock", url = "https://eu1.reliastream.com/proxy/feedb?mp=/CRR64"},
    {name = "Metro Dance Radio", url = "https://eu1.reliastream.com/proxy/mdr?mp=/MDR"},
    {name = "Metro Hits", url = "https://eu1.reliastream.com/proxy/mhr?mp=/MHR"},
    {name = "Metro HITS Radio", url = "https://eu1.reliastream.com/proxy/mhr?mp=/MHR"},
    {name = "Metro Love", url = "https://eu1.reliastream.com/proxy/service?mp=/service"},
    {name = "Metro Love 00S", url = "https://eu1.reliastream.com/proxy/metroplusc?mp=/MLR2K"},
    {name = "Metro Love 80S", url = "https://eu1.reliastream.com/proxy/love80?mp=/MLR80S"},
    {name = "Metro Love 90S", url = "https://eu1.reliastream.com/proxy/love80?mp=/MLR80S"},
    {name = "Metro Love 90S Plus", url = "https://eu1.reliastream.com/proxy/love80?mp=/MLR90S"},
    {name = "Metro Love Hits", url = "https://eu1.reliastream.com/proxy/service?mp=/service"},
    {name = "Metro Top Radio", url = "https://eu1.reliastream.com/proxy/mgr?mp=/MGR"},
    {name = "Metro Urban Hits", url = "https://eu1.reliastream.com/proxy/metroxmas?mp=/MCR"},
    {name = "Metro Virtuoso", url = "https://eu1.reliastream.com/proxy/mvr?mp=/MVR"},
    {name = "Metro Virtuoso Hits", url = "https://eu1.reliastream.com/proxy/mvr?mp=/MVR"},
    {name = "Mixx", url = "http://83.97.65.98:9000/"},
    {name = "N-JOY", url = "https://cdn.bweb.bg/radio/njoy.mp3"},
    {name = "NJOY Summer Mood", url = "https://cdn.bweb.bg/radio/njoy.mp3"},
    {name = "NJS Radio - New Jack Swing", url = "http://162.244.80.106:11198/"},
    {name = "Note FM", url = "http://stream-153.zeno.fm/rvw1h2zk7s8uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJydncxaDJ6azdzOHV2IiwiaG9zdCI6InN0cmVhbS0xNTMuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6ImRia05MT2djUWQtbFRaNjNwNWc5UEEiLCJpYXQiOjE3MjQ2ODc5NTEsImV4cCI6MTcyNDY4ODAxMX0.zRHWABCIfeOPHlwfjCZhCyFtCTahVDMhY7ho-KNxi7c"},
    {name = "Note Party", url = "http://stream-153.zeno.fm/ux3k5mabt18uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJ1eDNrNW1hYnQxOHV2IiwiaG9zdCI6InN0cmVhbS0xNTMuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6Il9jMjdTdVl0Um15TU1XeEljemR5ZFEiLCJpYXQiOjE3MjQ2NzE1MzgsImV4cCI6MTcyNDY3MTU5OH0.SMK3EFzuJjhXw1FRj7J8a9z5vIuoaB7v0nB0LYruKAA"},
    {name = "Nova", url = "http://stream.metacast.eu/nova.ogg"},
    {name = "Nova Bulgaria", url = "http://31.13.223.148:8000/nova.mp3"},
    {name = "Nova News", url = "http://stream.radioreklama.bg/novanews.aac"},
    {name = "Novanews Bulgaria", url = "https://play.global.audio/novanews.aac"},
    {name = "Online DJ Radio 64", url = "http://play-radio11.jump.bg:8000/stream64_autodj"},
    {name = "Onlinedjradio", url = "https://play.onlinedjradio.com:7000/live"},
    {name = "Power FM Bulgaria", url = "https://a1.vizitec.com:8001/powerfm.mp3"},
    {name = "Radio 1", url = "http://stream.metacast.eu/radio1128"},
    {name = "Radio 1 Bulgaria", url = "https://play.global.audio:80/radio164"},
    {name = "Radio 1 Rock", url = "https://25643.live.streamtheworld.com/RADIO_1_ROCKAAC_H.aac?dist=DESKTOP"},
    {name = "Radio 1 Радио 1 Класическите Хитове", url = "http://stream.radioreklama.bg/radio164"},
    {name = "Radio 999", url = "http://62.204.158.5:8081/live"},
    {name = "Radio AXE Project", url = "http://79.98.108.170:8004/autodj"},
    {name = "Radio Beatport", url = "http://79.98.108.170:8014/autodj"},
    {name = "Radio Beinsa Duno", url = "http://87.252.182.193:8000/;"},
    {name = "Radio Belisimo", url = "http://79.98.108.170:8002/;"},
    {name = "Radio BG London", url = "https://live.radiobg.co.uk:8443/live"},
    {name = "Radio BG London Plus", url = "http://live.radiobg.co.uk:8000/live"},
    {name = "RADIO BGRADIO", url = "https://play.global.audio/bgradio128"},
    {name = "Radio Bojia Sila", url = "https://stream-151.zeno.fm/6t0ec6rwtuquv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiI2dDBlYzZyd3R1cXV2IiwiaG9zdCI6InN0cmVhbS0xNTEuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6InNpWlhja1dJVEh5ak5zMk9WekF0eUEiLCJpYXQiOjE3MjQ2NzY0NDAsImV4cCI6MTcyNDY3NjUwMH0.eNMdneGaAreqMcycKXL5B8yuAaEX__Jxpd8-CqVDViQ"},
    {name = "RADIO CITY", url = "http://play.global.audio/city64"},
    {name = "Radio Contact", url = "https://listen.radioking.com/radio/490082/stream/546899"},
    {name = "Radio Deep Disco", url = "http://79.98.108.170:8000/autodj"},
    {name = "Radio Dobrudja", url = "http://5.104.174.128:8000/radiodobrudja"},
    {name = "Radio Eilo - Techno", url = "http://eilo.org:8000/techno"},
    {name = "Radio Eilo - Trance", url = "http://eilo.org:8000/trance"},
    {name = "Radio El Shada", url = "https://stream-174.zeno.fm/hku46gxdexquv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJoa3U0Nmd4ZGV4cXV2IiwiaG9zdCI6InN0cmVhbS0xNzQuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IkxOaWVGa0s5VEg2TTRocUI4bU05VWciLCJpYXQiOjE3MjQ2ODE1NjgsImV4cCI6MTcyNDY4MTYyOH0.mruGuEzkuAPR82oIdiSSkSm2902j8PURZVo-hr2O9Z8"},
    {name = "Radio Energy 90S Only Sofia", url = "https://play.global.audio/energy-90s.aac"},
    {name = "Radio Energy 90S Only Sofia 128K", url = "https://play.global.audio/energy-90s"},
    {name = "Radio Evangelie", url = "http://79.98.108.170:8078/autodj"},
    {name = "Radio Family", url = "http://a1.virtualradio.eu:8000/family.mp3"},
    {name = "Radio Favorit", url = "http://79.98.108.170:8235/stream"},
    {name = "Radio Folk Convert", url = "http://79.98.108.170:8039/autodj"},
    {name = "Radio Gamma", url = "http://g5.turbohost.eu:8003/gama128"},
    {name = "Radio Globe", url = "http://79.98.108.170:8019/autodj"},
    {name = "Radio Helikon", url = "http://87.121.90.229:9000/live_128"},
    {name = "Radio Horo", url = "http://g5.turbohost.eu:8020/stream256"},
    {name = "Radio Horo Plus", url = "http://g5.turbohost.eu:8020/stream256"},
    {name = "Radio Hotel Olimp", url = "http://79.98.108.170:8048/autodj"},
    {name = "Radio Hushove", url = "http://79.98.108.173:8006/radioxaschove"},
    {name = "Radio Jega", url = "http://g5.turbohost.eu:8004/stream"},
    {name = "Radio Jega Жега", url = "http://g5.turbohost.eu:8004/stream"},
    {name = "Radio Jugomania", url = "https://s8.yesstreaming.net:17051/autodj"},
    {name = "Radio Kesarevo", url = "https://ssl22.radyotelekom.com/8136/stream"},
    {name = "Radio Lagoshevtsi", url = "http://radio.jump.bg:8484/stream"},
    {name = "Radio M 35", url = "http://79.98.108.170:8029/autodj"},
    {name = "Radio Magic Fm", url = "https://bss1.neterra.tv/magicfm/magicfm.m3u8"},
    {name = "Radio Maia", url = "https://radio.rn-tv.com:8000/stream/1/"},
    {name = "Radio Mall Sofia", url = "http://79.98.108.170:8104/autodj"},
    {name = "Radio Melodia Silistra", url = "http://g5.turbohost.eu:8010/stream128"},
    {name = "Radio Melody", url = "http://193.108.24.6:8000/melody?file=.mp3"},
    {name = "Radio Metronom", url = "http://radiometronom.com:8010/"},
    {name = "Radio Music BG", url = "http://79.98.108.170:8243/stream"},
    {name = "Radio N-Joy Bulgaria", url = "https://cdn.bweb.bg/radio/njoy.mp3"},
    {name = "Radio Nazdrave", url = "http://powerdj.sf.ddns.bulsat.com:8066/;"},
    {name = "Radio Nostalgia", url = "https://stream-176.zeno.fm/bfkspxrh4zhvv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJiZmtzcHhyaDR6aHZ2IiwiaG9zdCI6InN0cmVhbS0xNzYuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6ImhGTmg4REJwUU1xa0V6UnhtSHlfVGciLCJpYXQiOjE3MjQ2OTA5NjAsImV4cCI6MTcyNDY5MTAyMH0.LdPQSt6bL66GsOZssJSQSuap9_vupdsqJUNPZp5kq6s"},
    {name = "Radio Nova Bulgaria", url = "https://play.global.audio/nova.opus"},
    {name = "Radio Nova News", url = "https://25693.live.streamtheworld.com/RADIO_NOVANEWSAAC_L.aac"},
    {name = "Radio Nova Zagora", url = "http://80.253.48.162:8090/nova.mp3"},
    {name = "Radio ORV", url = "http://radio.orvmedia.com:8005/stream"},
    {name = "Radio Pianica", url = "http://mpc1.mediacp.eu:8024/"},
    {name = "Radio Razgrad", url = "http://188.126.1.25:8000/razgrad"},
    {name = "Radio Retro Folk", url = "http://79.98.108.170:8053/"},
    {name = "Radio Rezonans", url = "http://88.87.10.53:8000/*.ogg"},
    {name = "Radio Rila Folk", url = "http://79.98.108.176:8016/;"},
    {name = "Radio Rock And Blues", url = "http://79.98.108.170:8029/autodj"},
    {name = "Radio Sevlievo", url = "http://195.68.214.130:8000/"},
    {name = "Radio Sladko Izkushenie", url = "http://g5.turbohost.eu:8006/autodj"},
    {name = "Radio Slavi", url = "http://79.98.108.170:8043/;"},
    {name = "Radio Slavianska Parodia", url = "http://79.98.108.170:8033/autodj"},
    {name = "Radio Strimonika", url = "https://play-radio0.jump.bg:7666/stream"},
    {name = "Radio Sunny Beach", url = "https://sunny-beachradio.stream.laut.fm/sunny-beachradio"},
    {name = "Radio Teteven", url = "http://g5.turbohost.eu:8001/teteven"},
    {name = "Radio The Voice", url = "https://bss1.neterra.tv/thevoicefm/thevoicefm.m3u8"},
    {name = "Radio Tomeko", url = "http://79.98.108.170:8024/live"},
    {name = "Radio Usmivka", url = "http://79.98.108.170:8025/stream"},
    {name = "Radio Vega Plus", url = "http://88.80.96.25:40070/vega.mp3"},
    {name = "Radio Venseremos", url = "https://listen7.myradio24.com/venceremos"},
    {name = "RADIO VERONIKA", url = "https://play.global.audio/veronika64"},
    {name = "Radio Veselina", url = "https://bss1.neterra.tv/veselina/veselina.m3u8"},
    {name = "Radio Veselina Bulgaria", url = "https://bss1.neterra.tv/veselina/veselina.m3u8"},
    {name = "Radio Veselina Folklor", url = "https://bss2.neterra.tv/veselinafolk/veselinafolk_0.m3u8"},
    {name = "Radio Veselina Retro", url = "https://bss2.neterra.tv/veselinaretro/veselinaretro_0.m3u8"},
    {name = "Radio Vidin", url = "http://89.106.110.85:8000/"},
    {name = "Radio Vitosha", url = "https://bss1.neterra.tv/vitosha/vitosha.m3u8"},
    {name = "Radio Winbet", url = "http://79.98.108.170:8010/autodj"},
    {name = "Radio Z-Rock Bulgaria", url = "https://cdn.bweb.bg/radio/z-rock.mp3"},
    {name = "Radio Zone Mix", url = "http://79.98.108.170:8036/autodj"},
    {name = "Radio Zorana Sofia", url = "https://radio.jump.bg/proxy/radio12/stream"},
    {name = "Radioplay Cafe", url = "https://play.global.audio/cafehi.aac"},
    {name = "Raimos Disco Radio", url = "http://a1.virtualradio.eu:8000/discoradio"},
    {name = "Raimos Hits Radio", url = "http://a3.virtualradio.eu:8000/pstz.mp3"},
    {name = "Raimos Rock Radio", url = "http://a1.virtualradio.eu:8000/rockradio"},
    {name = "Raimos Smooth Radio", url = "http://a3.virtualradio.eu:8000/softz.mp3"},
    {name = "Stream House Radio", url = "http://79.98.108.170:8018/autodj"},
    {name = "Sunny Beach Radio", url = "https://sunny-beachradio.stream.laut.fm/sunny-beachradio"},
    {name = "SWEET RADIO", url = "http://cdn.tvoetoradio.net:8000/test"},
    {name = "Tangra Mega Rock", url = "http://stream-bg-01.radiotangra.com:8000/Tangra.ogg"},
    {name = "Test NRJ Sergio IP", url = "http://149.13.0.80/energy-90s"},
    {name = "The Voice Of Bulgaria", url = "https://bss2.neterra.tv/voiceofbg/voiceofbg_0.m3u8"},
    {name = "Traffic Radio Station", url = "http://radio.networx.bg:8000/TrafficRadio"},
    {name = "Turbo Lounge", url = "http://79.98.108.170:8115/autodj"},
    {name = "Turbo Web", url = "http://79.98.108.170:8116/autodj"},
    {name = "TV 1 Radio", url = "https://tv1.cloudcdn.bg:8081/stream.m3u8"},
    {name = "TV Art", url = "https://stream.osc.bg/tvart/Stream3/playlist.m3u8"},
    {name = "Tvoeto Radio", url = "http://79.98.108.173:8010/radio"},
    {name = "Ultra Blagoevgrad", url = "http://88.80.96.25:3060/"},
    {name = "Ultra Pernik", url = "http://88.80.96.25:8000/"},
    {name = "Ultra Sandanski", url = "http://88.80.96.25:8000/"},
    {name = "Vanilla", url = "https://play.global.audio/vanillahi.aac"},
    {name = "Venceremos", url = "https://listen7.myradio24.com/venceremos"},
    {name = "Veronika", url = "http://stream.metacast.eu/veronika.ogg"},
    {name = "Vocal Mix Radio", url = "http://79.98.108.170:8015/autodj"},
    {name = "Xradyo 1", url = "https://xraydio.ddns.net/live"},
    {name = "Xraydio 2", url = "https://xraydio.ddns.net/jukebox"},
    {name = "Z-Rock Alt", url = "http://193.108.24.6:8000/zrock"},
    {name = "Zetra", url = "http://79.98.108.170:8092/;"},
    {name = "Авторадио", url = "http://play.global.audio/avtoradio.opus"},
    {name = "БНР Хоризонт", url = "http://stream.bnr.bg:8011/horizont.aac"},
    {name = "БНР Христо Ботев", url = "http://stream.bnr.bg:8012/hristo-botev.aac"},
    {name = "Дарик Носталджи", url = "https://darikradio.by.host.bg:8000/Nostalgie"},
    {name = "Мая", url = "http://www.rnmediagroup.com:9000/"},
    {name = "Общинско Радио Разград", url = "http://188.126.1.25:8000/razgrad"},
    {name = "Радио CITY", url = "http://31.13.223.148:8000/city.mp3"},
    {name = "Радио Варна", url = "http://broadcast.masters.bg:8000/live"},
    {name = "Радио Жега 96", url = "http://g5.turbohost.eu:8004/stream96"},
    {name = "Радио Канон - Radio Kanon", url = "http://79.98.108.170:8059/stream"},
    {name = "Радио Пайнер", url = "http://87.120.6.86:8000/hq"},
    {name = "Радио Пауър ФМ - Radio Power FM", url = "http://a1.virtualradio.eu:8000/powerfm.mp3"},
    {name = "Радио Пияника", url = "http://mpc1.mediacp.eu:8024/;"},
    {name = "Радио Хоро", url = "http://g5.turbohost.eu:8020/stream256"},
}

return stations