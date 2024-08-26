local stations = {
    {name = "RADIO MARIAM ARABIC", url = "http://dreamsiteradiocp4.com:8046/stream"},
    {name = "Afgan Fm", url = "https://canli.arabeskinmerkezi.com/9180/stream"},
    {name = "0-24 2000ER POP ROCK", url = "https://0-242000erpoprock.stream.laut.fm/0-24_2000er_pop_rock"},
    {name = "1337", url = "https://la1337.com/stream/la1337.mp3?sid="},
    {name = "80S Alive", url = "http://media2.hostin.cc/80s-alive.mp3"},
    {name = "80S Flashback", url = "http://stream3.radio.is:443/80flashback"},
    {name = "80S Forever Radio", url = "http://premium.shoutcastsolutions.com:8050/256.mp3"},
    {name = "90 Rak Thai", url = "http://radio11.plathong.net:8896/"},
    {name = "Abc", url = "https://nl1.streamhosting.ch/lounge64.aac"},
    {name = "Al Jazeera", url = "http://live-hls-audio-web-aja.getaj.net/VOICE-AJA/01.m3u8"},
    {name = "Ambient Space", url = "http://immortalharmony.out.airtime.pro:8000/immortalharmony_a"},
    {name = "Ariana News TV", url = "http://d10rltuy0iweup.cloudfront.net/ATNNEWS/myStream/playlist.m3u8"},
    {name = "Asds", url = "http://streaming.radiosenlinea.com.ar:8626/"},
    {name = "Asiafm", url = "https://live.ximalaya.com/radio-first-page-app/live/999/64.m3u8?transcode=ts"},
    {name = "BBC UNHCR", url = "http://stream.live.vc.bbcmedia.co.uk/bbc_pashto_radio"},
    {name = "BEAUTIFUL INSTRUMENTALS", url = "http://hydra.cdnstream.com/1822_128"},
    {name = "Bhakti World", url = "http://gurbani.out.airtime.pro:8000/gurbani_a"},
    {name = "BIAS Radio Flac", url = "https://admin.biasradio.com/radio/8000/flac"},
    {name = "Blues Radio Greece", url = "http://cast3.radiohost.ovh:8352/"},
    {name = "BNR Horizont", url = "http://stream.bnr.bg:8011/horizont.aac"},
    {name = "Br Klassik", url = "https://d121.rndfnk.com/ard/br/brklassik/live/mp3/256/stream.mp3?cid=01FBPVP3KY4W2XZ9KV8N032855&sid=2lCxm36nKo7VfZgloxtDpIdr0gK&token=3Xb_luT_FJsiB3W3m8bbxCNYTdN_nEbimJZ2DtPDR9U&tvf=4oe-21lv7xdkMTIxLnJuZGZuay5jb20"},
    {name = "Burj", url = "http://82.213.26.67:8000/stfeam"},
    {name = "Cartuja Radio", url = "http://stream-171.zeno.fm/qernw9vu91zuv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJxZXJudzl2dTkxenV2IiwiaG9zdCI6InN0cmVhbS0xNzEuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IlpTdEMyZHhWU1JPU0l4dVAwa3NSenciLCJpYXQiOjE3MjQ3MDQ3OTUsImV4cCI6MTcyNDcwNDg1NX0.qu_HmLcovToaPku5ftQZW77zqWwKknPxW1OwtJbVbDM"},
    {name = "Chain3", url = "https://webradio.tda.dz/Chaine3_64K.mp3"},
    {name = "Chalabi", url = "https://listen.radioking.com/radio/291025/stream/337294"},
    {name = "Classic Country", url = "http://185.33.21.112/ccountry_mobile_mp3"},
    {name = "Cnn", url = "https://unlimited2-ar.dps.live/cnn-ar/aac/icecast.audio"},
    {name = "Coast FM", url = "http://213.175.217.198:8000/tenerife"},
    {name = "Cool93", url = "https://coolism-web3rd.cdn.byteark.com/;stream/1"},
    {name = "Cosmo Hi", url = "https://f121.rndfnk.com/ard/wdr/cosmo/live/mp3/128/stream.mp3?cid=01FC1T8CET1M6TA2P4PQ2YA5NC&sid=2lC3ILJRvrVu45oIBtOsaU0CZTd&token=9Fv-dOs1KgudtcVKVZkfCwX0vac1GngUlcwldNxd6EU&tvf=8w3sPQJW7xdmMTIxLnJuZGZuay5jb20"},
    {name = "Demem", url = "https://player.web.tr/listen/b9b96f7c7d6d6a484e13c494d7221ade"},
    {name = "Deutschrap Detmold", url = "http://deutschrapradio.stream.laut.fm/deutschrapradio?t302=2024-08-26_10-11-54&uuid=93b4d00c-cc10-4fa1-af94-6fd90a500be5"},
    {name = "Deutschrap TRAP", url = "http://deutscherrap.stream.laut.fm/deutscherrap?t302=2024-08-26_11-22-01&uuid=3d24a00b-ad40-43c2-a041-cafea36e57cf"},
    {name = "Djdjdhs", url = "http://ohmi-design.com:8170/;"},
    {name = "Esradio", url = "https://libertaddigital-radio-live1.flumotion.com/libertaddigital/ld-live1-med.aac?listenerid=0c6b1192515b0c9e2f0697d3ecbf43c6&awparams=companionAds%3Atrue&aw_0_1st.version=1.1.7%3Ahtml5&aw_0_1st.playerid=jPlayer%202.9.2&aw_0_1st.skey=1601646790"},
    {name = "ESTUDIO FM INFANTIL", url = "http://stream-176.zeno.fm/7wdxbx1eqm0uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiI3d2R4YngxZXFtMHV2IiwiaG9zdCI6InN0cmVhbS0xNzYuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IkFUa3p0c3ZSU1RPRFcwN2tlN3B1WVEiLCJpYXQiOjE3MjQ2NjM2MDQsImV4cCI6MTcyNDY2MzY2NH0.CBf_W2gypHNbkVi9HTeHQfpRseii_agcjKfW20pmBa4"},
    {name = "Fb N", url = "http://icecast.radiofrance.fr/fbhautenormandie-midfi.mp3"},
    {name = "Flac", url = "http://stream.radioparadise.com/mellow-flac"},
    {name = "Fm", url = "http://stm11.streaming.profesional.bo:11300/Fb"},
    {name = "Focus", url = "http://ice.greekstream.net/focusfm?listenerid=ec33c4dfc99a6f71e6dc23583cbc91f2&awparams=companionAds:true"},
    {name = "Forst PSY", url = "https://fr1-play.adtonos.com/8103/psystation-forest-psy-trance"},
    {name = "GAYFM", url = "http://streaming.silvacast.com/GAYFM.mp3"},
    {name = "Gradio", url = "http://gradio-rap.stream.laut.fm/gradio-rap?t302=2024-08-26_09-13-15&uuid=d9240077-5784-4392-994b-9e527638f6d7"},
    {name = "Hhh", url = "https://stream-161.zeno.fm/60pqgs97f2zuv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiI2MHBxZ3M5N2YyenV2IiwiaG9zdCI6InN0cmVhbS0xNjEuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6ImNQOEs1QkI5VEtXaV9NVGtQYXp6UEEiLCJpYXQiOjE3MjQ2OTQyOTIsImV4cCI6MTcyNDY5NDM1Mn0.CL7n_ICmSkgJzIFhy6eXlPc5EMKQU7hZy9md_ERv3gg"},
    {name = "Hirschmilch Psytrance", url = "https://hirschmilch.de:7001/psytrance.mp3"},
    {name = "I24News", url = "https://bcovlive-a.akamaihd.net/773a2fa387914315ad11e6957cd54f6e/eu-central-1/5377161796001/playlist-all_dvr.m3u8?__nn__=5476555825001&hdnea=st=1653426000~exp=1653429600~acl=/773a2fa387914315ad11e6957cd54f6e/eu-central-1/5377161796001/*~hmac=aebdde505863d04e63be665d204f2b1faa531f95af73edbaa0f7a29c1f04f8f3"},
    {name = "I24News", url = "https://bcovlive-a.akamaihd.net/773a2fa387914315ad11e6957cd54f6e/eu-central-1/5377161796001/playlist-all_dvr.m3u8?__nn__=5476555825001&hdnea=st=1653426000~exp=1653429600~acl=/773a2fa387914315ad11e6957cd54f6e/eu-central-1/5377161796001/*~hmac=aebdde505863d04e63be665d204f2b1faa531f95af73edbaa0f7a29c1f04f8f3"},
    {name = "I24News", url = "https://bcovlive-a.akamaihd.net/773a2fa387914315ad11e6957cd54f6e/eu-central-1/5377161796001/playlist-all_dvr.m3u8?__nn__=5476555825001&hdnea=st=1653426000~exp=1653429600~acl=/773a2fa387914315ad11e6957cd54f6e/eu-central-1/5377161796001/*~hmac=aebdde505863d04e63be665d204f2b1faa531f95af73edbaa0f7a29c1f04f8f3"},
    {name = "Ig", url = "http://play.igradio.net:8000/;"},
    {name = "Igradiodsn", url = "http://play.igradio.net:8000/;"},
    {name = "Indieparty By Greensleeves", url = "http://indieparty.stream.laut.fm/indieparty?t302=2024-08-26_08-29-27&uuid=c2266e72-4a35-4110-afe1-cf9992be2cc6"},
    {name = "Jeff", url = "http://web.archive.org/web/20201128202306if_/https://live-cdn.pbskids.org/out/u/est.m3u8"},
    {name = "Jjj", url = "https://listen.moe/fallback"},
    {name = "Joy", url = "http://stream.joyhits.online:8070/joyhits.mp3"},
    {name = "K", url = "http://stream-154.zeno.fm/9e880vgncd0uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiI5ZTg4MHZnbmNkMHV2IiwiaG9zdCI6InN0cmVhbS0xNTQuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6InZrb1g2MlItVEl5bS1pZlF5el9yR1EiLCJpYXQiOjE3MjQ2OTQyMzEsImV4cCI6MTcyNDY5NDI5MX0.hmLYyG9shdnH95Dy4QqXnqsOvFeserzsRjFi3AwahB8"},
    {name = "KDPI", url = "https://peridot.streamguys1.com:5115/live"},
    {name = "KISS FM", url = "https://bbkissfm.kissfmradio.cires21.com/bbkissfm.mp3?wmsAuthSign=c2VydmVyX3RpbWU9MDgvMjYvMjAyNCAwNTozNTo1NCBQTSZoYXNoX3ZhbHVlPTQ4VHVHVlJrd0gxU0tyNE01RU1sYkE9PSZ2YWxpZG1pbnV0ZXM9MTQ0MCZpZD0zNDA5NTk4NTI="},
    {name = "KQED", url = "http://streams.kqed.org/kqedradio.m3u"},
    {name = "Louange Radio", url = "https://radio13.pro-fhi.net:19079/"},
    {name = "Megastar FM", url = "http://megastar-cope-rrcast.flumotion.com/cope/megastar.mp3"},
    {name = "Melody Radio Telugu", url = "https://a1.asurahosting.com:9580/radio.mp3"},
    {name = "Meloradio", url = "https://ml02.cdn.eurozet.pl/mel-net.mp3?redirected=02"},
    {name = "Michael Jackson Music Star", url = "https://icy.unitedradio.it/um2908.mp3"},
    {name = "MOMENTO LOVE GOSPEL", url = "http://stream-153.zeno.fm/526wmr2en98uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiI1MjZ3bXIyZW45OHV2IiwiaG9zdCI6InN0cmVhbS0xNTMuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IlY3bUJ1Nl9vUzUtMFhkNHJaRnJNbGciLCJpYXQiOjE3MjQ2NjA1MjksImV4cCI6MTcyNDY2MDU4OX0.JNVxmbYbiwfUTaNd_3hYrTGYeDVaDc8iLmTFPGdZahI"},
    {name = "Mujhe", url = "http://web.archive.org/web/20201128211515if_/https://adultswim-vodlive.cdn.turner.com/live/squidbillies/stream_7.m3u8"},
    {name = "Nair", url = "http://198.245.61.123:8000/nair"},
    {name = "Ndr Info", url = "http://d121.rndfnk.com/ard/ndr/ndrinfo/hamburg/aac/64/ct/stream.aac?cid=01FBQ2FR04JVDRRM969ZTAMZNK&sid=2lCp8VRdA0EYhCVFn5dYNCQ3tyG&token=NKpQ9axQY8zmNBvxWaLKtezCoosg89-4cdP-YyvO8vA&tvf=vmZU6Hlr7xdkMTIxLnJuZGZuay5jb20"},
    {name = "NDR Info AAC", url = "http://f111.rndfnk.com/ard/ndr/ndrinfo/niedersachsen/aac/64/stream.aac?cid=01FBRKHKTB73QDVNX7A9RT082R&sid=2lB8olV8zasHIrmQHoOvFr1VX4G&token=lh7a01EH9r9IFzpBEjbB6_lgQdONguhAiRel8k48Zdo&tvf=wq7lpKo87xdmMTExLnJuZGZuay5jb20"},
    {name = "Nova Bordeaux", url = "https://snb.ice.infomaniak.ch/snb-high.mp3"},
    {name = "Nova Classics", url = "https://nova-vnt.ice.infomaniak.ch/nova-vnt-128"},
    {name = "Nova La Nuit", url = "https://nova-ln.ice.infomaniak.ch/nova-ln-128"},
    {name = "O", url = "https://regiocast.streamabc.net/regc-80s80smweb2517500-mp3-192-1672667?sABC=653op5q6%230%235p58nn084q38sp434n9907261qno32q0%23gharva&aw_0_1st.playerid=tunein&amsparams=playerid:tunein;skey:1698416086"},
    {name = "Ofm Stasie2", url = "https://edge.iono.fm/xice/47_high.aac"},
    {name = "Old Radio", url = "https://sounder.ovh:9270/autodj?fbclid=IwAR1AVMAcgkeg3bTIGM8Z1B7MQ5lr3Fagu8pbx5Hcp9DwPFHllsyI8IlA8Is"},
    {name = "P", url = "https://sonic.onlineaudience.co.uk/8114/stream?listening-from-radio-garden=1657427657"},
    {name = "Paradise", url = "http://stream-uk1.radioparadise.com/aac-32"},
    {name = "Qamişlo", url = "http://dengeqamishlo.stream.laut.fm/dengeqamishlo?pl=m3u&t302=2024-08-26_15-00-25&uuid=cc44b763-e797-426b-a897-cd1a9b57f0d9"},
    {name = "Querétaro Rock Radio Estación", url = "http://stream-162.zeno.fm/xmhshz1wyrquv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJ4bWhzaHoxd3lycXV2IiwiaG9zdCI6InN0cmVhbS0xNjIuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6ImZ4MHBWZ2ZlUldLYXZ0NjNtYUxZOXciLCJpYXQiOjE3MjQ2OTY0NDMsImV4cCI6MTcyNDY5NjUwM30.LEy5IrLVw2SWPeH3_8JVpAj-qhyvu4GgQphbzSVxDaI"},
    {name = "RAD", url = "http://213.141.131.10:8002/jazzmetal"},
    {name = "Radio Activa", url = "https://stream9.mexiserver.com:7014/"},
    {name = "Radio Bandeirantes Goiania", url = "http://suaradio2.dyndns.ws:13633/stream"},
    {name = "Radio City", url = "http://190.52.32.13:1935/radiocity/live_1/chunklist_w289002165.m3u8"},
    {name = "Radio Koszalin", url = "http://91.232.4.33:9680/stream"},
    {name = "Radio Lola Love", url = "https://streaming.radiojat.rs/love.mp3"},
    {name = "Radio Mundo", url = "http://stream.radiomundo.uy:8000/2.mp4"},
    {name = "RADIO NORA OLDIES", url = "https://nora.streamabc.net/regc-noraoldie-mp3-192-4426850?sABC=66pp8r76%231%2305rr3oqro60pr97o7o5n8q8261306o0o%23ubzrcntr&mode=preroll&aw_0_req.gdpr=true&aw_0_1st.kuid=vhyh95oqv&aw_0_1st.ksg=[\"tsrazhtr3\",\"tow60dxfp\",\"s7lqc5jxe\",\"upxsvbudn\",\"uphudti45\",\"tz4swml9u\",\"s697d7eir\",\"s7ljhri17\",\"s7lo2do21\",\"s7lqvksor\",\"s7ltd00sq\",\"s7lul8vls\",\"s7lvpn712\",\"s7lwsqck7\",\"s78nn0wkd\",\"s71hrmzou\",\"s8cm9eyzj\",\"s8siicaeb\",\"takaaes6u\",\"ti505y9ml\",\"tan9djjrm\",\"ti54veycf\",\"tow80eky2\",\"uchw4pz1v\"]&listenerid=05ee3bdeb60ce97b7b5a8d8261306b0b&awparams=companionAds:true&aw_0_1st.playerid=homepage&amsparams=playerid:homepage;skey:1724681846"},
    {name = "Radio Schizoid", url = "http://94.130.113.214:8000/schizoid"},
    {name = "Radio Tarana", url = "http://peridot.streamguys.com:7150/Tarana.aac"},
    {name = "Radiowelle24", url = "http://rw24.stream.laut.fm/rw24?t302=2024-08-26_08-29-21&uuid=8ddda69e-115c-4e95-89ed-c903910964bc"},
    {name = "Radyo Bozcaada", url = "http://radyobozcaada.canliyayinda.com:4000/stream"},
    {name = "Rememberfm", url = "http://rememberfm.emisionlocal.com:9302/LIVE"},
    {name = "Retró Rádió", url = "https://icast.connectmedia.hu/5001/live.mp3"},
    {name = "Retrofm", url = "http://retroserver.streamr.ru:8043/retro128"},
    {name = "RMI - Euro Didco", url = "https://cast1.torontocast.com:1335/stream"},
    {name = "Rock Classics", url = "http://185.33.21.112/rockclassics_128"},
    {name = "Rockradio", url = "http://radiostream.pl/tuba9006-1.mp3"},
    {name = "Rpw", url = "https://radiostream.pl/tuba140-1.mp3"},
    {name = "Rrr", url = "http://media-ice.radiodns.ru/humour.m3u8"},
    {name = "RTVS", url = "http://icecast.stv.livebox.sk/slovensko_128.mp3"},
    {name = "SBS 파워 FM", url = "https://radiolive.sbs.co.kr/powerpc/powerfm.stream/playlist.m3u8?token=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3MjQ3MjU0MDMsInBhdGgiOiIvcG93ZXJmbS5zdHJlYW0iLCJkdXJhdGlvbiI6LTEsInVubyI6IjRmNDZlMzBkLTg2NmUtNDgwOC1hNzIwLTAzYzA4NzAxODNiOSIsImlhdCI6MTcyNDY4MjIwM30.PDoZ6jhLbsKeH4jgfws3HLHWZY2OmZ5RRWGPyuYHF8I"},
    {name = "SECTOR 80S", url = "http://89.223.45.5:8000/geny-flac"},
    {name = "Selah", url = "https://ice10.securenetsystems.net/KHHKHD3"},
    {name = "Sha3By FM", url = "https://radio95.radioca.st/stream/1/"},
    {name = "Simulator FM", url = "https://simulatorfm.stream:8025/320Kbps"},
    {name = "Solar Radio", url = "https://listen-msmn.sharp-stream.com/solarlow.mp3"},
    {name = "Spogmai Radio", url = "http://ca10.rcast.net:8026/"},
    {name = "Sunnah Radio", url = "http://andromeda.shoutca.st:8189/stream"},
    {name = "Sunshine-Live Fokus", url = "http://sunsl.streamabc.net/sunsl-sunslxzzupaaj5xv63-mp3-128-1516575?sABC=66pp6rs4%230%232qqpnss01895rqr0s8oq129o03s183o0%23fgernz.fhafuvar-yvir.qr&aw_0_1st.playerid=stream.sunshine-live.de&amsparams=playerid:stream.sunshine-live.de;skey:1724673780"},
    {name = "Syaivo", url = "http://stream.ntktv.ua/syaivo.mp3"},
    {name = "Tamil", url = "http://stream-151.zeno.fm/7aswfbpx25quv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiI3YXN3ZmJweDI1cXV2IiwiaG9zdCI6InN0cmVhbS0xNTEuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6InlpVXZMNkpLUXB1bUQxZElrOGxxLXciLCJpYXQiOjE3MjQ2MzA0MTAsImV4cCI6MTcyNDYzMDQ3MH0.VpWiNgYZgsfsRCOvJFleWSIlnW5lzFOc5Y_CNwmzpWQ"},
    {name = "Teleradio Ercolano", url = "https://rst.saiuzwebnetwork.it:19360/teleradioercolano-1/teleradioercolano-1.m3u8"},
    {name = "Test", url = "https://streaming.shoutcast.com/synchronizeradio?"},
    {name = "Twst", url = "https://fr1.streamhosting.ch/lounge64.aac"},
    {name = "Veronika", url = "http://play.global.audio/veronika.aac"},
    {name = "Vesti FM", url = "http://icecast.vgtrk.cdnvideo.ru/vestifm_mp3_128kbps"},
    {name = "Vocaloid", url = "https://vocaloid.radioca.st/stream"},
    {name = "Авторадио ВЛ", url = "http://vladfm.ru:8000/ara"},
    {name = "Монте Карло ВЛ", url = "http://194.58.122.69:8000/mcvl"},
    {name = "Радио Дача", url = "http://194.58.122.69:8000/vdacha"},
    {name = "Радио России", url = "http://mp3.ptr-vlad.ru:8000/Radio96"},
    {name = "Радіоточка", url = "https://radio.ukr.radio/ur5-mp3"},
    {name = "Романтика", url = "http://media-ice.radiodns.ru/romantika.m3u8"},
    {name = "РУКИ ВВЕРХ", url = "https://ic6.101.ru:8000/stream/pro/aac/64/163"},
    {name = "Русское Радио ВЛ", url = "http://194.58.122.69:8000/rrvl"},
    {name = "גל עברי", url = "http://glzwizzlv.bynetcdn.com/glglz_classicil_mp3?awCollectionId=misc&awEpisodeId=glglz_classicil"},
    {name = "גלגלצ להיטים חמים", url = "http://glzwizzlv.bynetcdn.com/glglz_hits_mp3?awCollectionId=misc&awEpisodeId=glglz_hits"},
    {name = "רשת ג", url = "https://25493.live.streamtheworld.com:443/KAN_GIMMEL.mp3?dist=bynetredirect"},
    {name = "إذاعة القرآن الكريم", url = "http://n0f.radiojar.com/0tpy1h0kxtzuv?rj-ttl=5&rj-tok=AAABkY-37M8A8ZMjEzDedm_QAQ"},
    {name = "إذاعة طريق السلف", url = "https://airtime.salafwayfm.ly/"},
    {name = "اذاعة القرآن الكريم", url = "http://n12.radiojar.com/0tpy1h0kxtzuv?rj-ttl=5&rj-tok=AAABkZB0qyMAHnQvfWSCjQrPkg"},
    {name = "مختصر التفسير", url = "https://qurango.net/radio/mukhtasartafsir"},
    {name = "مرايا", url = "https://shls-live-ak.akamaized.net/out/v1/a4a39d8e92e34b0780ca602270a59512/index_8.m3u8"},
    {name = "国乐悠扬", url = "http://stream3.hndt.com/now/8bplFuwp/playlist.m3u8"},
    {name = "月南之音", url = "https://stream.vovmedia.vn/vov5"},
    {name = "香港电台第一台", url = "https://rthkradio1-live.akamaized.net/hls/live/2035313/radio1/master.m3u8"},
}

return stations