local stations = {
    {name = "Radio Romania Actualități", url = "http://89.238.227.6:8006/;"},
    {name = "Deep House Radio - Bucharest Romania", url = "http://live.dancemusic.ro:7000/listen.pls?sid=1"},
    {name = "Magic FM", url = "http://live.magicfm.ro:9128/magicfm.aacp"},
    {name = "Kiss Fm Ro", url = "https://www.kissfm.ro/listen.pls"},
    {name = "Radio Zu", url = "http://zuicast.digitalag.ro:9420/zu"},
    {name = "Play 90'S", url = "http://live.playradio.org:9090/90HD"},
    {name = "DIGI FM", url = "http://edge76.rdsnet.ro:84/digifm/digifm.mp3"},
    {name = "Magic Party Mix", url = "https://live.magicfm.ro/magic.party.mix"},
    {name = "Dance FM 895 Bucharest", url = "http://edge126.rdsnet.ro:84/profm/dancefm.mp3"},
    {name = "Pro FM", url = "http://edge126.rdsnet.ro:84/profm/profm.mp3"},
    {name = "Digi24Fm", url = "https://edge76.rcs-rds.ro/digifm/digi24fm.mp3"},
    {name = "Gherla FM", url = "http://89.39.189.52:8000/;"},
    {name = "Europa FM Romania", url = "https://astreaming.edi.ro:8443/EuropaFM_aac"},
    {name = "Radio Manele FM", url = "http://a.fmradiomanele.ro:8054/;"},
    {name = "Radio Cafe Romania", url = "http://live.radiocafe.ro:8048/live.aac"},
    {name = "Europafm", url = "http://astreaming.edi.ro:8000/EuropaFM_aac"},
    {name = "Radio România Cultural", url = "http://stream2.srr.ro:8012/"},
    {name = "Radio 1 Manele", url = "http://radio1manele.no-ip.org:8000/;"},
    {name = "Virgin Radio Romania", url = "https://astreaming.edi.ro:8443/VirginRadio_aac"},
    {name = "Realitatea FM", url = "https://shout.realitatea.net:8001/rfmweb"},
    {name = "Europa FM", url = "http://astreaming.europafm.ro:8000/europafm_aacp48k"},
    {name = "Prob Radio", url = "http://live.radioprob.ro:8888/stream"},
    {name = "Lautaru Populara", url = "http://live.radiolautaru.ro:9000/;stream.nsv"},
    {name = "Rockfm", url = "https://live.rockfm.ro/rockfm.aacp"},
    {name = "Radio Tequila Dance Romania", url = "http://dance.radiotequila.ro:7000/;stream.nsv"},
    {name = "DJ Radio Romania", url = "https://stream.djradio.ro/radio/8000/stream.mp3"},
    {name = "Rock FM Romania", url = "http://live.rockfm.ro:9128/rockfm.aacp"},
    {name = "Radio Impuls Romania", url = "http://live2.radio-impuls.ro/"},
    {name = "Goldfm", url = "http://80.86.106.110:8002/"},
    {name = "Smart FM", url = "http://live.smartradio.ro:9128/live"},
    {name = "Radio Guerrilla", url = "http://live.guerrillaradio.ro:8010/guerrilla.aac"},
    {name = "Eteatru", url = "http://stream2.srr.ro:8078/eteatru.mp3"},
    {name = "Chill FM Romania", url = "http://edge126.rdsnet.ro:84/profm/chillfm.mp3"},
    {name = "Radio Boom House Music", url = "https://stream.radioboom.ro/listen/boom_house_music/radio.mp3"},
    {name = "RFI Romania", url = "http://asculta.rfi.ro:9128/live.aac"},
    {name = "Antena Satelor", url = "http://89.238.227.6:8042/"},
    {name = "Play Radio Cafe", url = "http://live.playradio.org:9090/CafeHD"},
    {name = "Romantic FM", url = "http://zuicast.digitalag.ro:9420/romanticfm"},
    {name = "Kiss Fm", url = "http://live.kissfm.ro:9128/kissfm.aacp"},
    {name = "Radio Hit Fm Manele", url = "http://asculta.radiohitfm.net:8340/;"},
    {name = "Radio Petrecăretzu", url = "http://live.radiopetrecaretzu.ro:8383/;"},
    {name = "Atmospheric Dnb S0Urce", url = "https://brokenbeats.net/stream/aac"},
    {name = "Radio Romania International", url = "http://stream2.srr.ro:8052/;"},
    {name = "Mooz Dance TV - Sunet ONLINE By Romaniaradioro", url = "http://109.103.178.66:8018/listen.pls"},
    {name = "Magic Sunset", url = "https://live.magicfm.ro/magic.lite"},
    {name = "Radio Romanian Manele", url = "https://asculta.radioromanian.net/8300/stream"},
    {name = "Radio Romantic", url = "http://stream.zeno.fm/72k4a597rs8uv"},
    {name = "Play Radio 916", url = "http://live.playradio.org:9090/FMHD"},
    {name = "Radio Trinitas", url = "http://81.196.25.70:8000/"},
    {name = "Radio Tanănana", url = "https://live.tananana.ro:8443/stream-48.aac"},
    {name = "Musicfm", url = "http://edge126.rdsnet.ro:84/profm/music-fm.mp3"},
    {name = "RADIO MANELE PETRECERE", url = "https://ssl.servereradio.ro/8123/stream"},
    {name = "FM Radio Manele", url = "http://a.fmradiomanele.ro:8054/stream"},
    {name = "Radio Reggaeton", url = "http://85.120.223.142:8888/stream?icy=https"},
    {name = "Radio Oldies Romania", url = "http://listen.radiooldies.ro:9200/;"},
    {name = "Extravaganza Radio", url = "https://s3.radio.co/s1492c0564/listen"},
    {name = "Radio Vacanta", url = "http://89.238.227.6:8330/listen.pls"},
    {name = "Focus FM", url = "http://live.focusfm.ro:8000/focusfmhigh.ogg.m3u"},
    {name = "Capital FM - Manele", url = "http://manele.capitalfm.ro:8020/;"},
    {name = "Radio România Iași", url = "http://89.238.227.6:8202/listen.pls"},
    {name = "Dance FM", url = "https://edge126.rcs-rds.ro/profm/dancefm.mp3"},
    {name = "Rock Fm Ballads", url = "https://live.rockfm.ro/ballads.rock"},
    {name = "Radio Tequila Petrecere", url = "http://petrecere.radiotequila.ro:7000/;"},
    {name = "Radio Hot Style", url = "http://mp3.radiohot.ro:8000/stream"},
    {name = "Radio Dreams Dance Hits Adrenaline", url = "http://5.2.184.92:3390/radiodreams.g1.ro?icy=https"},
    {name = "Doina", url = "http://89.43.138.116:8000/radiodoina.mp3"},
    {name = "ONEFM", url = "http://live.onefm.ro:9128/onefm.aacp"},
    {name = "Radio Marketescu Minimal", url = "https://sonic2-rbx.cloud-center.ro:7022/stream"},
    {name = "BUG Mafia", url = "https://stream-153.zeno.fm/x3626gvvsf9uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJ4MzYyNmd2dnNmOXV2IiwiaG9zdCI6InN0cmVhbS0xNTMuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6InRBU2NXVkZDUWZHTkpWLUgySjdxa3ciLCJpYXQiOjE3MTU4MjkwNDIsImV4cCI6MTcxNTgyOTEwMn0.FEyU-KKrVHVgpMYMNw3sAdunkbEeCRtxphRRFVPnPDw"},
    {name = "Radio România Muzical", url = "http://stream2.srr.ro:8022/"},
    {name = "Radio Folclor Buzau", url = "https://live.radiofolclorbuzaufm.ro:8910/stream"},
    {name = "Radio Folclor", url = "https://ssl.omegahost.ro/8092/stream"},
    {name = "Radio Cartier Romania", url = "https://live.radiocartier.eu:8048/stream"},
    {name = "Radio Liberty Multiplayer Phonk Remix", url = "https://hs1.radiolibertymp.ro/listen/lmpphonk/stream.mp3"},
    {name = "Gospace", url = "https://live.gofm.ro:2000/stream/goSPACE/stream.mp3"},
    {name = "Radio Bucuresti FM", url = "http://89.238.227.6:8032/;stream/1"},
    {name = "Space Fm Dance", url = "https://spacefm.live/radio/8000/spacefm128"},
    {name = "Baraka Radio", url = "https://ice.streams.ovh:1165/stream"},
    {name = "Super FM Prahova", url = "https://asculta.superfmradio.ro:9720/stream"},
    {name = "Play Urban", url = "http://live.playradio.org:9090/UrbanHD"},
    {name = "Radio Pro Manele", url = "http://radiopromanele.zapto.org:8000/;"},
    {name = "RADAIO ROMANCE21ROMANIA", url = "https://stream.rcast.net/200392"},
    {name = "Ambiento", url = "https://ambiento-adradio.radioca.st/128"},
    {name = "Radio Timișoara 630 AM", url = "http://89.238.227.6:8352/"},
    {name = "Radio Delta Romania", url = "https://sslstreaming.com/8014/stream"},
    {name = "Radio Turda", url = "https://live.aftech.ro/radio/8010/radio.mp3"},
    {name = "Dark Edge Radio", url = "http://stream.darkedge.ro:8000/"},
    {name = "Radio ZEN", url = "https://streaming.shoutcast.com/radiozen"},
    {name = "One FM Dance", url = "https://live.onefm.ro/onefm.aacp"},
    {name = "Europa FM-AAC", url = "http://astreaming.virginradio.ro:8000/EuropaFM_aac"},
    {name = "Getarum Radio", url = "https://stream.clever-host.ro/8010/stream"},
    {name = "Love Marilena Galați", url = "https://radio.sonicpanel.ro/8068/stream"},
    {name = "Alba24Ro", url = "http://movingrecords.radioca.st:8045/stream"},
    {name = "Radio Taraf MANELE", url = "http://asculta.radiotaraf.ro:7100/;"},
    {name = "Radio DA", url = "http://n01.radiojar.com/du8khw2d2wzuv"},
    {name = "Valori Românești Radio", url = "https://securestreams6.autopo.st:2250/"},
    {name = "Capital FM - Dance", url = "https://ssl.omegahost.ro:8020/stream"},
    {name = "Fain Simplu", url = "http://zuicast.digitalag.ro:9420/fainsisimplu"},
    {name = "Sweet FM Romania", url = "https://live.gofm.ro:2000/stream/SWEET/stream.mp3"},
    {name = "Radio Romanian Dance", url = "https://asculta.radioromanian.net/8100/stream"},
    {name = "Radio Romanian Hip-Hop", url = "https://asculta.radioromanian.net/8400/stream"},
    {name = "Radio Badita Popular", url = "http://89.39.189.29:8000/listen.pls"},
    {name = "Radio Armonia Romania", url = "http://audio.radioarmoniaro.bisericilive.com/mainradioarmoniaro.mp3.m3u"},
    {name = "RADIO MIRAJUL MUZICII", url = "http://live.radiomiraj.ro:9952/stream"},
    {name = "România Oltenia-Craiova", url = "http://stream2.srr.ro:8370/;stream.mp3"},
    {name = "Eveniment FM Sibiu 1032", url = "https://live.gofm.ro:2000/stream/eveniment"},
    {name = "RADIO MARIA ROMANIA HUNG", url = "http://dreamsiteradiocp4.com:8026/stream"},
    {name = "Radio Flo Manele", url = "https://live.radioflomanele.ro/8084/stream"},
    {name = "Radio Doza Manele", url = "https://manele.radiodoza.eu:8100/listen.pls"},
    {name = "Radio 7 Bucuresti Romania", url = "http://80.86.106.32:8000/radio7.mp3"},
    {name = "Bistrița FM 926", url = "https://audio-edge-cmc51.fra.h.radiomast.io/66f238bb-8b61-4196-a8c3-28aea07235e8"},
    {name = "Radio Manele Romania", url = "http://petrecere.fmradiomanele.ro:8123/;stream.nsv"},
    {name = "Radio Energy Cugir", url = "https://sonicssl.namehost.ro/8790/stream/;"},
    {name = "Rock Fm Blues", url = "https://live.rockfm.ro/blues"},
    {name = "Radio Lăutaru", url = "http://live.radiolautaru.ro:9000/;"},
    {name = "Radio Gold FM", url = "http://80.86.106.110:8002/listen.pls"},
    {name = "Radio Boom Energy", url = "https://stream.radioboom.ro/listen/boom_energy/radio.mp3"},
    {name = "CFM Radio", url = "http://stream2.radiocfm.ro:9090/CFM"},
    {name = "Radio DEEA", url = "http://radiocdn.nxthost.com/radio-deea"},
    {name = "Frăsinești Radio", url = "https://stream.zeno.fm/mpmilx1n4yuuv"},
    {name = "Radio Dacia Energie", url = "https://streaming.napocalive.ro/radio-dacia01"},
    {name = "Radio Unique", url = "http://listen.radiounique.ro:8106/live"},
    {name = "Radio Vocea Evangheliei RVE Sibiu", url = "https://c13.radioboss.fm:18286/stream"},
    {name = "Super FM", url = "https://live.superfm.ro/stream.mp3"},
    {name = "Radio Space 90", url = "http://ingame.go.ro:8003/stream"},
    {name = "Radio Filadelfia", url = "https://b1.radiofiladelfia.ro:8101/filadelfia_128.aac"},
    {name = "Blues Radio", url = "http://stream.zeno.fm/bpn1hy0h6ehvv.m3u"},
    {name = "OXO Radio", url = "https://s4.ssl-stream.com/listen/oxo_radio/radio.mp3"},
    {name = "West City Radio", url = "http://live.westcityradio.ro:8000/mp3"},
    {name = "Radio Kids Romania", url = "https://asculta.radioromanian.net:10997/"},
    {name = "Radio Mynele", url = "http://live.radiomynele.ro:8000/;"},
    {name = "Rock Fm Hard Rock", url = "https://live.rockfm.ro/hard.rock"},
    {name = "Dance Effect Radio", url = "http://asculta.danceeffect.ro:3333/;"},
    {name = "Radio Romania Constanta", url = "http://89.238.227.6:8332/listen.pls?sid=1"},
    {name = "Napoca FM", url = "https://streaming.napocalive.ro/napoca-fm"},
    {name = "Radio Deep", url = "http://live.radiodeep.ro:7500/;"},
    {name = "Gobeach", url = "https://live.gofm.ro:2000/stream/goBEACH/stream.mp3"},
    {name = "Jurnal FM", url = "https://ssl.radios.show:7009/stream"},
    {name = "Aripi Spre Cer Instrumental", url = "https://instrumental.aac.aripisprecer.ro/radio.mp3;"},
    {name = "Radio Someș", url = "https://evcast01.mediacp.eu/somes"},
    {name = "Radio Transilvania - Cluj", url = "https://stream2.radiotransilvania.ro/Cluj"},
    {name = "Radio Dobrogea", url = "http://stream.arhivaradiodobrogea.ro:7000/dobrogea"},
    {name = "RADIO MARIA ROMANIA", url = "http://dreamsiteradiocp2.com:8002/stream"},
    {name = "RADIO PRO PARTY", url = "http://asculta.proparty.net:8567/stream"},
    {name = "Radio Dacia Calm", url = "https://streaming.napocalive.ro/radio-dacia04"},
    {name = "Radio România Cluj", url = "http://89.238.227.6:8384/"},
    {name = "Metronom FM", url = "http://86.123.134.70:8000/metronom"},
    {name = "Radio Domeldo", url = "https://radiodomeldo.ro/movie"},
    {name = "Medias Fm", url = "http://mediasfm.eushells.ro:8082/;stream.nsv"},
    {name = "Marlene Radio", url = "https://live.gofm.ro:2000/stream/MARLENERADIO/stream.mp3"},
    {name = "Kolozsvári Rádió", url = "http://89.238.227.6:8386/listen.pls"},
    {name = "EBS | Jazz", url = "https://azura.ebsmedia.ro/listen/jazz/jazz128.mp3"},
    {name = "EBS | Electro", url = "https://azura.ebsmedia.ro/listen/electro/electro128.mp3"},
    {name = "Radio Manele Premium", url = "http://88.198.70.25:8894/;"},
    {name = "Magic Gold Hits", url = "https://live.magicfm.ro/magic.gold.hits"},
    {name = "Radio Romance 21", url = "http://live.radioromance21.ro:9950/stream"},
    {name = "Radio Tequila Manele", url = "http://live.radiotequila.ro:7000/;"},
    {name = "Aripi Spre Cer Popular", url = "https://popular.stream.aripisprecer.ro/radio.mp3"},
    {name = "247 FM Exotic", url = "http://exotic.radio247international.com:9810/;stream.mp3"},
    {name = "Radio HY Brăila", url = "https://asculta.ascultatare.ro:8034/;"},
    {name = "Radio Romania Muzical", url = "http://stream2.srr.ro:8020/listen.pls"},
    {name = "Radio Romanian Popular", url = "https://asculta.radioromanian.net/8500/stream"},
    {name = "MB Music Radio", url = "http://s33.myradiostream.com:16150/"},
    {name = "Rádió Gaga Gyergyószék", url = "https://a3.my-control-panel.com:6690/radio.mp3"},
    {name = "Black Rhino Radio", url = "https://blackrhinoradio.out.airtime.pro/blackrhinoradio_a"},
    {name = "You FM Romania", url = "https://asculta.muzicaok.de:8034/listen.pls"},
    {name = "Radio Marketescu Houseminimal", url = "https://s31.radiolize.com/radio/8020/radio.mp3"},
    {name = "Muscel FM 941", url = "http://188.27.135.199:8000/muscelfm"},
    {name = "Roman FM", url = "https://live.romanfm.ro:8000/;rfm"},
    {name = "Radio Banat FM", url = "http://live.radiobanatfm.com:8002/listen.pls"},
    {name = "Rádió Gaga", url = "http://rc.radiogaga.ro:8000/live"},
    {name = "Radio Tequila Manele Romania", url = "https://petrecere.radiotequila.ro/7000/stream"},
    {name = "Ascultă-Radio Levi", url = "http://audio.radioleviro.bisericilive.com/radioleviro.mp3"},
    {name = "Radio Gosen", url = "http://ascultaradiogosen.no-ip.org:8125/listen.pls"},
    {name = "Vox FM - Székelykeresztúr", url = "http://stream.voxfm.ro:8000/listen.pls"},
    {name = "Electric Castle", url = "https://electriccastle.out.airtime.pro/electriccastle_a"},
    {name = "Play Radio", url = "https://live.playradio.org:8443/90HD"},
    {name = "Radio Dacia Traditional", url = "https://streaming.napocalive.ro/radio-dacia06"},
    {name = "MDI Fm", url = "http://stream.mdifm.ro:8000/live"},
    {name = "Alt FM", url = "http://asculta.radiocnm.ro:8002/live"},
    {name = "Radio Timișoara", url = "http://89.238.227.6:8354/"},
    {name = "Radio Damici", url = "http://ssl.radios.show:8004/stream"},
    {name = "Radio Noise Party", url = "https://partylive.radionoise.ro:9160/"},
    {name = "Radio Manelescu", url = "https://my3.radiolize.com:8000/radio.mp3"},
    {name = "Radio Oldies", url = "http://live.radiooldies.ro:9200/listen.pls"},
    {name = "Chill FM", url = "https://edge126.rcs-rds.ro/profm/chillfm.mp3?1712405207687"},
    {name = "Radio Alpin", url = "http://live.radiodeejay.hr:7002/;"},
    {name = "Supravibe Radio", url = "https://supraviberadio-radiohosting.radioca.st/stream"},
    {name = "Radio Click Romania", url = "http://live.radioclick.ro:8008/"},
    {name = "Supersonic Radio", url = "https://s5.radio.co/s08e5c5875/listen"},
    {name = "Radio Stres", url = "http://live.radiostres.com:8402/;"},
    {name = "Radio Trib", url = "https://streams.radio.co/s78f983952/listen"},
    {name = "Radio Veselia Folclor", url = "http://asculta.radioveseliafolclor.com:8232/;"},
    {name = "Radio Alba24", url = "https://movingrecords.radioca.st/;"},
    {name = "Radio Oltenia Craiova", url = "http://stream2.srr.ro:8370/listen.pls"},
    {name = "Radio Killer Câmpia Turzii", url = "https://s12.myradiostream.com/17492/listen.mp3"},
    {name = "Radio Voces Campi", url = "http://vocescampi.ro:8001/;"},
    {name = "Radio Super Manele", url = "http://manele.capitalfm.ro:8020/listen.pls"},
    {name = "Radio ROT Romania", url = "http://radiorot.ovh:8000/radio.mp3"},
    {name = "Cool FM", url = "https://live.aftech.ro/radio/8060/radio.mp3"},
    {name = "Radio Terra", url = "http://188.26.110.59:8000/terra_hq.mp3"},
    {name = "Radio HIT Iasi", url = "http://live02.radiohit.ro:8000/hit.mp3"},
    {name = "Aripi Spre Cer", url = "https://mobile.stream.aripisprecer.ro/radio.mp3"},
    {name = "Radio Aquila", url = "https://s10.webradio-hosting.com/proxy/schrteam/stream"},
    {name = "HIT FM", url = "http://s3.myradiostream.com:4404/;"},
    {name = "Radio Korrupt Nostalgic", url = "http://stream.zeno.fm/ow1xlcqo3aatv"},
    {name = "Radio Top Suceava", url = "https://live.radiotop.ro/radio/8000/radio.mp3"},
    {name = "Radio Romanian Rock", url = "https://asculta.radioromanian.net/8800/stream"},
    {name = "City Fm 983", url = "https://mscp1.gazduireradio.ro:1270/stream"},
    {name = "Radio A-Tentat", url = "https://ssl.omegahost.ro/8066/stream"},
    {name = "Rádió Gaga Háromszék", url = "https://a3.my-control-panel.com:6670/radio.mp3"},
    {name = "Gofm", url = "https://live.gofm.ro:2000/stream/goFMro"},
    {name = "Radio Nova22", url = "http://s2.myradiostream.com:4520/listen.m4a"},
    {name = "Gocafe", url = "https://live.gofm.ro:2000/stream/goCAFE/stream.mp3"},
    {name = "Radio RFM", url = "https://shout.realitatea.net:8001/mixt"},
    {name = "Radio Biserica Romano Catolica Bacau", url = "http://46.4.14.12:8020/listen.pls"},
    {name = "Aripi Spre Cer Worship", url = "https://worship.aac.aripisprecer.ro/radio.mp3;"},
    {name = "Radio Arad", url = "http://85.120.220.205:8000/radio-arad.m3u"},
    {name = "Radio Medias", url = "http://mediasfm.eushells.ro:8082/listen.pls"},
    {name = "Martathonita Radio", url = "https://radio.mountathos.info/live"},
    {name = "Traffic Radio", url = "https://live.gofm.ro:2000/stream/traficradio"},
    {name = "Radio Boom Gold", url = "https://stream.radioboom.ro/listen/boom_gold/radio.mp3"},
    {name = "Orion FM 917", url = "https://sonic1-rbx.cloud-center.ro/8070/stream"},
    {name = "UNTOLD RADIO", url = "https://live-untold.distinct.ro:8001/untold.ogg"},
    {name = "TWIST -Radio Trap", url = "https://stream.zeno.fm/9dhe4r7upg8uv"},
    {name = "Rádió Koko", url = "https://az10.yesstreaming.net:8210/radiokoko.mp3"},
    {name = "Free FM Bucarest", url = "https://rocafmadrid.radioca.st/"},
    {name = "Dcnews", url = "https://live.radiodcnews.ro:8443/public-live-feed"},
    {name = "Next Radio", url = "https://stream.nextradio.live/listen/nextradio/NextHD"},
    {name = "Bigfm Deva", url = "http://82.208.143.10:8000/;"},
    {name = "Radio Dacia Paradis", url = "https://streaming.napocalive.ro/radio-dacia02"},
    {name = "Club Radio", url = "https://live.clubradio.ro/listen/clubradio/live"},
    {name = "Star Rádió", url = "http://live.starradio.ro:9000/;&type=mp3"},
    {name = "Hangos Rádió", url = "https://stream.zeno.fm/mv62tmd8wp8uv.aac"},
    {name = "Itsy Bitsy", url = "http://itsybitsy.ro/listen.pls"},
    {name = "Radio Blue Romania", url = "https://asculta.muzicaok.de:8002/stream"},
    {name = "Radio Vocea Evangheliei Suceava - RVE", url = "http://s9.yesstreaming.net:7014/stream"},
    {name = "Alien Club Fantasy", url = "http://radio.club-fantasy-hub.ro:8000/;"},
    {name = "Enjoy Radio", url = "https://live.enjoyradio.ro/radio/8000/enjoylive.mp3"},
    {name = "Rádió Gaga Udvarhelyszék", url = "https://a3.my-control-panel.com:6680/radio.mp3?1709996423"},
    {name = "Superfm Brasov 938 FM", url = "https://live.superfm.ro/stream.mp3?nocache=0.19023860954617056"},
    {name = "Radio Antena Braşovului", url = "http://streaming.radiomures.ro:8302/listen.pls"},
    {name = "Dejavumusic", url = "https://stream.zeno.fm/mdupctf7zxhvv"},
    {name = "Radio Brașov", url = "https://live.radiobrasov.ro/stream.mp3?nocache=${Math.random()}"},
    {name = "Fresh FM", url = "https://radio.onlinehost.ro/listen/freshfm/radio.mp3"},
    {name = "Social FM", url = "http://noasrv.caster.fm:10085/listen.m3u"},
    {name = "Manastirea Putna", url = "https://www.ortodoxradio.ro:8000/stream48"},
    {name = "Space FM", url = "http://stream.radioparadise.com/world-etc-192"},
    {name = "Radio Goldies", url = "https://s10.streamingcloud.online/stream/13664"},
    {name = "EBS | Music", url = "https://azura.ebsmedia.ro/listen/music/music128.mp3"},
    {name = "EBS | Romanian Gold", url = "https://azura.ebsmedia.ro/listen/romaniangold/romaniangold128.mp3"},
    {name = "EBS | Fresco", url = "https://azura.ebsmedia.ro/listen/fresco/fresco128.mp3"},
    {name = "EBS | Lounge", url = "https://azura.ebsmedia.ro/listen/lounge/lounge128.mp3"},
    {name = "Social FM 969", url = "https://noasrv.caster.fm:10085/listen"},
    {name = "Ercis FM", url = "https://ercislive.enkosoft.com/live"},
    {name = "EBS | Xmas", url = "https://azura.ebsmedia.ro/listen/xmas/xmas128.mp3"},
    {name = "EBS | Blues", url = "https://azura.ebsmedia.ro/listen/blues/blues128.mp3"},
    {name = "Radio Eco Natura", url = "https://n0a.radiojar.com/fp5c3fgbyzzuv"},
    {name = "Radio Crasna", url = "http://ssl.omegahost.ro/8006/stream/"},
    {name = "Biblia Audio - Radio Calea Spre Cer", url = "https://panel.radiocaleasprecer.com/radio/8010/radio.mp3"},
    {name = "TRADIȚIONAL POPULAR - Radio Calea Spre Cer LIVE 247", url = "https://panel.radiocaleasprecer.com/radio/8020/radio.mp3"},
    {name = "Dux Radio", url = "https://radio.duxradio.ro:8002/stream"},
    {name = "Poetunes Radio", url = "https://sonic1-rbx.cloud-center.ro/8054/stream"},
    {name = "Retró Rádió Csíkszereda", url = "http://online.radioretro.ro:8002/RetroRadio.mp3"},
    {name = "Radio Lipova", url = "https://securestreams5.autopo.st:1888/;listen.pls"},
    {name = "Pink Radio", url = "http://pink.exyuserver.com/stream"},
    {name = "Radio 3Net", url = "http://media.3netmedia.ro:8000/Live128.m3u"},
    {name = "Radio Romanian Disco", url = "https://asculta.radioromanian.net/8700/stream"},
    {name = "Radio Romanian Gold", url = "https://asculta.radioromanian.net/8900/stream"},
    {name = "Radio FIR", url = "https://sonic1-rbx.cloud-center.ro/8010/stream"},
    {name = "Nova 22", url = "https://s2.myradiostream.com/4520/listen.mp3"},
    {name = "Plusz FM - Nagyvarad", url = "https://stream2.radiotransilvania.ro/Nagyvarad"},
    {name = "Szépvíz FM", url = "http://szepvizfm.ro:8000/"},
    {name = "Radio Marketescu Reggaetrip-Hop", url = "https://s37.radiolize.com/radio/8100/radio.mp3"},
    {name = "Radio Lumina 904", url = "http://live.radiolumina.ro/lumina_winamp-hi.m3u"},
    {name = "Radio Constanta FM", url = "http://89.238.227.6:8332/;stream/1"},
    {name = "Gojazz", url = "https://live.gofm.ro:2020/stream/goJAZZ"},
    {name = "Radio Intens", url = "https://www.radiointens.ro/128.pls"},
    {name = "Radio Xtream", url = "https://ssl.radios.show:7008/;"},
    {name = "EBS Radio", url = "https://azura.ebsmedia.ro/public/live/playlist.m3u"},
    {name = "Radio Boom Rock", url = "https://stream.radioboom.ro/listen/boom_rock/radio.mp3"},
    {name = "Agnus Rádió", url = "http://radio2.tirek.hu:8000/agnusradio"},
    {name = "Ascultă-Radio Unison", url = "http://audio.radiounisonro.bisericilive.com:8080/radiounisonro.mp3"},
    {name = "Radio Rahanopolis", url = "http://86.120.124.101:8000/128"},
    {name = "TWIST -Radio Ușoară", url = "https://stream.zeno.fm/g7uert66bxhvv"},
    {name = "Https:Livereintregirearo", url = "https://live.reintregirea.ro/"},
    {name = "Radio Noise", url = "http://live.radionoise.ro:9100/;"},
    {name = "Radio Impuls RO", url = "https://live.radio-impuls.ro/stream"},
    {name = "City Radio Romania", url = "http://live.city-radio.ro:8800/;"},
    {name = "Half Is Enough", url = "http://centauri.shoutca.st:8322/stream"},
    {name = "Radio Dacia Clasic", url = "https://streaming.napocalive.ro/radio-dacia05"},
    {name = "Rádio Koko", url = "https://az10.yesstreaming.net:8210/radiokoko"},
    {name = "Radioromanian Colinde", url = "https://asculta.radioromanian.net/8600/stream"},
    {name = "Radio Boom Vrancea", url = "http://89.38.8.133:8000/listen.pls"},
    {name = "Cross One Radio", url = "https://lb01.bpstream.com:8630/;"},
    {name = "Marosvásárhelyi Rádió", url = "http://streaming.radiomures.ro:8312/;stream.nsv&type=mp3"},
    {name = "Funfm", url = "http://online.funfm.ro:8000/funfm.mp3"},
    {name = "Gofmro", url = "http://live.gofm.ro:9128/"},
    {name = "Radio Tranquila Manele", url = "https://live.radiotranquila.net:8032/stream"},
    {name = "Régió Rádió", url = "https://live.regioradio.info/listen/"},
    {name = "HIT FM Alba", url = "https://s3.myradiostream.com/4404/listen.mp3"},
    {name = "HIT FM Brasov", url = "https://s25.myradiostream.com/:16434/listen.mp3?nocache=1719549990"},
    {name = "Blaj Radio", url = "https://ssl.asculta.live:8016/"},
    {name = "Radio 1 FM 1072", url = "https://stream.zeno.fm/ekrzffgjb4ktv"},
    {name = "Impact FM", url = "http://109.166.241.233:8500/"},
    {name = "Radio România Brașov", url = "http://stream2.srr.ro:8210/;"},
    {name = "Radio Greu De Difuzat", url = "https://greudedifuzat.ro/stream/"},
    {name = "Radio Antena Satelor", url = "http://89.238.227.6:8042/listen.pls"},
    {name = "EBS | Movie Soundtracks", url = "https://azura.ebsmedia.ro/listen/movies/movies128.mp3"},
    {name = "EBS | Classical", url = "https://azura.ebsmedia.ro/listen/classical/classical128.mp3"},
    {name = "EBS | Magyar Zene", url = "https://azura.ebsmedia.ro/listen/hungarian/hungarian128.mp3"},
    {name = "Radio Bandit", url = "http://live.radiobandit.ro:8000/320.mp3"},
    {name = "Nicecreamfm - Blue", url = "https://play.nicecream.fm/radio/8020/blue.mp3"},
    {name = "Radio Party București", url = "http://asculta.radiopartybucuresti.ro:8050/;"},
    {name = "Ascultă-Rve Oradea", url = "http://38.96.148.39:6700/stream"},
    {name = "Radio VIP", url = "http://live1.radiovip.ro:8969/;"},
    {name = "Radio Test", url = "https://hs1.radiolibertymp.ro/listen/lmpchill/stream.mp3?refresh=1700228324588"},
    {name = "We Radio", url = "http://93.115.175.106:8000/player"},
    {name = "Golounge", url = "http://fr1.streamhosting.ch/lounge128.mp3"},
    {name = "Radio Elim Air", url = "http://91.213.11.102:8011/stream_high"},
    {name = "Radio Peniel", url = "https://stream.zeno.fm/a26ipyehngytv"},
    {name = "Radio Crazy", url = "http://live.crazyradio.ro:8024/stream"},
    {name = "Radiopitesteanuromania", url = "https://free.rcast.net/246157"},
    {name = "Radio Maria", url = "http://cloudrad.io/radiomariaromania/listen.pls"},
    {name = "Radiopapuc", url = "https://stream.zeno.fm/phcn6lncrj4tv"},
    {name = "Free FM Bucaresti", url = "https://rocafmadrid.radioca.st/stream"},
    {name = "Radio România 3 Net", url = "http://media.3netmedia.ro:8000/Live128"},
    {name = "Lounge Avenue", url = "http://arlandria.go.ro:8000/lounge"},
    {name = "Radio Iubire", url = "http://ssl.radios.show:8026/;"},
    {name = "RADIO MAGIA INIMII TALE", url = "https://radio.cloud23.eu/magiainimiitale"},
    {name = "Plusz FM - Margitta", url = "https://stream2.radiotransilvania.ro/Margitta"},
    {name = "Radio Romania Targu Mures AM", url = "http://streaming.radiomures.ro:8322/"},
    {name = "Playradio Urban", url = "https://live.playradio.org:8443/UrbanHD"},
    {name = "Music FM Romania", url = "https://live.musicfm.ro:8000/"},
    {name = "Radio Marketescu Raptrap", url = "https://s45.radiolize.com/radio/8060/radio.mp3"},
    {name = "Cozy FM", url = "https://live.cozyfm.ro:8010/live"},
    {name = "Gorebel", url = "https://live.gofm.ro:2000/stream/goREBEL/stream.mp3"},
    {name = "Radio Bucovina", url = "http://radiobucovina.ro/live.m3u"},
    {name = "Radio Cuibul Lupilor Albi", url = "https://stream.zeno.fm/7s5mmrtzmuhvv"},
    {name = "Gorock", url = "https://live.gofm.ro:2020/stream/goROCK"},
    {name = "Radio Resita", url = "http://89.238.227.6:8344/listen.pls"},
    {name = "Replica Radio", url = "https://securestreams.autopo.st:2490/"},
    {name = "Replica Radio Rock", url = "https://securestreams.autopo.st:2496/"},
    {name = "Radio Popular Arhiva 1", url = "http://web.archive.org/web/20180110095018if_/http://mp3.radiopopular.ro:7777/;"},
    {name = "Radio Nebunya", url = "http://asculta.radionebunya.ro:7575/"},
    {name = "Radio Dacia Relax", url = "https://streaming.napocalive.ro/radio-dacia03"},
    {name = "Pluszfm", url = "http://stream2.radiotransilvania.ro:8000/Nagyvarad"},
    {name = "Radio Liberty Slagare", url = "http://slagare.radioliberty.ro:1989/"},
    {name = "Radio Master One", url = "http://whsh4u-server.com:11060/autodj"},
    {name = "Radio Folclor Muntenia", url = "https://live.radiofolclormuntenia.ro:8008/stream"},
    {name = "Rádió Gaga Csíkszék", url = "https://a3.my-control-panel.com:6700/radio.mp3"},
    {name = "Radio Romania Targu Mures", url = "http://streaming.radiomures.ro:8302/listen.pls;/stream"},
    {name = "Rádió Gaga Marosszék", url = "https://a3.my-control-panel.com:6660/radio.mp3?1709995925"},
    {name = "Radio Extrem Live", url = "https://www.radio-extrem.com/asculta"},
    {name = "Atlas 21", url = "https://radio.manelemania.ro/listen/atlas21/atl21"},
    {name = "Intens", url = "http://live.radiointens.ro:8070/stream"},
    {name = "Radio Condor Bucharest", url = "http://www.radiocondor.ro:6303/"},
    {name = "Super FM Brasov 938", url = "https://live.superfm.ro/stream.mp3?time=1697692801"},
    {name = "Gherlafm", url = "http://89.39.189.52:8000/stream"},
    {name = "Radio Sky FM", url = "http://89.43.138.116:8000/radiosky.mp3"},
    {name = "Radio Vestea Buna", url = "http://c34.radioboss.fm:8175/autodj"},
    {name = "Gofresh", url = "https://live.gofm.ro:2000/stream/goFMFRESH/stream.mp3"},
    {name = "EBS | Nouvelle Vague", url = "https://azura.ebsmedia.ro/listen/nouvelle/nouvelle128.mp3"},
    {name = "Radio Camarad", url = "https://93.115.53.53/radio"},
    {name = "EBS | Alternative", url = "https://azura.ebsmedia.ro/listen/alternative/alternative128.mp3"},
    {name = "Nicecreamfm - Green", url = "https://play.nicecream.fm/radio/8010/green.mp3"},
    {name = "Nicecreamfm - Red", url = "https://play.nicecream.fm/radio/8000/red.mp3"},
    {name = "Radio Tequila Hip-Hop", url = "http://necenzurat.radiotequila.ro:7000/;"},
    {name = "Radio Tequila Oldies", url = "https://stream.zeno.fm/5a1utt11fkhvv"},
    {name = "Siculus Rádió", url = "http://46.214.17.202:8000/radioac3"},
    {name = "Radio Elim Plus", url = "http://91.213.11.102:8003/stream3"},
    {name = "Radio Prahova", url = "https://streamx.rph.ro:8100/relay"},
    {name = "Radio Taraf", url = "https://ddos.radiotaraf.ro/7100/stream"},
    {name = "Free FM Rock București", url = "https://freefmrock.radioca.st/stream"},
    {name = "Rocker Inside", url = "https://cast4.my-control-panel.com/proxy/fountai1/stream"},
    {name = "Radio Etno Vest Timisoara", url = "http://ssl.radios.show:8020/;"},
    {name = "Radio Marketescu Rockpop", url = "https://s37.radiolize.com/radio/8040/radio.mp3"},
    {name = "Radio Underland", url = "https://radio.underland.team/radio/8000/radio.mp3"},
    {name = "Radio Marketescu Travel", url = "https://s103.radiolize.com:8020/radio.mp3"},
    {name = "Aripi Spre Cer International", url = "https://international.aac.aripisprecer.ro/radio.mp3"},
    {name = "Aripi Spre Cer Special", url = "https://special.aac.aripisprecer.ro/radio.mp3;"},
    {name = "Aripi Spre Cer Predici", url = "https://predici.aac.aripisprecer.ro/radio.mp3"},
    {name = "Radio Claudia", url = "http://ssl.kenhost.ro:8091/listen.pls?sid=1"},
    {name = "Radio Orion", url = "http://90.84.231.191:7000/live.mp3"},
    {name = "Radio România Târgu Mureș - Marosvásárhelyi Rádió Románia", url = "http://streaming.radiomures.ro:8312/listen.pls?sid=1"},
    {name = "Radio Doza Urban", url = "https://stream.zeno.fm/cezx5b1nw98uv.pls"},
    {name = "Profi Rádió", url = "http://93.115.175.141:8000/stream"},
    {name = "Radio Calea Spre Cer LIVE 247", url = "https://panel.radiocaleasprecer.com/radio/8000/radio.mp3"},
    {name = "Radio Elim", url = "http://91.213.11.102:8000/stream_high"},
    {name = "Radio Elim Español", url = "http://91.213.11.102:8023/stream_high"},
    {name = "Erdély FM", url = "https://efm.radioca.st/stream"},
    {name = "Radio Trandafirul Rosu", url = "https://stream-148.zeno.fm/46mdd8ebdchvv?zs=3KOOJiuCTAuEqso88MJ74A"},
    {name = "Radio KPTV", url = "https://nl1.streamingpulse.com/ssl/KPTV"},
}

return stations