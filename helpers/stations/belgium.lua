local stations = {
    {name = "Studio Brussel", url = "http://icecast.vrtcdn.be/stubru-high.mp3"},
    {name = "Qmusic Belgium", url = "https://icecast-qmusicbe-cdp.triple-it.nl/qmusic.aac"},
    {name = "RTBF La Première", url = "https://radios.rtbf.be/laprem1ere-64.aac"},
    {name = "Radio 1", url = "http://icecast.vrtcdn.be/radio1-high.mp3"},
    {name = "MNM", url = "http://icecast.vrtcdn.be/mnm-high.mp3"},
    {name = "Classic21", url = "http://radios.rtbf.be/classic21-128.mp3"},
    {name = "Tomorrowland One World Radio", url = "https://playerservices.streamtheworld.com/api/livestream-redirect/OWR_INTERNATIONAL_ADP.aac"},
    {name = "Nostalgie - What A Feeling", url = "https://22673.live.streamtheworld.com/NOSTALGIEWHATAFEELING.mp3"},
    {name = "JOE", url = "https://icecast-qmusicbe-cdp.triple-it.nl/joe.mp3"},
    {name = "Classic 21 80'S New Wave", url = "https://radio.rtbf.be/c21-80nw/mp3-128/me"},
    {name = "Klara Continuo", url = "http://icecast.vrtcdn.be/klaracontinuo-high.mp3"},
    {name = "Topradio Belgium", url = "http://str.topradio.be/topradio.mp3"},
    {name = "Joe 80'S 90'S", url = "https://icecast-qmusicbe-cdp.triple-it.nl/joe_80s_90s.mp3"},
    {name = "RTBF Vivacité Bruxelles", url = "https://radios.rtbf.be/vivabxl-64.aac"},
    {name = "MNM Big Hits", url = "http://icecast.vrtcdn.be/mnm_hits-high.mp3"},
    {name = "Instrumentals Forever", url = "http://quincy.torontocast.com:1910/stream"},
    {name = "Willy", url = "https://icecast-qmusicbe-cdp.triple-it.nl/willy.mp3"},
    {name = "Klara", url = "http://icecast.vrtcdn.be/klara-high.mp3"},
    {name = "Studio Brussel - De Tijdloze", url = "http://icecast.vrtcdn.be/stubru_tijdloze-high.mp3"},
    {name = "Easyradio Flac", url = "https://easyradio.bg/m3u/easyradio.bg-flac.m3u"},
    {name = "Stubru", url = "http://icecast.vrtcdn.be/stubru.aac"},
    {name = "Bel RTL", url = "http://belrtl.ice.infomaniak.ch/belrtl-mp3-192.mp3"},
    {name = "VRT NWS", url = "http://progressive-audio.vrtcdn.be/content/fixed/11_11niws-snip_hi.mp3"},
    {name = "RTBF Classic 21", url = "https://radios.rtbf.be/classic21-128.mp3"},
    {name = "Tommorowland One World Radio - Daybreak Sessions", url = "https://playerservices.streamtheworld.com/api/livestream-redirect/OWR_DAYBREAK_ADP.aac"},
    {name = "Joe 60'S 70'S", url = "https://icecast-qmusicbe-cdp.triple-it.nl/joe_60s_70s.mp3"},
    {name = "Mynoise Rainy Day", url = "http://rainyday.radio.mynoise.net/"},
    {name = "Joe FM", url = "https://25593.live.streamtheworld.com/JOE.mp3"},
    {name = "Mynoise Ocean Waves", url = "http://oceanwaves.radio.mynoise.net/"},
    {name = "La Première - Bruxelles", url = "http://radios.rtbf.be/laprem1erebxl-128.mp3"},
    {name = "Nostalgie+", url = "https://22673.live.streamtheworld.com/NOSTALGIEWAF6070.mp3"},
    {name = "Q-Foute Radio", url = "https://streams.radio.dpgmedia.cloud/redirect/foute_radio_be/mp3"},
    {name = "VRT Radio 1 Aac", url = "http://icecast.vrtcdn.be/radio1.aac"},
    {name = "Radio 2 Limburg", url = "http://icecast.vrtcdn.be/ra2lim-high.mp3"},
    {name = "Nostalgie Vlaanderen", url = "https://playerservices.streamtheworld.com/api/livestream-redirect/NOSTALGIEWHATAFEELING.mp3?dist=radiobrowser"},
    {name = "VRT Radio 2 West-Vlaanderen", url = "http://icecast.vrtcdn.be/ra2wvl-high.mp3"},
    {name = "Instrumentals Forever 64Kbp", url = "http://quincy.torontocast.com:1920/stream"},
    {name = "Radio 2 Oost-Vlaanderen", url = "http://icecast.vrtcdn.be/ra2ovl-high.mp3"},
    {name = "Bruce Classic Rock", url = "http://streamingv2.shoutcast.com/bruce-classic-rock"},
    {name = "Nostalgie 80'S", url = "https://playerservices.streamtheworld.com/api/livestream-redirect/NOSTALGIEWAF80.mp3"},
    {name = "RTBF Vivacité Liège", url = "https://radios.rtbf.be/vivaliege-64.aac"},
    {name = "Mynoise Pure Nature", url = "https://purenature-mynoise.radioca.st/stream"},
    {name = "Radio 2 Antwerpen", url = "http://icecast.vrtcdn.be/ra2ant-high.mp3"},
    {name = "Mynoise Zen Garden", url = "http://zengarden.radio.mynoise.net/"},
    {name = "'T Is Vloms", url = "https://bluford.torontocast.com/proxy/iimfoptl/stream"},
    {name = "Chillout CROOZE", url = "http://streams.crooze.fm:8006/stream/1/"},
    {name = "Tomorrowland Anthems", url = "https://22673.live.streamtheworld.com/OWR_DAB.mp3"},
    {name = "Classic 21 Blues", url = "http://radios.rtbf.be/wr-c21-blues-128.mp3"},
    {name = "Mynoise Space Odyssey", url = "http://spaceodyssey-mynoise.radioca.st/stream"},
    {name = "RTBF Tarmac", url = "https://radios.rtbf.be/tarmac-128.mp3"},
    {name = "VRT Radio 2 Antwerpen - AAC", url = "http://icecast.vrtcdn.be/ra2ant.aac"},
    {name = "Radio Contact", url = "http://radiocontact.ice.infomaniak.ch/radiocontact-mp3-192.mp3"},
    {name = "Kiosk Radio", url = "https://kioskradiobxl.out.airtime.pro/kioskradiobxl_b"},
    {name = "Top Radio Retro", url = "https://str.topradio.be/topradioretroarena.mp3"},
    {name = "RTBF Musiq3", url = "https://radios.rtbf.be/musiq3-128.aac"},
    {name = "Joe Easy", url = "https://streams.radio.dpgmedia.cloud/redirect/joe_easy/mp3"},
    {name = "RTBF Classic 21 - 60'S", url = "https://radios.rtbf.be/wr-c21-60-128.mp3"},
    {name = "Nostalgie Extra New Wave", url = "https://playerservices.streamtheworld.com/api/livestream-redirect/NOSTALGIEWAFNEWWAVE.mp3"},
    {name = "VRT Radio 1 Classics", url = "http://icecast.vrtcdn.be/radio1_classics-high.mp3"},
    {name = "Radio Campus BXL 921 [AAC+]", url = "https://www.radiocampus.be/stream/stream.aacplus.m3u"},
    {name = "Stubru De Tijdlooze", url = "http://vrt.streamabc.net/vrt-stubrutijdloze-mp3-128-1875746?sABC=6604s101%230%232qqpnss01895rqr0s8oq129o03s183o0%23&aw_0_1st.playerid=&amsparams=playerid:;skey:1711599873"},
    {name = "The Funky Channel", url = "http://cast3.my-control-panel.com:8170/stream"},
    {name = "Topradio Toptechno", url = "https://22733.live.streamtheworld.com/TOPSPINNINGAAC.aac"},
    {name = "Tipik", url = "https://radios.rtbf.be/pure-128.mp3"},
    {name = "RTBF Viva+", url = "https://radios.rtbf.be/vivaplus-128.mp3"},
    {name = "100% Retro", url = "https://server.musicstars.online/radio/8000/listen"},
    {name = "VRT Radio 2 Bene Bene", url = "http://icecast.vrtcdn.be/radio2_benebene-high.mp3"},
    {name = "La Classica", url = "http://stream.laclassica.be:8023/stream"},
    {name = "Joe - All The Way", url = "https://playerservices.streamtheworld.com/api/livestream-redirect/JOE.mp3"},
    {name = "RTBF Classic 21 - 70'S", url = "https://radios.rtbf.be/wr-c21-70-128.mp3"},
    {name = "Zenfm", url = "http://str.topradio.be/zenfm.mp3"},
    {name = "Topradio Topretroarena", url = "https://playerservices.streamtheworld.com/api/livestream-redirect/TOPRETROAAC.aac"},
    {name = "NRJ België", url = "https://playerservices.streamtheworld.com/api/livestream-redirect/NRJBELGIE.mp3?dist=radiobrowser"},
    {name = "One World Radio - Tomorrowland", url = "http://playerservices.streamtheworld.com/api/livestream-redirect/OWR_INTERNATIONAL_ADP.aac"},
    {name = "Classic 21 Metal", url = "http://radio.rtbf.be/c21-metal/aac-128/fl"},
    {name = "Fun Radio", url = "http://statslive.infomaniak.ch/playlist/funradiobe/funradiobe-high.mp3/playlist.pls"},
    {name = "Instrumental Radio, Be", url = "http://streams.shoutcastsolutions.com:8599/stream"},
    {name = "RTBF Pure FM", url = "https://radios.rtbf.be/pure-64.aac"},
    {name = "Stubru The Greatest Switch", url = "http://icecast.vrtcdn.be/stubru_tgs-high.mp3"},
    {name = "Gothville Radio", url = "https://gothville.radio/radio/8000/stream"},
    {name = "MNM 90'S 00'S", url = "http://icecast.vrtcdn.be/mnm_90s00s-high.mp3"},
    {name = "Mynoise Siren Songs", url = "http://sirensongs-mynoise.radioca.st/stream"},
    {name = "Radio Minerva", url = "http://streaming.radiominerva.be/minerva"},
    {name = "Musiq3 Baroque", url = "https://radios.rtbf.be/wr-m3-baroque-128.mp3"},
    {name = "Radio 2 Vlaams-Brabant", url = "http://icecast.vrtcdn.be/ra2vlb-high.mp3"},
    {name = "Psylo Garden Studio - Techno Trance Classic Compilations", url = "http://psylo.ddns.net:8000/PGS1"},
    {name = "Topradio We Love Music", url = "https://25703.live.streamtheworld.com/TOP_RADIOAAC.aac"},
    {name = "RTBF Classic 21 - Live", url = "https://radios.rtbf.be/wr-c21-live-128.mp3"},
    {name = "RTBF Classic 21 - Underground", url = "https://radios.rtbf.be/wr-c21-underground-128.mp3"},
    {name = "Mynoise Drone Zone", url = "http://dronezone-mynoise.radioca.st/stream"},
    {name = "Willy Class X", url = "https://icecast-qmusicbe-cdp.triple-it.nl/willy-class-x.aac"},
    {name = "VRT Radio 2 Vlaams-Brabant", url = "http://icecast.vrtcdn.be/ra2vlb.aac"},
    {name = "8090Rocks", url = "https://radio.8090rocks.com/"},
    {name = "RTBF Classic 21 - 80'S", url = "https://radios.rtbf.be/wr-c21-80-128.mp3"},
    {name = "Cdance", url = "http://198.100.145.187:18304/;"},
    {name = "Radio Plus Gent", url = "http://live.radiostudio.be/plus"},
    {name = "100,5 Das Hitradio", url = "http://stream.dashitradio.de/dashitradio/aac-48/stream.mp3"},
    {name = "Stubru Untz AAC", url = "http://icecast.vrtcdn.be/stubru_untz.aac"},
    {name = "AFN 360 Benelux", url = "http://playerservices.streamtheworld.com/m3u/AFNE_BLX.m3u"},
    {name = "RTBF Classic 21 - Reggae", url = "https://radios.rtbf.be/wr-eventradio-128.mp3"},
    {name = "Classic 21 80’S Hits", url = "https://radio.rtbf.be/c21-80s/mp3-128/me"},
    {name = "BRF1", url = "http://streaming.brf.be/brf1-high.mp3"},
    {name = "Melinda FM", url = "http://stream.decibelhuis.be:8000/1"},
    {name = "Belgian Dance Radio", url = "https://s4.radio.co/sf5a880a25/listen"},
    {name = "RTBF Vivacité Luxembourg", url = "https://radios.rtbf.be/vivalux-64.aac"},
    {name = "VRT Radio 2 Oost-Vlaanderen", url = "http://icecast.vrtcdn.be/ra2ovl.aac"},
    {name = "Tomorrowland - Daybreak Sessions", url = "http://playerservices.streamtheworld.com/api/livestream-redirect/OWR_DAYBREAK_ADP.aac"},
    {name = "Radio Sud", url = "http://streaming.domainepublic.net:8000/radiosud.mp3"},
    {name = "Villa Bota", url = "https://caster04.streampakket.com/proxy/8186/stream"},
    {name = "1 BELGIAN ON DEMAND RADIO", url = "http://bodr.ddns.net:9052/;"},
    {name = "RTBF Jam", url = "https://radios.rtbf.be/jam-128.mp3"},
    {name = "De Goeie Ouwe Tijd", url = "http://samcloud.spacial.com/api/listen?sid=118908&rid=238881&f=mp3,any&br=128000,any&m=m3u&t=ssl"},
    {name = "Radio Centraal", url = "http://streams.movemedia.eu/centraal"},
    {name = "Bruzz", url = "https://rrr.sz.xlcdn.com/?account=fmbrussel&file=fmb988.mp3&type=live&service=icecast&protocol=https&port=8000&output=pls"},
    {name = "RTBF Classic 21 - Route 66", url = "https://radios.rtbf.be/wr-c21-route66-128.mp3"},
    {name = "Psylo Garden Studio - Livesets Mix Sessions", url = "http://psylo.ddns.net:8000/PGS2"},
    {name = "Radio Chrétienne Francophone Belgique", url = "http://rcf.streamakaci.com/rcfbe.mp3"},
    {name = "Radio Air Libre", url = "http://streaming.domainepublic.net:8000/radioairlibre.ogg.m3u"},
    {name = "Joe 80S 90S", url = "https://icecast-qmusicbe-cdp.triple-it.nl/joe_80s_90s.aac?aw_0_1st.skey=1686378273&aw_0_1st.playerid=site-player"},
    {name = "Halloween Radio - Atmosphere", url = "https://www.halloweenradio.net/stream/halloweenradio-atmosphere.m3u"},
    {name = "Orgelradio", url = "http://radio.organroxx.com:8000/freestream.mp3"},
    {name = "RTBF Classic 21 - Soul Power", url = "https://radios.rtbf.be/wr-c21-soul-128.mp3"},
    {name = "Tipik À L'Ancienne RTBF", url = "http://radio.rtbf.be/tipik-al/mp3-128/rb"},
    {name = "Pure FM - 128", url = "http://radios.rtbf.be/pure-128.mp3"},
    {name = "Klara Continuo Aac", url = "http://icecast.vrtcdn.be/klaracontinuo.aac"},
    {name = "RTBF Vivacité Namur Brabant Wallon", url = "https://radios.rtbf.be/vivanamurbw-64.aac"},
    {name = "Topradio Topbam", url = "https://playerservices.streamtheworld.com/api/livestream-redirect/TOPBAM.mp3"},
    {name = "Willy - Aac", url = "https://streams.radio.dpgmedia.cloud/redirect/willy_be/aac"},
    {name = "BRF2 Radio", url = "https://streaming.brf.be/brf2-high.mp3"},
    {name = "RTBF Classic 21 - 90'S", url = "https://radios.rtbf.be/wr-c21-90-128.mp3"},
    {name = "Nostalgie Extra What A Feeling", url = "https://playerservices.streamtheworld.com/api/livestream-redirect/NOSTALGIEWAFEXTRA.mp3"},
    {name = "Ajoin Music", url = "https://play.ajoinmusic.be/ajoinmusic.mp3"},
    {name = "Ketnet Hits", url = "https://icecast.vrtcdn.be/ketnetradio-high.mp3?dist=belgiefm"},
    {name = "Qmusic Q-Allstars", url = "https://icecast-qmusicbe-cdp.triple-it.nl/q-allstars.aac"},
    {name = "Radio Centraal 1067FM", url = "http://streams.movemedia.eu:8530/"},
    {name = "Willy Classix", url = "https://streams.radio.dpgmedia.cloud/redirect/willy_be_class_x/mp3"},
    {name = "Pep'S Radio", url = "https://behofm.ice.infomaniak.ch/behofm.mp3"},
    {name = "Metropole Radio", url = "http://metropoleradio.ice.infomaniak.ch/metropoleradio-192.mp3"},
    {name = "Urgentfm", url = "http://urgentstream.radiostudio.be:8000/live"},
    {name = "Radio Salamandre ASBL", url = "http://radiosalamandre.ice.infomaniak.ch/radiosalamandre.aac"},
    {name = "Radio Bonheur BE", url = "https://france1.coollabel-productions.com/proxy/radiobonheur317/stream"},
    {name = "Joe Lage Landen", url = "https://icecast-qmusicbe-cdp.triple-it.nl/joe_lage_landen.mp3"},
    {name = "Halloween Radio - Main", url = "https://www.halloweenradio.net/stream/halloweenradio-main.m3u"},
    {name = "Arabel", url = "http://arabelfm.ice.infomaniak.ch/arabelprodcastfm.mp3"},
    {name = "PINK", url = "https://www.clubfmserver.be/pink.mp3"},
    {name = "Mint Radio", url = "https://mint.ice.infomaniak.ch/mint-mp3-128.mp3"},
    {name = "Be One - Xmas", url = "http://live.radiostudio.be/beonexmas"},
    {name = "FM Goud Limburg", url = "https://streamingv2.shoutcast.com/fm-goud-noord-limburg"},
    {name = "Radio Emotion Belgique", url = "https://stream1.dgnet.be/1"},
    {name = "Vuurland Vrt", url = "http://icecast.vrtcdn.be/stubru_tgs.aac"},
    {name = "VRT Studio Brussel Untz", url = "http://icecast.vrtcdn.be/stubru_untz-high.mp3"},
    {name = "Klara Aac", url = "http://icecast.vrtcdn.be/klara.aac"},
    {name = "Sud Radio", url = "http://sudradio.ice.infomaniak.ch/sudradio-96.aac"},
    {name = "Topradio Topschaamteloos", url = "https://25503.live.streamtheworld.com/TOPSCHAAMTELOZEAAC.aac"},
    {name = "VRT Radio 2 Unwind", url = "http://icecast.vrtcdn.be/radio2_unwind-high.mp3"},
    {name = "Gold FM", url = "http://www.goldfm.be/live/playlist.php?name=listen.pls"},
    {name = "Radio Folie", url = "https://listen.radioking.com/radio/378724/stream/429523"},
    {name = "RTBF Classic 21 - Metal", url = "https://radios.rtbf.be/wr-c21-metal-128.mp3"},
    {name = "Wradio", url = "http://stream.wradio.es:9000/;stream/1"},
    {name = "RBL", url = "https://radios.rtbf.be/laprem1ere-128.mp3"},
    {name = "Radio Reflex", url = "http://shoutcast2.wirelessbelgie.be:8510/"},
    {name = "1 MINI 1", url = "http://centauri.shoutca.st:9021/;"},
    {name = "Zen Garden Mynoise Radio", url = "https://zengarden-mynoise.radioca.st/stream"},
    {name = "Versuz", url = "http://27993.live.streamtheworld.com/TOPVERSUZ.mp3"},
    {name = "Islam En Français", url = "http://104.7.66.64:8099/stream/1/"},
    {name = "TSF Radio Allround", url = "http://ec5.yesstreaming.net:3430/stream"},
    {name = "Radio Stars 985 FM DAB+ Belgium", url = "http://stream.radiostars.be:9850/RadioStars.mka"},
    {name = "Impact FM", url = "http://statslive.infomaniak.ch/playlist/impactfm/impactfm-64.aac/playlist.pls"},
    {name = "Radio Tequila", url = "http://s43.myradiostream.com:20542/listen.mp3"},
    {name = "Radio Judaïca", url = "http://radiojudaica.ice.infomaniak.ch/radiojudaica-128.mp3?_=1"},
    {name = "Radio Magic Europ", url = "http://s4.yesstreaming.net:7162/stream"},
    {name = "Kix", url = "https://www.radiokix.be/interactive/livestream_kix_aac.m3u"},
    {name = "Radio 19", url = "http://audiostream.radio19.fm:8200/;"},
    {name = "YOLO - Life Is Like A Dance", url = "https://streamingv2.shoutcast.com/yolo-life-is-like-a-dance"},
    {name = "Jamendo Lounge", url = "http://streamingp.shoutcast.com/JamendoLounge"},
    {name = "Slow Radio", url = "https://streams.slowradio.com/slowradio192.m3u"},
    {name = "Joe 60S 70S", url = "https://icecast-qmusicbe-cdp.triple-it.nl/joe_60s_70s.aac?aw_0_1st.skey=1686378120&aw_0_1st.playerid=site-player"},
    {name = "Fiësta Radio", url = "https://media1.hostin.cc/fiestaradio.mp3"},
    {name = "Roxx", url = "http://www.clubfmserver.be:8000/roxx.mp3"},
    {name = "Depechemodebe", url = "https://c2.radioboss.fm:8494/stream"},
    {name = "Radio Eagle", url = "https://antares.dribbcast.com:2199/tunein/puurtren.pls"},
    {name = "FM Goud Maasland", url = "https://streamingv2.shoutcast.com/fm-goud-maasland"},
    {name = "10584", url = "http://s1.voscast.com:10584/stream"},
    {name = "Radio 700", url = "https://stream.radio700.eu/radio700-live/mp3-192?ref=radiobrowser"},
    {name = "Accent Radio", url = "https://www.clubfmserver.be/accent.mp3"},
    {name = "BRF2", url = "http://streaming.brf.be/brf2-high.mp3"},
    {name = "Radio Chevaucoir", url = "https://radio10.pro-fhi.net/flux-nqjpklks/stream"},
    {name = "Charleking Radio", url = "http://charlekingradio.ice.infomaniak.ch/ckradio-192.mp3"},
    {name = "Radio Expres Antwerpen", url = "http://www.clubfmserver.be:8000/expres.mp3"},
    {name = "Vlaamse Wonderjaren", url = "https://cast1.torontocast.com:3305/stream"},
    {name = "Q-Allstars", url = "https://streams.radio.dpgmedia.cloud/redirect/qbe_allstars/mp3"},
    {name = "Magic Radio Herentals", url = "http://shoutcast.movemedia.eu/pdgfm"},
    {name = "Radio Valencia", url = "https://cloud-faro.beheerstream.com/proxy/radiovalenciafm?mp=/stream"},
    {name = "Up Radio", url = "http://upradio.ovh:8054/up-low"},
    {name = "Studio Brussel Zware Gitaren", url = "https://vrt.streamabc.net/vrt-studiobrusselbruut-mp3-128-7838034"},
    {name = "Frequence Eghezee", url = "http://stream.fr-eghezee.be:8054/FE"},
    {name = "Radyo Gar", url = "https://gargara.net/listen/zana/radio.mp3"},
    {name = "ONIB Radio", url = "https://www.radioking.com/play/galaxieradio-belgium-1/356660"},
    {name = "Rowyna Music", url = "https://server5.radio-streams.net:2199/tunein/rowynamu.pls"},
    {name = "Mélodie FM", url = "http://188.165.35.60:8008/;"},
    {name = "Zoe FM", url = "https://icecast.movemedia.be/zoe128"},
    {name = "Radio 4910", url = "https://radio7.pro-fhi.net:19073/stream.mp3"},
    {name = "Psylo Garden Studio - Lounge", url = "http://psylo.ddns.net:8000/PGS3"},
    {name = "Trendy FM", url = "http://stream.trendyfm.be/"},
    {name = "RGR Classic Hits", url = "https://stream1.rgrfm.be/"},
    {name = "Radio Campus", url = "http://streamer.radiocampus.be/stream.mp3"},
    {name = "Radio1 Lage Landenlijst", url = "http://icecast.vrtcdn.be/radio1_lagelanden-high.mp3"},
    {name = "Scorpio", url = "https://stream.radioscorpio.be/stream"},
    {name = "Clubfm Oost-Vlaanderen", url = "http://www.clubfmserver.be:8000/radioclubfm.mp3"},
    {name = "Radio Mol", url = "http://radiomol.ice.infomaniak.ch/radiomol-192.mp3"},
    {name = "RADIO MARIA BELGIUM", url = "http://dreamsiteradiocp.com:8042/stream"},
    {name = "Radio 100%", url = "http://live2.radiostudio.be:8000/pros"},
    {name = "VRT Studio Brussel - Bruut", url = "http://icecast.vrtcdn.be/stubru_bruut-high.mp3"},
    {name = "La Cible", url = "https://quincy.torontocast.com:3195/stream"},
    {name = "Stadsradio Vlaanderen", url = "http://randstad.wirelessbelgie.be:8330/stream.mp3"},
    {name = "PROS", url = "https://stream4.audiostreamen.nl/radiopros"},
    {name = "BRF1 Radio", url = "https://streaming.brf.be/brf1-high.mp3"},
    {name = "Arabel FM", url = "https://arabelfm.ice.infomaniak.ch/arabelprodcastfm.mp3?1707017559"},
    {name = "Radio Maria", url = "http://stream.radiomaria.be/RadioMaria-96.pls"},
    {name = "Elisa FM, Brugge, Be", url = "http://stream.vbro.be:9200/ElisaFM"},
    {name = "Radio Equinoxe", url = "http://live.equinoxenamur.be:8000/Equinoxe.mp3"},
    {name = "Radio Quartz", url = "http://manager2.streaming-ingenierie.fr:8026/;stream.mp3"},
    {name = "Geel Fm", url = "http://geelfm.nsupdate.info:8080/geelfm.mp3"},
    {name = "RCF Liège", url = "http://rcf.streamakaci.com/rcfliege.mp3"},
    {name = "RCF Sud Belgique", url = "http://rcf.streamakaci.com/rcfsudbe.mp3"},
    {name = "Radio Bahena - Baarle-Hertog, Be", url = "http://stream.bahena.be:8000/bahena.mp3"},
    {name = "Radio AKTIEF", url = "http://www.clubfmserver.be:8000/aktief.mp3"},
    {name = "Radio Italia Charleroi", url = "http://str01.fluidstream.net:7170/listen.pls"},
    {name = "Radio Internazionale", url = "http://str01.fluidstream.net/fluid06.mp3"},
    {name = "Radio Qui Chifel", url = "https://stream.rqc.be/listen.pls?sid=1"},
    {name = "Mooi Radio 1066 FM Mechelen,Be", url = "http://mooiradio.live-streams.nl/"},
    {name = "Radio Paloma Poppel,Be", url = "http://ex52.voordeligstreamen.nl/8054/stream"},
    {name = "Radio Beverland, 1061 FM Beveren", url = "http://livestream.beverland.info:8009/Beverland"},
    {name = "Radio Benelux Beringen, Be", url = "http://remote.radiobenelux.be/MP3"},
    {name = "1 MINI 2", url = "http://centauri.shoutca.st:9064/;"},
    {name = "Radio Totaal 1059 FM Kapellen, Be", url = "https://live.radiototaal.be/radiototaal.mp3"},
    {name = "Radio Ariane 1076 FM - Kortessem, Be", url = "http://caster02.streampakket.com:8862/;"},
    {name = "Radio Pallieter", url = "http://s39.myradiostream.com:14494/listen.mp3"},
    {name = "RGR FM 1065Fm Heist Op Den Berg, Be", url = "http://uplink.intronic.nl/rgrfm"},
    {name = "Music Is Love", url = "https://25643.live.streamtheworld.com/POTZ.mp3"},
    {name = "ULTRASON", url = "http://broadcast.infomaniak.ch/ultrason-high.mp3"},
    {name = "MNM Urbanice", url = "http://icecast.vrtcdn.be/mnm_urb-high.mp3"},
    {name = "Radio Music Sambre", url = "http://radiomusicsambre.ice.infomaniak.ch/radiomusicsambre-128.mp3"},
    {name = "Retro Radio Singjaal", url = "http://ice.cr1.streamzilla.xlcdn.com:8000/sz=radiosingjaal=radiostream"},
    {name = "Radio Nova", url = "https://nova.dzradio.nl/nova"},
    {name = "Radio Gompel 105,6 FM , Mol, Be", url = "http://caster05.streampakket.com:8916/stream.mp3"},
    {name = "Clubfm", url = "http://www.clubfmserver.be:8000/clubfm.mp3"},
    {name = "Radio TRL", url = "http://stream.radiotrl.be:8000/RadioTRL"},
    {name = "Gaveromroep", url = "http://s43.myradiostream.com:18192/"},
    {name = "Family Radio Belgiëbelgiquebelgien", url = "http://www.clubfmserver.be:8000/family.mp3"},
    {name = "VRT Radio 1 Low", url = "http://icecast.vrtcdn.be/radio1-mid.mp3"},
    {name = "Studio Brussel Low", url = "http://icecast.vrtcdn.be/stubru-mid.mp3"},
    {name = "Radio Appolo, Wiekevorst, Be", url = "https://radioapollo.beheerstream.nl/8004/stream"},
    {name = "Radio Land Van Waas Stream", url = "http://stream.rlvw.be:8480/stream"},
    {name = "Radio Utopia 1079 - Baal, Be", url = "http://panel.beheerstream.com:2199/tunein/radioutopia.pls"},
    {name = "Komilfoo FM - 1069 FM Aarschot", url = "http://www.komilfoo.be/live/komilfoo.m3u"},
    {name = "RCF Bruxelles", url = "http://rcf.streamakaci.com/rcfbruxelles.mp3"},
    {name = "VBRO Radio", url = "http://stream.vbro.be:9100/vbro"},
    {name = "VBRO Evergreen", url = "http://stream.vbro.be:9400/evergreen"},
    {name = "Radio Alma", url = "http://shoutcast2.wirelessbelgie.be:8310/;stream.mp3"},
    {name = "Equinoxe FM 1001", url = "http://equinoxefm.ddns.net:8000/stream.ogg"},
    {name = "RTBF Vivacité Charleroi", url = "https://radios.rtbf.be/vivacharleroi-64.aac"},
    {name = "RTBF Vivacité Hainaut", url = "https://radios.rtbf.be/vivahainaut-64.aac"},
    {name = "RBS Radio", url = "http://streams.movemedia.eu/rbs"},
    {name = "Radio Sunshine 97,5 Ostbelgien", url = "http://streamlive.syndicationradio.fr:8158/stream"},
    {name = "Tradcan", url = "https://dc1.serverse.com/proxy/wiupfvnu?mp=/TradCan"},
    {name = "Radio M FM", url = "http://149.202.22.75:8248/;"},
    {name = "Radio FM Gold", url = "http://fmgold.mvserver.be:3181/;"},
    {name = "We Are Various", url = "https://azuracast.wearevarious.com/listen/we_are_various/live.mp3"},
    {name = "Lokale Radio Lanaken", url = "http://s2.ssl-stream.com:8070/1;"},
    {name = "Omroep Neteland", url = "http://media1.hostin.cc/omroepneteland.mp3"},
    {name = "Omroep Voeren - Vroenhoven, Be", url = "http://stream.omroepvoeren.be/radio/8000/radio.mp3"},
    {name = "Radio Christina 1061 FM - Heist Od Berg , Be", url = "http://shoutcast2.wirelessbelgie.be:8100/;"},
    {name = "Familieradio Enjoy Fm", url = "http://live.radiostudio.be/enjoyfm"},
    {name = "Radio Zoe Gold", url = "https://streams.movemedia.eu/zoegold128"},
    {name = "Radio Parkies - Meise, Be", url = "https://stream.radioparkies.com/listen/parkies/stream.mp3"},
    {name = "Roa", url = "https://live.roa.be:8000/roa1062fm-128.mp3"},
    {name = "FM Goud Tenerife", url = "https://stream.fmgoud.be/fm-goud-tenerife"},
    {name = "Radio Memory", url = "https://live.radiostudio.be/radiomemory"},
    {name = "De Jukebox", url = "http://s35.myradiostream.com:14472/"},
    {name = "Emotion", url = "http://stream.radioemotion.be/;stream.mp3"},
    {name = "Radio Park FM", url = "http://streams.movemedia.eu:8054/"},
    {name = "Radio 700 - Elsenborn, Be", url = "https://streaming.radio700.eu/radio700.mp3"},
    {name = "Radio 700 - Elsenborn, Be Aac", url = "https://streaming.radio700.eu/radio700.aac"},
    {name = "CROOZE Christmas", url = "https://streaming.shoutcast.com/xmas-crooze-aac"},
    {name = "Willy Classx - AAC", url = "https://streams.radio.dpgmedia.cloud/redirect/willy_be_class_x/aac"},
    {name = "Radio Onda", url = "https://stream.rcast.net/69114"},
    {name = "Radio Tamara", url = "http://audiostreamen.nl:8006/"},
}

return stations