local stations = {
    {name = "1009 Play FM", url = "https://mdstrm.com/audio/5c8d6406f98fbf269f57c82c/icecast.audio"},
    {name = "80Sflashback Radio", url = "https://c23.radioboss.fm:8129/stream"},
    {name = "Activa", url = "http://provisioning.streamtheworld.com/pls/ACTIVA.pls"},
    {name = "Almeyda", url = "https://sonic.streamingchilenos.com/9974/stream.aac"},
    {name = "Alta Fidelidad Radio", url = "https://s21.myradiostream.com/14464/;?type=http&nocache=1724080980?0.022147003328686576"},
    {name = "BEAT FM - La Radio Que Te Mueve - Valle Aconcagua 987", url = "https://audio.streaminghd.cl:2000/stream/beatfm-sanfelipe"},
    {name = "Beethoven - Santiago FM", url = "https://unlimited4-us.dps.live/beethovenfm/aac/icecast.audio"},
    {name = "Blaster Radio", url = "https://s2.mkservers.space/blaster"},
    {name = "BLUFM", url = "https://sonic.nnw.cl:7009/;"},
    {name = "Bonita", url = "https://sonicpanel.chileservidores.cl/8032/stream"},
    {name = "Bío-Bío Concepción 981", url = "https://unlimited3-cl.dps.live/biobioconcepcion/aac/icecast.audio"},
    {name = "Carabineros De Chile Radio", url = "https://sonic01.instainternet.com/8374/stream"},
    {name = "Cobrox Radio", url = "http://65.108.120.179:8672/cobroxradio"},
    {name = "Concierto", url = "http://provisioning.streamtheworld.com/pls/CONCIERTO.pls"},
    {name = "Conexion Radio", url = "https://tunein.radiomaniacos.cl/conexionradio"},
    {name = "Corazon", url = "http://provisioning.streamtheworld.com/pls/CORAZON.pls"},
    {name = "Código Metal Radio", url = "https://streaming.viphosting.cl/8012/stream"},
    {name = "De Culto Radio", url = "https://ascl.denial.cl:8014/stream"},
    {name = "Diferencia FM 893", url = "https://sonic-cl.streaming-chile.com/8092/stream"},
    {name = "En La Noticia Radio 1011 FM", url = "http://streaming.chiloestreaming.com:9920/;"},
    {name = "Europa Beat", url = "https://s4.radio.co/s13e4f2090/listen"},
    {name = "Exa FM", url = "https://playerservices.streamtheworld.com/api/livestream-redirect/XHPSFMAAC.aac"},
    {name = "Fanatica CHILL", url = "http://ascl.denial.cl:8004/"},
    {name = "Fanatica DANCE", url = "http://ascl.denial.cl:8030/"},
    {name = "Fanatica INDIE", url = "http://ascl.denial.cl:8008/"},
    {name = "Fanatica POP", url = "http://ascl.denial.cl:8010/"},
    {name = "Fanática UNO", url = "http://ascl.denial.cl:8042/;"},
    {name = "FM Okey", url = "https://streaming.fmokey.cl/moviles.mp3"},
    {name = "FM Siete Rock", url = "https://sp1.streamingssl.com/8036/stream"},
    {name = "Frecuencia Rock 953", url = "http://audio.streaminghd.cl:9206/stream"},
    {name = "Futuro", url = "http://provisioning.streamtheworld.com/pls/FUTUROAAC.pls"},
    {name = "Gothic Metal Radio Chile", url = "http://209.126.107.182:8298/stream"},
    {name = "Imagina", url = "http://provisioning.streamtheworld.com/pls/imagina.pls"},
    {name = "Insular FM", url = "https://sonic-us.streaming-chile.com:7023/live"},
    {name = "Isadora", url = "https://streaming.comunicacioneschile.net/9326/stream.aac"},
    {name = "Isla Negra", url = "https://radioislanegra.org/radio/8000/basic.aac"},
    {name = "Isla Negra Slowbeat", url = "https://radioislanegra.org/radio/8010/basic.aac"},
    {name = "Isla Negra Upbeat", url = "https://radioislanegra.org/radio/8030/basic.aac"},
    {name = "La Mega Fm", url = "https://sonic.portalfoxmix.club/8478/stream"},
    {name = "La Melinkana FM", url = "https://audio3.tustreaming.cl/7050/stream"},
    {name = "La Mexicana 953 San Vicente", url = "http://audio0.tustreaming.cl:7160/aire"},
    {name = "La Mexicana Chile", url = "https://audio0.tustreaming.cl/7170/casablanca"},
    {name = "La Más Kaliente", url = "https://audio1stream.com/8002/stream"},
    {name = "La Retro 80S Chile", url = "https://s2.radio.co:80/s9ecef4f68/listen"},
    {name = "Laretro", url = "http://s2.radio.co/s9ecef4f68/listen.m3u"},
    {name = "Libelulachilecom Señal 1", url = "https://streaming.viphosting.cl:7138/;"},
    {name = "Libelulachilecom Señal 4 Tangos Y Algo Más", url = "https://streaming.viphosting.cl:7126/;"},
    {name = "Los 40 Principales Chile", url = "http://provisioning.streamtheworld.com/pls/LOS40_CHILE.pls"},
    {name = "Maray", url = "https://video.mediawebchile.com:2000/stream/8212/stream"},
    {name = "María", url = "http://dreamsiteradiocp4.com:8024/"},
    {name = "Mi Radio", url = "https://audio1.tustreaming.cl/9020/stream"},
    {name = "Musicoop", url = "https://sonic.portalfoxmix.club/8486/stream"},
    {name = "Oceano FM La Serena Y Coquimbo", url = "https://audio2.tustreaming.cl/9025/stream"},
    {name = "Positiva", url = "https://unlimited4-us.dps.live/positiva/aac/icecast.audio"},
    {name = "Pudahuel", url = "http://provisioning.streamtheworld.com/pls/PUDAHUEL.pls"},
    {name = "Radio Agricultura", url = "http://unlimited4-us.dps.live/agricultura/mp3/icecast.audio?"},
    {name = "Radio Alegría Del Transporte 907 FM", url = "http://streaming01.xhost.cl/8048/;"},
    {name = "Radio Amistad 1019 FM", url = "https://audio.jcrdmedia.com/8018/stream"},
    {name = "Radio Arcoiris FM 993", url = "https://audio2.tustreaming.cl/7210/stream"},
    {name = "Radio BBN", url = "https://audio-edge-es6pf.mia.g.radiomast.io/475ebed1-595e-4717-b888-64fe8fc6b09f"},
    {name = "Radio Beethoven FM", url = "http://unlimited4-us.dps.live/beethovenfm/aac/icecast.audio"},
    {name = "Radio Bio Bio", url = "https://unlimited3-cl.dps.live/biobiosantiago/mp3/icecast.audio"},
    {name = "Radio Bio Bio Temuco", url = "https://unlimited3-cl.dps.live/biobiotemuco/aac/icecast.audio"},
    {name = "Radio Bio-Bio Puerto Montt", url = "https://unlimited3-cl.dps.live/biobiopuertomontt/mp3/icecast.audio"},
    {name = "Radio Canina", url = "https://mdstrm.com/audio/601de1cd07ba40129dbcd35e/icecast.audio"},
    {name = "Radio Caramelo 913 FM", url = "https://audio5.tustreaming.cl/8004/stream"},
    {name = "Radio Caribe FM 955", url = "http://149.56.241.149:8118/stream"},
    {name = "RADIO CARICIA FM", url = "https://sonic.portalfoxmix.club/8244/stream/"},
    {name = "Radio Centro Cristiano", url = "https://vivo.miradio.in:7008/"},
    {name = "Radio Club 80", url = "https://stream.radioclub80.cl:8002/clasicos80.mp3"},
    {name = "Radio Club 80 Euro FLAC", url = "https://stream.radioclub80.cl:8032/stream.euro80flac"},
    {name = "Radio Club 80 Movie Sound FLAC", url = "https://stream.radioclub80.cl:8072/peliculas80.flac"},
    {name = "Radio Club 80 Trance FLAC", url = "https://stream.radioclub80.cl:8052/trance80.flac"},
    {name = "Radio Cobremar - Chañaral FM 899", url = "https://audio.bitsur.cl/8066/stream"},
    {name = "Radio Colocolo", url = "https://audio2.tustreaming.cl:10997/stream"},
    {name = "Radio Contigo", url = "http://streaming.comunicacioneschile.net:9318/stream"},
    {name = "RADIO COOPERATIVA", url = "https://unlimited3-cl.dps.live/cooperativafm/mp3/icecast.audio"},
    {name = "Radio Crystal Petorca 1023 FM", url = "https://stm2.srvif.com:8024/stream"},
    {name = "Radio Cómplices", url = "https://streaming.comunicacioneschile.net:7007/;"},
    {name = "Radio Definitiva", url = "http://192.198.83.230:8772/;"},
    {name = "Radio Dixi 1069 FM", url = "https://sonic.portalfoxmix.cl/9940/stream"},
    {name = "Radio Dulce LLAY-LLAY 1019 FM", url = "http://200.24.229.253:8240/stream/9/;"},
    {name = "Radio Edelweiss", url = "https://audio.bitsur.cl:8018/stream"},
    {name = "Radio El Carbon", url = "https://unlimited11-cl.dps.live/elcarbon/aac/icecast.audio"},
    {name = "Radio El Conquistador FM Santiago", url = "https://stream10.usastreams.com/9314/stream/"},
    {name = "RADIO EL LOA 1011 FM", url = "http://us9.maindigitalstream.com:7258/stream"},
    {name = "Radio Estacion Del Poder", url = "http://stream.zeno.fm/t7cdutykw38uv.m3u"},
    {name = "Radio Estrella Del Norte", url = "http://sonic.portalfoxmix.cl:8424/;"},
    {name = "Radio Exquisita FM", url = "http://ascl.denial.cl:8002/stream"},
    {name = "Radio FM Centro 917", url = "https://s02.azuracast.cl/radio/8210/fmcentro"},
    {name = "Radio Gatuna", url = "https://mdstrm.com/audio/611d9db704b775082811559e/icecast.audio"},
    {name = "Radio Guayacán", url = "https://sonic.mallocohosting.cl/8038/stream"},
    {name = "Radio Iglesia Cristiana La Serena", url = "https://servidor32.brlogic.com:7050/live"},
    {name = "RADIO ISLA ONLINE", url = "https://sp.totalstreaming.net:8018/stream"},
    {name = "Radio Las Nieves", url = "https://audio2.tustreaming.cl:10987/stream"},
    {name = "Radio Lautaro Talca", url = "https://audio2.tustreaming.cl/7320/stream"},
    {name = "RADIO MARIA CHILE", url = "http://dreamsiteradiocp.com:8066/stream"},
    {name = "Radio Maria FM Linares", url = "https://audioradio.cl/8006/stream"},
    {name = "RADIO MAXIMA FM VALPARAISO 969 - Fono+51-925691328", url = "https://servermax2.azuracast.com.es/listen/maximafm/radio.mp3"},
    {name = "Radio Nativa FM", url = "https://stm3.srvif.com:8090/listen.pls"},
    {name = "Radio Nostalgica", url = "https://unlimited5-us.dps.live/nostalgica/aac/icecast.audio"},
    {name = "Radio Nuble 897 Fm", url = "http://streaming.comunicacioneschile.net:9358/;"},
    {name = "Radio Nuevo Mundo Ovalle", url = "http://192.99.16.17:8102/stream"},
    {name = "RADIO NUEVO S CHILOE FM", url = "http://stream.zeno.fm/nzk58p79b9quv.pls"},
    {name = "Radio Paloma", url = "https://audio3.tustreaming.cl/7320/stream"},
    {name = "Radio Paula FM - 1037 Mhz - Laja HD", url = "http://escucha.radiopaulafm.com/"},
    {name = "RADIO PAULINA", url = "https://sp1.streamingssl.com/8058/stream"},
    {name = "Radio Picarona", url = "https://sonic.portalfoxmix.cl:7045/;"},
    {name = "Radio Polarisima", url = "http://cdn1.onstream.audio:8085/autodj"},
    {name = "Radio Pudahuel", url = "https://26653.live.streamtheworld.com/PUDAHUEL_SC"},
    {name = "Radio Rapel", url = "https://sonic.globalstreaming.net/8268/;"},
    {name = "Radio Rara", url = "http://190.3.169.87:9952/;"},
    {name = "Radio Retro Online", url = "https://sonic.streamingchilenos.com/8138/stream"},
    {name = "Radio RTL", url = "http://radio.mediadev.cl:8090/rtl_curico"},
    {name = "RADIO SANFURGO", url = "http://176.31.241.17:7112/"},
    {name = "Radio Sol 977", url = "https://us9.maindigitalstream.com/ssl/7389"},
    {name = "Radio Sol Classic", url = "https://us9.maindigitalstream.com/ssl/radiosol"},
    {name = "Radio Udec", url = "https://audio.divalstream.com:7019/stream"},
    {name = "Radio Universidad De Chile", url = "https://sonic-us.streaming-chile.com/8186/stream"},
    {name = "Radio Vale FM CHILE", url = "https://sp1.streamingssl.com/8056/stream"},
    {name = "Radio Violeta - La Música De Ayer Y Hoy Las 24 Hd", url = "https://server01.heplayer.com/9390/stream"},
    {name = "Radioactiva", url = "http://playerservices.streamtheworld.com/m3u/ACTIVA.m3u"},
    {name = "Radioactiva 925 FM", url = "http://playerservices.streamtheworld.com/m3u/ACTIVAAAC.m3u"},
    {name = "Radiomenap Chile", url = "https://sonicpanel.streaming10.net/8008/stream"},
    {name = "Radiomix", url = "https://video.mediawebchile.com:2000/stream/radiomixsc/stream"},
    {name = "Ritmo FM", url = "https://sonic.portalfoxmix.cl/9976/stream"},
    {name = "Rock And Pop", url = "http://playerservices.streamtheworld.com/m3u/ROCK_AND_POPAAC.m3u"},
    {name = "Rock Pop M", url = "http://provisioning.streamtheworld.com/pls/ROCK_AND_POP.pls"},
    {name = "Rockpop Chile", url = "https://playerservices.streamtheworld.com/api/livestream-redirect/ROCK_AND_POPAAC_SC"},
    {name = "Sintonizados Con Cristo Radio - IMPCH San Miguel", url = "https://audio.streaminghd.cl:9130/live"},
    {name = "Sonar 1053 FM", url = "https://mdstrm.com/audio/5c915724519bce27671c4d15/icecast.audio?property=radiobox"},
    {name = "Sunrise", url = "https://sonic-cl.streaming-chile.com/8044/stream"},
    {name = "Sunrise Dance", url = "https://sonic-cl.streaming-chile.com/8054/stream"},
    {name = "Sunrise Lounge", url = "https://sonic-cl.streaming-chile.com/8098/stream"},
    {name = "Super45Fm", url = "https://s4.radio.co/s421105570/listen"},
    {name = "Vilas Radio 1001", url = "https://sonic.streamingchilenos.com/8072/stream"},
    {name = "Vilas Radio 981", url = "https://sonic.portalfoxmix.club/8042/stream"},
}

return stations
