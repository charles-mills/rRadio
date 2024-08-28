local stations = {
    {name = "Infovojna", url = "http://159.69.219.5:8010/aac"},
    {name = "Mirjam Rádio - Mária Rádió Felvidék", url = "http://193.87.81.131:8081/MariaRadioFelvidek"},
    {name = "JOJ 24", url = "https://live.cdn.joj.sk/live/joj_news.m3u8"},
    {name = "Joj 24 404 P", url = "https://live.cdn.joj.sk/live/andromeda/joj_news-404.m3u8"},
    {name = "Rádio Beta", url = "http://109.71.67.102:8000/beta_live_high.mp3"},
    {name = "Radio Dychovka", url = "https://epanel.mediacp.eu:7661/stream"},
    {name = "Dobré Rádio", url = "http://stream.dobreradio.sk:8813/dobreradio.mp3"},
    {name = "Rádio Beta - Hity 80'S A 90'S", url = "http://109.71.67.102:8000/beta_80a90.mp3"},
    {name = "Fred Film Radio-25 Slovenčina", url = "https://s10.webradio-hosting.com/proxy/fredradiosk/stream"},
    {name = "Fit Famili Rádio", url = "https://solid1.streamupsolutions.com/proxy/utwrguip/stream"},
    {name = "Československé Radio", url = "http://live.topradio.cz:8000/csradio128"},
    {name = "G-Radio", url = "http://88.212.34.18:8050/mp3midband"},
    {name = "Radio Extra", url = "http://live.topradio.cz:8000/extra192"},
    {name = "Rádio Aetter", url = "http://stream.aetter.sk:8000/aetter"},
    {name = "Rádio Beta - České A Slovenské Hity", url = "http://109.71.67.102:8000/beta_cspop.mp3"},
    {name = "Rádio KIKS - Big 80S", url = "https://online.radiokiks.sk:8000/kiks_big80s.mp3"},
    {name = "FRESH Rádio", url = "https://icecast2.radionet.sk/freshradio.sk"},
    {name = "Rádio Expres", url = "http://195.168.61.226:8000/128.mp3"},
    {name = "Radio Expres", url = "http://195.168.61.226:8000/96.mp3"},
    {name = "BB FM Rádio", url = "http://stream.bbfm.sk/bbfm128.mp3"},
    {name = "Funradio Live", url = "http://stream.funradio.sk:8000/funpgm256.mp3"},
    {name = "Funrádio Mileniálky", url = "http://stream.funradio.sk:8000/milenialky128.mp3"},
    {name = "FUN RÁDIO 80-90", url = "http://stream.funradio.sk:8000/80-90-128.mp3"},
    {name = "Fun Radio", url = "http://stream.funradio.sk:8000/fun128.mp3"},
    {name = "Fun Radio CZ", url = "http://stream.funradio.sk:8000/cs128.mp3"},
    {name = "FUN RÁDIO DANCE", url = "http://stream.funradio.sk:8000/dance128.mp3"},
    {name = "RADIO BIBLIA SK", url = "http://radiobiblia.online:8000/stream.ogg"},
    {name = "Radio 7", url = "https://play.radio7.sk/128"},
    {name = "Rádio KIKS", url = "https://online.radiokiks.sk:8000/kiks_hq.mp3"},
    {name = "Lux TV", url = "https://stream.tvlux.sk/lux/ngrp:lux.stream_all/playlist.m3u8"},
    {name = "Irock", url = "https://radioserver.online:9927/irockHQ.mp3"},
    {name = "Bestfm", url = "https://stream3.bestfm.sk:8000/160.aac"},
    {name = "Rádio Bestfm", url = "https://stream3.bestfm.sk:8000/128.mp3"},
    {name = "Rádio Jazz", url = "http://stream.sepia.sk:8000/jazz128.mp3"},
    {name = "Rádio Jupiter", url = "http://stream.radiojupiter.sk:8000/jupiter_64.aac"},
    {name = "METALSCENA Netradio", url = "https://listen.radioking.com/radio/263218/stream/308365"},
    {name = "RÁDIO FM", url = "https://icecast.stv.livebox.sk/fm_128.mp3"},
    {name = "Pátria Rádió", url = "https://icecast.stv.livebox.sk/patria_128.mp3"},
    {name = "Rádio KIKS - Big 90S", url = "https://online.radiokiks.sk:8000/kiks_big90s.mp3"},
    {name = "Funrádio Úsmev", url = "https://stream.funradio.sk/usmev128.mp3"},
    {name = "Radio Ekspres", url = "https://stream.nextmedia.si/proxy/ekspres1?mp=/stream"},
    {name = "Europa 2", url = "https://stream.bauermedia.sk/europa2.mp3"},
    {name = "Rádio KIKS - Rock Music", url = "https://online.radiokiks.sk:8000/kiks_rock.mp3"},
    {name = "Funradio Live 256Kbps", url = "https://stream.funradio.sk:8000/funpgm256.mp3"},
    {name = "Fun Radio Chill", url = "https://stream.funradio.sk:8000/chill128.mp3"},
    {name = "Radio Expres SK", url = "https://stream.expres.sk/128.mp3"},
    {name = "Rádio Modra", url = "http://185.98.208.12:8000/"},
    {name = "Hitrádio Slovakia", url = "https://hitradioslovakia.stream.laut.fm/hitradioslovakia"},
    {name = "Rádio Košice BA", url = "http://176.102.98.74:8000/radiokosice-ba-128.mp3"},
    {name = "Rádio Topoľčany", url = "http://80.242.44.249:8000/;"},
    {name = "Rádio Topolčany", url = "http://80.242.44.249:8000/"},
    {name = "Rádio V Nitre", url = "http://195.210.28.150:8932/radiovnitre_live.mp3"},
    {name = "RÁDIO VIVA", url = "http://stream.sepia.sk:8000/viva128.mp3"},
    {name = "Radio Vega", url = "http://stream.sepia.sk:8000/vega128.mp3"},
    {name = "Rádio Maria Slovensko", url = "http://dreamsiteradiocp5.com:8012/streaming.mp3"},
    {name = "Rádio Piešťany", url = "http://live.radiopiestany.sk:8000/live.mp3"},
    {name = "Rádio Košice", url = "http://stream.ecce.sk:8000/radiokosice-128.mp3"},
    {name = "Radiox - Alternative X", url = "http://158.193.82.41:8000/alternative.mp3"},
    {name = "Radiox", url = "http://158.193.82.41:8000/radiox_128.mp3"},
    {name = "Rádio Muzika", url = "https://listen.radioking.com/radio/276343/stream/321988"},
    {name = "Rádio Lumen", url = "http://audio.lumen.sk:8000/live128.mp3"},
    {name = "Rádio Frontinus", url = "http://stream.frontinus.sk:8000/frontinus128.mp3"},
    {name = "Radiox - Dance X", url = "http://158.193.82.41:8000/dance.mp3"},
    {name = "Rádio Pohoda 2", url = "http://mpc1.mediacp.eu:18111/stream"},
    {name = "Radiox - Chillout X", url = "http://158.193.82.41:8000/chillout.mp3"},
    {name = "Rádio REGINA ZÁPAD", url = "https://icecast.stv.livebox.sk/regina-ba_128.mp3"},
    {name = "RÁDIO SLOVENSKO", url = "https://icecast.stv.livebox.sk/slovensko_128.mp3"},
    {name = "Radiox - Folklore X", url = "http://158.193.82.41:8000/ludovky.mp3"},
    {name = "Rádio Vlna", url = "http://stream.radiovlna.sk/vlna-hi.mp3"},
    {name = "Rádio Vlna CLASSIC ROCK", url = "http://stream.radiovlna.sk:8000/rock-hi.mp3"},
    {name = "Rádio Paráda", url = "https://extra.mediacp.eu/stream/RadioParada,o.z."},
    {name = "Rádio Sity", url = "https://radiosity.online:8000/aac"},
    {name = "Radiox - Oldies X", url = "http://158.193.82.41:8000/oldies.mp3"},
    {name = "RÁDIOFM", url = "http://live.slovakradio.sk:8000/FM_256.mp3"},
    {name = "Radiox - Dnb X", url = "http://158.193.82.41:8000/dnb.mp3"},
    {name = "Radiox - Metal X", url = "http://158.193.82.41:8000/metal.mp3"},
    {name = "Rádio MÁRIA SLOVENSKO", url = "https://dreamsiteradiocp5.com/proxy/radiomariaslomp3?mp=/stream.mp3"},
    {name = "Radio TLIS", url = "https://stream.tlis.sk/tlis.mp3"},
    {name = "Rádio Melody", url = "https://stream.bauermedia.sk/melody-hi.mp3"},
    {name = "Radio Melody", url = "https://stream.bauermedia.sk/melody-lo.mp3?aw_0_req.gdpr=false&aw_0_1st.playerid=melody_web_mobile"},
    {name = "Radiox - Mood X", url = "http://158.193.82.41:8000/mood.mp3"},
    {name = "RTVS Litera256", url = "http://live.slovakradio.sk:8000/Litera_256.mp3"},
    {name = "Mars Dance", url = "https://stream-176.zeno.fm/683gf5xrxfeuv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiI2ODNnZjV4cnhmZXV2IiwiaG9zdCI6InN0cmVhbS0xNzYuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IlI0eWpRVURfVFdpcndDNkEtMXpKamciLCJpYXQiOjE3MjQ4MTEzMDgsImV4cCI6MTcyNDgxMTM2OH0.ybmJqGSI91bYaLWH3Ss7QcvkP4dhE9m9RH9QY8veXwA"},
    {name = "RTVS Pyramida256", url = "http://live.slovakradio.sk:8000/Pyramida_128.mp3"},
    {name = "Rádio Rock SV", url = "https://s2.myradiostream.com/:4870/listen.mp3"},
    {name = "Sllobodný Vysielač", url = "http://159.69.219.5:8010//aac"},
    {name = "Rádio Relax International", url = "https://edge04.cdn.bitflip.ee:8888/international?_i=416d8856"},
    {name = "TV Joj 404 P", url = "https://live.cdn.joj.sk/live/andromeda/joj-404.m3u8"},
    {name = "Sro1 Rádio Slovensko 256K", url = "http://live.slovakradio.sk:8000/Slovensko_256.mp3"},
    {name = "TV Plus 404 P", url = "https://live.cdn.joj.sk/live/andromeda/plus-404.m3u8"},
    {name = "Radio Wow", url = "https://radioserver.online:9816/radiowow.mp3"},
    {name = "Sro1 Rádio Slovensko", url = "http://live.slovakradio.sk:8000/Slovensko_128.mp3"},
    {name = "Radio Romper Čechoslovakia", url = "https://15113.live.streamtheworld.com:443/SAM05AAC415.aac"},
    {name = "RÁDIO VLNA 60-70", url = "https://stream.radiovlna.sk/gold-hi.mp3"},
    {name = "Rádio ROCK", url = "https://stream.bauermedia.sk/rock-hi.mp3"},
    {name = "Radio Vega Slovakia", url = "https://stream.sepia.sk:8000/vega128.mp3"},
    {name = "Rádio Vlna Oldies Party", url = "https://stream.radiovlna.sk/party-hi.mp3"},
    {name = "Sro9 Rádio Junior 256K", url = "http://live.slovakradio.sk:8000/Junior_256.mp3"},
    {name = "SLOBODNÝ VYSIELAČ", url = "http://vysielanie.online/radio/8020/SV128.mp3"},
    {name = "Sro5 Rádio Pátria RSI", url = "http://live.slovakradio.sk:8000/Patria_128.mp3"},
    {name = "SKY Rádio", url = "http://stream.skyradio.sk:8000/sky128"},
    {name = "Repete", url = "http://stream.rusyn.fm/rusyny-low.mp3"},
    {name = "Sro9 Rádio Junior", url = "http://live.slovakradio.sk:8000/Junior_128.mp3"},
    {name = "Rusyn FM", url = "https://stream.rusyn.fm/rusyny.mp3"},
    {name = "Rusynfm", url = "http://stream.rusyn.fm/rusyny.mp3"},
    {name = "Top Rádio", url = "https://solid1.streamupsolutions.com/proxy/vhhggmih/stream"},
    {name = "Záhorácke Rádio", url = "http://live.zahorackeradio.sk:8080/zr128.mp3"},
    {name = "Sro2 Rádio Regina Stred", url = "http://icecast.stv.livebox.sk/regina-bb_128.mp3"},
    {name = "TA3", url = "https://n13.stv.livebox.sk/ta3/685d9a141bd846e8facf83bc378da26b/invalidtoken/playlist.m3u8"},
    {name = "TV Wau 404 P", url = "https://live.cdn.joj.sk/live/andromeda/wau-404.m3u8"},
    {name = "Radio Zabava", url = "https://stream-164.zeno.fm/eyac00cx1nhvv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJleWFjMDBjeDFuaHZ2IiwiaG9zdCI6InN0cmVhbS0xNjQuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6Il9MdmUySlhoUjR1QzM2ZUkxX2p2ZlEiLCJpYXQiOjE3MjQ4NTAzODYsImV4cCI6MTcyNDg1MDQ0Nn0.hd9SoD5xxwoln1QBpXvASQGOo08ucuZDO7r0kTiKbPE"},
    {name = "TV Doktor", url = "https://live.tvdoktor.sk/high/index.m3u8"},
    {name = "SUB:FM", url = "http://stream.subfm.sk/subfm"},
    {name = "Radio VIVA", url = "https://stream.sepia.sk/viva128.mp3"},
    {name = "Sro2 Rádio Regina Východ", url = "http://icecast.stv.livebox.sk/regina-ke_128.mp3"},
    {name = "Sro3: Rádio Devín", url = "http://icecast.stv.livebox.sk/devin_128.mp3"},
    {name = "Sro6 Radio Slovakia International", url = "http://icecast.stv.livebox.sk/rsi_128.mp3"},
    {name = "Sro8 Rádio Litera", url = "http://icecast.stv.livebox.sk/litera_128.mp3"},
    {name = "TRNAVSKÉ RÁDIO", url = "https://solid33.streamupsolutions.com/proxy/mujdmamw/trnavske"},
    {name = "Sro2 Rádio Regina Západ", url = "http://icecast.stv.livebox.sk/regina-ba_128.mp3"},
    {name = "Party Mix Radio", url = "http://stream-157.zeno.fm/rw6ckefezs8uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJydzZja2VmZXpzOHV2IiwiaG9zdCI6InN0cmVhbS0xNTcuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IkhvSllQTzk0Ul9hcmhoX0FwYTlCZnciLCJpYXQiOjE3MjQ3OTEyMDQsImV4cCI6MTcyNDc5MTI2NH0.dQNNR_Nx8iN8gGz_7USdxzaa72wCCNhQONtPYAv1Bp0"},
    {name = "House Radio", url = "http://stream-155.zeno.fm/qm8e21gta18uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJxbThlMjFndGExOHV2IiwiaG9zdCI6InN0cmVhbS0xNTUuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6ImMwNkc2N1h6VFh5MUd1YU0wX0xNS0EiLCJpYXQiOjE3MjQ4MjExNDQsImV4cCI6MTcyNDgyMTIwNH0.g_eEDzEi7w9e0VR8ieGWfF7SgzGxl_2ZqddnLDcJixo"},
    {name = "Duflo Radio", url = "http://stream-171.zeno.fm/kxwhyvz2fm0uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJreHdoeXZ6MmZtMHV2IiwiaG9zdCI6InN0cmVhbS0xNzEuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6Ikl2VWZIU1hjVGR5RktXMDR6dktVaFEiLCJpYXQiOjE3MjQ4NDg0NDgsImV4cCI6MTcyNDg0ODUwOH0.2UOg8S57IhW000MafD-0bTF_N7tBc7Pp7CmtfkEsaDU"},
    {name = "Kosice International ATC", url = "http://s1-bos.liveatc.net:80/lzkz?nocache=2024082807134595334"},
}

return stations