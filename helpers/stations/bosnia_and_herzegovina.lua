local stations = {
    {name = "Big2", url = "http://big2.bigportal.ba:8100/big2"},
    {name = "Radio BN", url = "http://stream.rtvbn.com:8522/;.mp3"},
    {name = "Kalman Radio", url = "http://188.40.62.20:8004/stream"},
    {name = "Narodni Radio - Sarajevo", url = "http://server1.tnt.ba:8010/"},
    {name = "Radio Miljacka", url = "https://radiomiljacka-bhcloud.radioca.st/stream.mp3"},
    {name = "BALKAN Hit RADIO - SARAJEVO", url = "https://cast2.asurahosting.com/proxy/balkanhi/stream"},
    {name = "Radio Rujnica Zavidovici", url = "https://r.name.ba:7115/stream"},
    {name = "Radio Sehara", url = "https://r.name.ba:7320/;"},
    {name = "Balkan Hip-Hop Radio", url = "http://centova.dukahosting.com:2022/stream"},
    {name = "Radiopostaja Mir - Međugorje", url = "http://mirm.live/mir.mp3"},
    {name = "Velkaton", url = "http://188.40.62.20:8044/;stream.mp3?_=1"},
    {name = "Radio Sarajevo", url = "http://malla.softnet.si:8000/;.mp3"},
    {name = "Antena Radio, Jelah Tešanj", url = "https://radio.tnt.ba/radio/8020/live?1616060583"},
    {name = "Radio DAŠ", url = "http://158.69.119.6:8095/;&type=mp3"},
    {name = "Radio Tešanj 922Mhz", url = "http://radio.daj.ba:8082/stream"},
    {name = "Kupreški Radio", url = "http://www.kupreskiradio.com/kupreski.m3u"},
    {name = "Radio Bihać Folk", url = "http://5.9.13.39:8071/stream"},
    {name = "Radio Breza", url = "https://sonicpanel.vmakerhost.com/8192/stream"},
    {name = "Pakao Radio", url = "https://www.pakaoradio.net/pakaoradio.m3u"},
    {name = "Antena Sarajevo", url = "http://116.203.7.166:9020/stream"},
    {name = "Day Dee Eurodance Radio", url = "http://daydeeeurodance.stream.laut.fm/daydeeeurodance"},
    {name = "Radio Marija", url = "http://cloudrad.io/radiomariabosnia/listen.pls"},
    {name = "BIG Radio 1 Banja Luka", url = "http://big1.bigportal.ba:8100/big1"},
    {name = "Radio Merak", url = "http://79.143.187.96:8092/stream/"},
    {name = "Takt Radio", url = "https://taktradio.ba/listen/stream/radio.mp3"},
    {name = "Radio - Livno", url = "http://cast2.name.ba:8127/stream/"},
    {name = "Radio Bir", url = "http://opml.radiotime.com/Tune.ashx?id=s102873"},
    {name = "Pop FM", url = "http://188.40.62.20:8032/"},
    {name = "Radio Magic", url = "http://stream.iradio.pro:8034/radiomagic"},
    {name = "Radio Džungla Doboj", url = "http://5.9.25.50:9302/stream"},
    {name = "Thrash Metal", url = "http://79.120.77.11:8000/thrashmetal"},
    {name = "Narodni Radio Tuzla", url = "http://server1.tnt.ba:9080/"},
    {name = "Radio Vihror", url = "https://r.name.ba:7500/stream"},
    {name = "Radio Busovača", url = "https://ec2s.crolive.com.hr:1510/stream"},
    {name = "RADIO MARIA BOSNIA", url = "http://dreamsiteradiocp.com:8034/stream"},
    {name = "Radio Posavina Zagreb", url = "http://cmr-hosting.com:8500/;stream.mp3"},
    {name = "Kontakt Radio", url = "http://mojstream.eu:8114/kontaktradio"},
    {name = "Slon Radio Tuzla", url = "http://31.47.0.130:88/broadwavehigh.mp3?src=1;"},
    {name = "Radio Avlija", url = "http://51.255.127.128:8900/;"},
    {name = "BIG 3", url = "http://big3.bigportal.ba:8100/big3?1548653014620"},
    {name = "Big Radio 4 Domaćica", url = "http://domacica.bigportal.ba:8100/domacica"},
    {name = "Radio USK", url = "https://radiousk.radioca.st/stream"},
    {name = "Radio Veseli Bosanac", url = "http://opportunity.shoutca.st:8038/"},
    {name = "RADIO CAROLINE", url = "http://radiocaroline.ice.infomaniak.ch/radiocaroline-128.mp3"},
    {name = "Radio Čapljina", url = "http://s8.iqstreaming.com:8016/"},
    {name = "Radio Feniks", url = "https://solid55.streamupsolutions.com/proxy/umzjpgrm/stream"},
    {name = "Radio Slon", url = "http://31.47.0.130:88/broadwavehigh.mp3"},
    {name = "Radio Studio 99 Sarajevo", url = "https://c2.radioboss.fm:18249/stream"},
    {name = "Pop FM Bosnia And Herzegovina", url = "http://188.40.62.20:8032/;stream.nsv"},
    {name = "Radio Brcko District", url = "http://91.191.0.45:8000/listen.pls"},
    {name = "Radio Postaja Odžak", url = "https://stream.rcast.net/70602"},
    {name = "Radio Bosanska Posavina", url = "http://78.46.64.6:7000/;"},
    {name = "Radio Posušje", url = "http://136.243.144.93:9994/"},
    {name = "Radio Bosanski Brod", url = "https://zpilipov-geckohost.radioca.st/stream"},
    {name = "Radio Olovo", url = "http://sonicpanel.vmakerhost.com:8038/stream"},
    {name = "Radio Trebinje", url = "https://radio.dukahosting.com:7002/"},
    {name = "Radio Džungla Doboj 3", url = "http://cast2.name.ba:8006/"},
    {name = "KUPRESKIRADIO", url = "https://ec2s.crolive.com.hr:1265/stream"},
    {name = "RADIO KISS KISELJAK", url = "http://stream.kissfm.ba:8010/live"},
    {name = "RADIO ZENICA", url = "http://stream.rtvze.ba:8000/stream"},
    {name = "RDV", url = "http://www.shoutcastunlimited.com:8892/stream/1/"},
    {name = "ROBOT HIT RADIO", url = "https://slusaj.off.ba/radio/8000/robot"},
    {name = "Radio 8 Sarajevo", url = "https://radio8-bhcloud.radioca.st/1.mp3"},
    {name = "Radioaktivan", url = "https://stream-152.zeno.fm/4qe0awx37wquv?zs=LaZXevHRRP2c8j2V0O-NOA"},
    {name = "Radio Glas Drine", url = "http://109.105.201.90:8028/;"},
    {name = "Radio Preporod Odzak 95,2", url = "http://s1.voscast.com:7986/;"},
    {name = "Megamix", url = "https://eu1.fastcast4u.com/proxy/megamix?mp=/1"},
    {name = "Narodni Radio Zenica", url = "http://server1.tnt.ba:9010/"},
    {name = "Radio Slobodna Evropa", url = "https://n11.radiojar.com/bugesa4nn3quv?rj-ttl=5&rj-tok=AAABihgJBEQA_ptijcBtD6_jYw"},
    {name = "Radio Zenit - Caffe", url = "http://5.189.168.133:8020/stream/2/;"},
    {name = "Radio Bihać Caffe", url = "http://5.9.13.39:8075/stream"},
    {name = "Radio Grude", url = "http://radio.pa-hosting.de:1040/"},
    {name = "RVK", url = "http://rvk2021.radioca.st:8206/stream"},
    {name = "Federalni RADIO", url = "https://s2.free-shoutcast.com/stream/18170"},
    {name = "Nes Radio", url = "http://188.40.62.20:8070/;"},
    {name = "Radio Donji Vakuf", url = "http://5.9.71.122:8134/;stream.mp3"},
    {name = "Radio ZENIT Zenica", url = "http://5.189.168.133:8020/1"},
    {name = "Radio Visoko", url = "http://188.40.62.20:8080/"},
    {name = "Radio Ljubuški", url = "https://s8.iqstreaming.com:8044/stream"},
    {name = "TNT Travnik", url = "http://server1.tnt.ba/proxy/tntradio?mp=/stream1"},
    {name = "RADIO VITEZ", url = "https://radio.iti.hr/listen/radio_vitez/radio.mp3"},
    {name = "Islamski Radio", url = "http://eu3.fastcast4u.com:5762/stream"},
    {name = "Radio Bihać", url = "http://radiobihaclive.radioca.st:8249/stream"},
}

return stations
