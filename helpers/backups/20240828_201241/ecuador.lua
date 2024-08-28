local stations = {
    {name = "Newstalk ZB Auckland", url = "https://ais-nzme.streamguys1.com/nz_002_aac"},
    {name = "Amazonas FM 921", url = "https://dattavolt.com/8346/stream"},
    {name = "Amena Radio", url = "https://srv.amenaradio.com.es/listen/amena-radio/stream"},
    {name = "Antena Uno 905", url = "https://dattavolt.com/8202/stream"},
    {name = "Area Deportiva", url = "https://cast.uncuartocomunicacion.com/listen/areadeportivafm/live"},
    {name = "Area Deportiva 993 FM", url = "https://radio.uncuartocomunicacion.com:8020/stream"},
    {name = "Armonica FM", url = "https://armonicafm.makrodigital.com:9570/stream"},
    {name = "ASTRO RADIO", url = "https://stream.zeno.fm/ewdz55ik9xftv"},
    {name = "Atenas FM 957", url = "https://stream.zeno.fm/grqrmw9ezs8uv"},
    {name = "Bahia Stereo 905 FM", url = "https://grupomundodigital.com:9310/stream"},
    {name = "Besame", url = "http://stream.zeno.fm/5xq756t2gchvv"},
    {name = "Café Radio 917 FM", url = "https://usa3.lhdserver.es:8139/stream"},
    {name = "Cañar Stereo 973 FM", url = "https://ecuamedios.net:10937/stream"},
    {name = "Católica Cuenca 981 FM", url = "https://radiohdstreaming.com/radio/8230/catolica"},
    {name = "Color Stereo 1053 FM", url = "https://cloudstream2032.conectarhosting.com/9470/;"},
    {name = "Cómplice FM 997 FM", url = "https://dattavolt.com/8422/stream"},
    {name = "Conecta 2 Radio", url = "https://radio.conecta2service.com/8060/stream"},
    {name = "Contigo Fm", url = "https://panel.innovatestream.pe:10852/stream"},
    {name = "Contigo FM 1049", url = "https://panel.innovatestream.pe:10852/;"},
    {name = "Corp Stereo 941", url = "http://stream.zeno.fm/rgbmruwhtuhvv"},
    {name = "Cuenca TV", url = "http://stream.zeno.fm/63eny6sypuhvv"},
    {name = "DIBLU FM 889", url = "https://streamingecuador.net:9002/stream"},
    {name = "Ecua Stereo Bohemia", url = "https://stream-069.zeno.fm/xlrqrx7wuwcvv"},
    {name = "Estelar Costa 931 FM", url = "https://sv70.ecuaradiotv.net:8000/estelarcosta"},
    {name = "Exa FM 925 Ecuador", url = "http://playerservices.streamtheworld.com/pls/ECUADORAAC.pls"},
    {name = "Exa FM Ibarra - 939 FM - Ibarra, Ecuador", url = "https://streamingecuador.net:7030/stream"},
    {name = "Expresiun FM 1029", url = "https://usa3.lhdserver.es:8031/stream"},
    {name = "Fabu 1057 FM", url = "https://alba-ec-fabu-fabuguayaquil.stream.mediatiquestream.com/chunks.m3u8"},
    {name = "Gualaceo Stereo 927", url = "https://stream.zeno.fm/s74szs5uquhvv"},
    {name = "HCJB La Voz De Los Andes 893 FM", url = "https://streamingecuador.net:8287/hcjb.m3u"},
    {name = "JC La Bruja", url = "http://s7.yesstreaming.net:8040/stream?1655753305283"},
    {name = "Jumbo Deep Radio", url = "http://stream.zeno.fm/juhqepbmmxqvv"},
    {name = "KCH FM Radio", url = "https://streamingecuador.net:7075/stream"},
    {name = "La 961 - Suprema Estacion", url = "https://dattavolt.com/8150/stream"},
    {name = "La Chismosa", url = "https://sp.dattavolt.com/8052/stream"},
    {name = "La Coquetisima Online", url = "http://stream.zeno.fm/529kmm15gv8uv"},
    {name = "LA CUMBRE RADIO", url = "https://stream.zeno.fm/bp7fnhwzo4bvv"},
    {name = "La Dinastia FM", url = "http://stream.zeno.fm/204egk2n5ehvv"},
    {name = "La M3G4", url = "http://gradio.net:8000/lam3g4"},
    {name = "La Main Street Radios Ecuador Online", url = "https://radiolatina.info/9930/stream"},
    {name = "La Mejor Radio - 1039 FM - HCRA - Ibarra, Ecuador", url = "https://streamingecuador.net:8214/lamejor"},
    {name = "La Radio Redonda 969 Quito", url = "https://laredondafm.makrodigital.com/stream/radiolaredondaquito"},
    {name = "La Radio Redonda 993 Guayaquil", url = "https://laredondafm.makrodigital.com/stream/radiolaredondaguayaquil"},
    {name = "La Radio Redonda Guayaquil", url = "https://laredondafm.makrodigital.com:9550/stream"},
    {name = "La Radio Redonda Quito - 969 FM", url = "http://laredondafm.makrodigital.com:9560/stream"},
    {name = "La Super Deportiva 917 Fm", url = "http://190.123.34.101:8001/stream"},
    {name = "La Tukka Ec", url = "http://grupomundodigital.com:8673/live"},
    {name = "La Victoria FM", url = "http://stream.zeno.fm/b3v617nkbrzuv"},
    {name = "La Voz De Los Caras 953 FM", url = "http://streaming.hdserver.biz:9368/listen.pls"},
    {name = "La Voz Del Tomebamba", url = "https://streamingecuador.com:8074/lavozdeltomebamba"},
    {name = "La Voz Del Tomebamba 1070 AM", url = "https://streamingecuador.net:8074/lavozdeltomebamba"},
    {name = "Los 40 Ecuador", url = "https://streamingecuador.com:7051/stream.m3u"},
    {name = "LV Radio Satelital FM", url = "http://stream.zeno.fm/ech627b6u18uv"},
    {name = "Mega St☆R", url = "http://stream.zeno.fm/4xcrps37zs8uv"},
    {name = "Mega St☆R Ecuador", url = "http://stream.zeno.fm/kc5hfz4aqs8uv"},
    {name = "Modelo 977 FM", url = "https://usa3.lhdserver.es:8197/stream"},
    {name = "Municipal 720 AM", url = "https://grupomundodigital.com:8588/live"},
    {name = "Municipal FM 1029", url = "https://grupomundodigital.com:8577/stream"},
    {name = "OE Radio - Ondas De Esperanza", url = "http://eu1.fastcast4u.com:10936/"},
    {name = "Oxigeno 1005 FM", url = "https://sonic.dattalive.com/8384/stream"},
    {name = "Pagma Stereo FM Alausi", url = "http://stream.zeno.fm/tqwu1sku9c0uv"},
    {name = "Play FM 953", url = "https://streamingecuador.net:8008/radioplayfm"},
    {name = "PM RADIO Quevedo", url = "https://as100.globalhost1.com/8010/stream"},
    {name = "RSN La Indestructible", url = "https://stream.zeno.fm/wahxwkbdaoduv"},
    {name = "Radio 11Q 1049 FM", url = "https://streamingecuador.net:8012/radio11q.m3u"},
    {name = "Radio Alegriafm", url = "https://cloudstream2032.conectarhosting.com/9376/;"},
    {name = "Radio América 1045 FM", url = "https://streamingecuador.com:7030/stream?1657848016283"},
    {name = "Radio Amiga", url = "http://190.57.161.179:8000/stream"},
    {name = "Radio Andina", url = "https://grupomundodigital.com:8580/stream"},
    {name = "Radio Antena 3 917 FM", url = "https://streamingecuador.net:9368/radioantena3.m3u"},
    {name = "RADIO ANTENA SUR 895FM LA Señal DE ORO DESDE PONCE ENRIQUEZ", url = "https://grupomundodigital.com:8504/antenashd"},
    {name = "Radio Armonía 1001 FM", url = "https://radiohdstreaming.com/radio/8040/armonia"},
    {name = "Radio Atenas", url = "http://stream.zeno.fm/63feuw9ezs8uv"},
    {name = "Radio Aventura 1071 FM", url = "http://streaming.hdserver.biz:9424/listen.pls"},
    {name = "RADIO BURBUJA BALZAR 895 FM", url = "https://stream.zeno.fm/1pdnsbf5w8ftv"},
    {name = "Radio Cadena Stereo 1071", url = "http://stream.zeno.fm/10g8v80ta2zuv"},
    {name = "Radio Cadena Stereo Country", url = "http://stream.zeno.fm/wyr2sxuito5vv"},
    {name = "RADIO CALIDA 1029 FM", url = "https://streamingecuador.com:7048/stream"},
    {name = "Radio Canela 1065 FM", url = "https://canelaradio.makrodigital.com/stream/canelaradiotungurahua"},
    {name = "Radio Canela Azuay 1073 FM", url = "https://canelaradio.makrodigital.com/stream/canelaradiocuenca"},
    {name = "Radio Canela Chimborazo 945 FM", url = "https://canelaradio.makrodigital.com/stream/canelaradiochimborazo"},
    {name = "Radio Canela El Oro 1007 FM", url = "https://canelaradio.makrodigital.com/stream/canelaradiomachala"},
    {name = "Radio Canela Guayas", url = "https://canelaradio.makrodigital.com/stream/canelaradioguayaquil"},
    {name = "Radio Canela Imbabura 927 FM", url = "https://canelaradio.makrodigital.com/stream/canelaradioibarra"},
    {name = "Radio Canela Loja 969 - 989 FM", url = "https://canelaradio.makrodigital.com/stream/canelaloja"},
    {name = "Radio Canela Manabí 1025 FM", url = "https://canelaradio.makrodigital.com/stream/canelaradiomanabi"},
    {name = "Radio Canela Morona Santiago 917 FM", url = "https://canelaradio.makrodigital.com/stream/canelaradiomacas"},
    {name = "Radio Canela Napo 1061 FM", url = "https://canelaradio.makrodigital.com/stream/canelaradionapo"},
    {name = "Radio Canela Pichincha", url = "https://ecuadorstreaming.net:9280/stream"},
    {name = "Radio Canela Sucumbíos 945 FM", url = "https://canelaradio.makrodigital.com:9230//stream"},
    {name = "Radio Centro 1013 FM", url = "https://streamingecuador.com:7046/stream"},
    {name = "Radio Coqueta 965 FM", url = "http://cloudstream2032.conectarhosting.com:8214/;"},
    {name = "Radio Corazón De Jesús FM", url = "http://stream.zeno.fm/cu68600hswzuv"},
    {name = "Radio Cristal 870 AM", url = "https://streaming.ecuastreaming.com/9958/stream"},
    {name = "RADIO ECOS DE RUMIÑAHUI 889 FM", url = "https://streamingecuador.com:9040/stream"},
    {name = "Radio Elite 997 FM", url = "https://streamingecuador.net:8135/radioelite"},
    {name = "RADIO ESTELAR 1065 FM", url = "https://dattavolt.com/8152/stream"},
    {name = "Radio Evolución", url = "https://stream.gradio.net/evolucion"},
    {name = "Radio Fuego 1065 FM", url = "https://streamingecuador.net:8005/radiofuego.m3u"},
    {name = "Radio Gaviota 1051 FM", url = "https://streamingecuador.net:9000/radiogaviota.m3u"},
    {name = "Radio Gitana 949 FM", url = "https://s7.yesstreaming.net:8078/live"},
    {name = "Radio HCJB German", url = "http://segenswelle.de:8000/hcjb"},
    {name = "Radio HCJB German 32Kbps", url = "http://segenswelle.de:8000/hcjb-aac"},
    {name = "RADIO IMPACTO 1079", url = "https://cast.uncuartocomunicacion.com/listen/radioimpacto/live"},
    {name = "Radio La Metro Stereo", url = "https://alba-ec-lametro-lametro.stream.mediatiquestream.com/chunks.m3u8"},
    {name = "Radio La Otra - 913 FM", url = "https://laotrafm.makrodigital.com/stream/laotrafmquito"},
    {name = "Radio La Red 1021 FM", url = "https://icecast.radiolared.com.ec/radiolared"},
    {name = "Radio La Voz Del Tambo", url = "https://server.efrasystem.com:7068/live"},
    {name = "Radio Lío", url = "https://usa3.lhdserver.es:8259/stream"},
    {name = "Radio Mágica 877 Ecuador", url = "https://usa10.fastcast4u.com:1680/;?type=http&nocache=1683302387"},
    {name = "Radio Magica 877 Ecuador", url = "http://usa10.fastcast4u.com:1680/"},
    {name = "Radio Makro Digital", url = "http://streamingecuador.net:7000/stream"},
    {name = "Radio Marejada 1009 FM", url = "http://streaming.hdserver.biz:9330/listen.pls"},
    {name = "Radio Maria Cuenca", url = "http://radioserver11.profesionalhosting.com:9069/stream"},
    {name = "RADIO MARIA ECUADOR", url = "http://dreamsiteradiocp4.com:8010/stream"},
    {name = "Radio Mokawa 939 FM", url = "http://stream.hdserver.biz:9474/listen.pls"},
    {name = "Radio Nexo", url = "http://stream.zeno.fm/xvyq4g94fchvv"},
    {name = "Radio Nuevo Tiempo 921 FM", url = "http://stream.live.novotempo.com/radio/smil:rntQuitoEC.smil/playlist.m3u8"},
    {name = "Radio Olímpica 963 FM", url = "http://stream.hdserver.biz:9320/stream"},
    {name = "Radio Onda Positiva 941 FM", url = "https://streamingecuador.net:8011/radioondapositiva.m3u"},
    {name = "Radio Pasion", url = "http://streamingecuador.net:7500/stream"},
    {name = "Radio Pichincha Universal", url = "https://icecast.radiopichincha.com/radiopichincha"},
    {name = "Radio Platinum Fm", url = "https://streamingecuador.com:8160/radioplatinum"},
    {name = "Radio Popular 1230 AM", url = "http://stream-50.zeno.fm/py6f6znfntzuv?zs=noiOyzMaTqWxs_wNcfkWgg&1679303614411"},
    {name = "Radio Públicafm", url = "https://comep.radioca.st/stream"},
    {name = "Radio Punto Rojo 897 FM", url = "https://streamingecuador.net:9086/stream.m3u"},
    {name = "Radio Quito 760 AM", url = "https://streamingecuador.net:8332/radioquito?1679294453918"},
    {name = "Radio Romance 901 FM", url = "https://streamingecuador.net:9090/stream.m3u"},
    {name = "Radio Rumba", url = "https://streamingecuador.net:8078/radiorumbanetwork"},
    {name = "Radio Samantha 893 FM", url = "http://5.135.183.124:8153/stream.m3u"},
    {name = "Radio San Miguel 957 FM", url = "https://sonicpanel.cloudstreaming.eu/8126/stream"},
    {name = "Radio Scandalo 1037 FM", url = "http://str.manaideas.com:8000/;stream.mp3"},
    {name = "Radio Señal Pirata", url = "https://radios.sonidoshd.com/8222/stream"},
    {name = "Radio Son De Manta 933 FM", url = "http://grupomundodigital.com:8649/live.m3u"},
    {name = "Radio Sonoonda 997 FM", url = "http://5.135.183.124:8040/stream.m3u"},
    {name = "Radio Sucumbíos 1053 FM", url = "http://aler.org:8000/radiosucumbios.mp3"},
    {name = "Radio Super Sol", url = "http://streamingecuador.com:8002/radiosupersol"},
    {name = "Radio Super Sol - 963 FM", url = "https://streamingecuador.com:8002/radiosupersol"},
    {name = "Radio Tambo Mix", url = "https://stream.zeno.fm/gey7t9er11zuv"},
    {name = "RADIO TURBO", url = "https://streamingecuador.com/stream/radioturboambato"},
    {name = "Radio Ultimito Mix", url = "https://usa4.fastcast4u.com/proxy/rwrw1?mp=/1"},
    {name = "RADIO VALLE FM", url = "http://stream.zeno.fm/veu31437sm0uv"},
    {name = "Radio Vigia Fm", url = "https://streamingecuador.com:9070/radiovigia"},
    {name = "Radio Xtrema FM", url = "https://s1.raudiostream.com:8004/stream"},
    {name = "Radio Zaracay 1005 FM", url = "http://stream-36.zeno.fm/as3xhhc0ts8uv?_=1"},
    {name = "RCN CATOLICA NACIONAL", url = "https://dattavolt.com/8358/stream"},
    {name = "RCS Manabi Stereo", url = "http://stream.zeno.fm/esda9vaw438uv"},
    {name = "RCS Chimborazo Stereo", url = "http://stream.zeno.fm/epr9867v438uv"},
    {name = "RCS El Oro Stereo", url = "http://stream.zeno.fm/v4bvybbw438uv"},
    {name = "RCS Guayas Stereo", url = "http://stream.zeno.fm/75b5ah2v438uv"},
    {name = "RCS Imbabura Stereo", url = "http://stream.zeno.fm/kewgx19v438uv"},
    {name = "RCS Mix", url = "http://stream.zeno.fm/17qka9nun2zuv"},
    {name = "RCS Morona Santiago Stereo", url = "http://stream.zeno.fm/2r6uvhcw438uv"},
    {name = "RCS Noticias", url = "http://stream.zeno.fm/mz04b1exz08uv"},
    {name = "RCS Orellana Stereo", url = "http://stream.zeno.fm/pb4351gw438uv"},
    {name = "RCS Quito Stereo", url = "http://stream.zeno.fm/p6dy80yt6s8uv"},
    {name = "Retro Music By Pelambre Records", url = "http://streamingecuador.net:9300/stream"},
    {name = "RNC La Mundialista 1033 FM AAC", url = "https://streamingecuador.net:7008/radiornc.m3u"},
    {name = "RTP 965 FM", url = "https://streamingecuador.net:8167/radiotropicana"},
    {name = "RVT Satelital 915 FM", url = "http://209.208.111.122:8000/rvtpeninsula"},
    {name = "San Fernando FM", url = "http://stream.zeno.fm/gqn5xf0fd18uv"},
    {name = "Somos Radio Familia 969", url = "https://cloudstream2030.conectarhosting.com/8206/;"},
    {name = "Super 949", url = "https://dattavolt.com/8028/stream"},
    {name = "Tambo Stereo FM", url = "http://stream.zeno.fm/uqwrvvpvhm0uv"},
    {name = "Tres Patines", url = "https://ssl.nexuscast.com:8043/;"},
    {name = "Tu Voz Stereo", url = "http://stream.zeno.fm/zy7aqxp4q98uv"},
    {name = "Turbo Imparable", url = "http://sonic.portalfoxmix.cl:8394/stream/;"},
    {name = "UTC Radio FM", url = "https://radio.cedia.org.ec/utc-radio"},
    {name = "Virgen De Guadalupe Radio", url = "http://stream.zeno.fm/9f0rk1re508uv"},
}

return stations