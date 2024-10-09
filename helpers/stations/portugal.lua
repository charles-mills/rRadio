local stations = {
    {name = "RFM", url = "https://23603.live.streamtheworld.com/RFMAAC.aac"},
    {name = "Radio Comercial Portugal", url = "https://stream-icy.bauermedia.pt/comercial.mp3"},
    {name = "ORBITAL", url = "http://centova.radios.pt:8401/;listen.pls"},
    {name = "Rádio Observador", url = "http://195.23.85.126:8455/listen.pls?sid=1"},
    {name = "Rádio Renascença", url = "http://provisioning.streamtheworld.com/pls/RADIO_RENASCENCA.pls"},
    {name = "M80 Rádio", url = "http://stream-icy.bauermedia.pt/m80.mp3"},
    {name = "Mega Hits", url = "http://provisioning.streamtheworld.com/pls/mega_hits.pls"},
    {name = "M80 Rádio – 80S", url = "https://stream-icy.bauermedia.pt/m8080.aac"},
    {name = "M80 Rádio – Ballads", url = "https://stream-icy.bauermedia.pt/m80ballads.aac"},
    {name = "M80 Rádio – 60S", url = "https://stream-icy.bauermedia.pt/m8060.aac"},
    {name = "Deep In Radio", url = "http://s3.viastreaming.net:8525/"},
    {name = "4Drive Jazz", url = "http://radio.streemlion.com:1150/stream"},
    {name = "Rádio Amália", url = "http://centova.radio.com.pt:9496/;"},
    {name = "The VIBE - Dancefloor Radio", url = "http://109.71.41.6:8046/stream"},
    {name = "Antena 1 Fado", url = "http://radiocast.rtp.pt/antena1fado80a.mp3"},
    {name = "M80 Rádio – Dance", url = "https://stream-icy.bauermedia.pt/m80dance.aac"},
    {name = "M80 Rádio – Pop", url = "https://stream-icy.bauermedia.pt/m80pop.aac"},
    {name = "Oceano Pacífico", url = "https://25533.live.streamtheworld.com/OCEANPACIFICAAC.aac"},
    {name = "Rádio CAPSAO", url = "http://capsaolisboa.ice.infomaniak.ch/capsaolisboa-128.mp3"},
    {name = "Rádio Marginal", url = "http://centova.radio.com.pt:8499/;"},
    {name = "1054 Cascais - O Rock Da Linha", url = "https://play.radioregional.pt:8220/stream/2/;;/stream.mp3"},
    {name = "Antena 3 - Main", url = "https://radiocast.rtp.pt/antena380a.mp3"},
    {name = "Smooth FM AAC", url = "https://stream-icy.bauermedia.pt/smooth.aac"},
    {name = "Rádio Nova 989 FM", url = "http://centova.radio.com.pt:9528/"},
    {name = "Wonder 80'S", url = "https://80.streeemer.com/listen/80s/radio.mp3"},
    {name = "M80 Rádio – Rock", url = "https://stream-icy.bauermedia.pt/m80rock.aac"},
    {name = "FUTURA - Rádio De Autor", url = "https://s4.radio.co/s7e7b6c165/listen"},
    {name = "Antenna 2 Opera", url = "http://radiocast.rtp.pt/antena2opera80a.mp3"},
    {name = "Rádio Comercial Kids", url = "https://stream-icy.bauermedia.pt/rckids.aac"},
    {name = "Golofm", url = "https://sp0.redeaudio.com/8154/stream"},
    {name = "Raphip Hop", url = "http://185.32.188.17:8097/stream"},
    {name = "Rádio Festival", url = "http://centova.radios.pt:9520/;"},
    {name = "TOP 80 - Todos Os Exitos De 80 A 2000", url = "http://live.top80.fm:8086/"},
    {name = "Rádio Festival Madeira 984 FM", url = "https://audio.serv.pt/8012/stream.mp3"},
    {name = "Radio Fado De Coimbra", url = "https://nl.digitalrm.pt:8048/stream"},
    {name = "Superfm", url = "https://play.radioregional.pt:8210/stream/2/;/stream.mp3"},
    {name = "Rádio Comercial Dance", url = "https://stream-icy.bauermedia.pt/rcdance.aac"},
    {name = "M80 Rádio – Portugal", url = "https://stream-icy.bauermedia.pt/m80nacional.aac"},
    {name = "SBSRFM", url = "http://centova.radio.com.pt:8435/"},
    {name = "Tropical FM 953", url = "https://solid24.streamupsolutions.com/proxy/dcofieen?mp=/stream"},
    {name = "Rádio Nova", url = "http://centova.radios.pt:9528/;"},
    {name = "Orbital Rádio", url = "http://centova.radios.pt:8401/;"},
    {name = "4DJ 4Drive Jazz", url = "https://radio.streemlion.com:4870/stream"},
    {name = "Rádio Freguesia De Belém", url = "https://s2.radio.co/s0ddea4a53/listen"},
    {name = "Rádio Planície 928 Moura", url = "http://109.71.41.6:8026/stream"},
    {name = "Rádio Nova Era", url = "http://centova.radio.com.pt:9478/"},
    {name = "M80 Rádio AAC", url = "https://stream-icy.bauermedia.pt/m80.aac"},
    {name = "ABC Portugal", url = "http://centova.radio.com.pt:8547/;"},
    {name = "Radio Orbital", url = "https://centova.radio.com.pt/proxy/401?mp=/stream"},
    {name = "M80 Rádio – 90S", url = "https://stream-icy.bauermedia.pt/m8090.aac"},
    {name = "Radio Maria Portugal", url = "https://dreamsiteradiocp5.com/proxy/rmportugal1?mp=/stream"},
    {name = "MRR Manitu Rock Radio", url = "https://radio.streemlion.com:4515/stream"},
    {name = "Radio 94 FM", url = "http://185.11.164.106:35022/stream"},
    {name = "Rádio XL", url = "https://radios.justweb.pt/8002/stream"},
    {name = "Rádio Noar", url = "https://radios.justweb.pt/8034/stream"},
    {name = "M80 Rádio – 70S", url = "https://stream-icy.bauermedia.pt/m8070.aac"},
    {name = "RES FM", url = "http://stream2.soundflux.eu:8440/stream"},
    {name = "Geice FM", url = "https://ec2.yesstreaming.net:3275/stream"},
    {name = "Rádio Mega FM - Portugal", url = "https://ssls.stmxp.net:5878/1"},
    {name = "Rádio Lafões FM", url = "https://sp0.redeaudio.com/9304/stream"},
    {name = "Rádio Cidade Hoje", url = "http://centova.radio.com.pt:8119/;"},
    {name = "Rádio Festival Do Norte", url = "http://centova.radio.com.pt:9520/;"},
    {name = "Hiper FM", url = "http://195.23.85.126:9500/;"},
    {name = "Rádio Santiago", url = "http://eu6.fastcast4u.com:5002/stream"},
    {name = "94FM Leiria", url = "http://185.11.164.106:35022/stream?type=mp3"},
    {name = "Radio FM", url = "http://playerservices.streamtheworld.com/api/livestream-redirect/RFM.mp3"},
    {name = "Rádio Clube Foz Do Mondego", url = "http://nl.digitalrm.pt:8216/stream"},
    {name = "Rádio Quântica", url = "http://stream2.radioquantica.com:8000/stream"},
    {name = "Rádio Vida FM 971", url = "http://centova.radio.com.pt:9482/;"},
    {name = "Radio Tuganet", url = "https://ssl.stmxp.net:8006/;"},
    {name = "Emissora Das Beiras", url = "http://centova.radio.com.pt:8465/;"},
    {name = "Posto Emissor Do Funchal OM", url = "https://centova.radio.com.pt/proxy/422?mp=/stream;"},
    {name = "Rádio Terra Nova", url = "http://centova.radio.com.pt:9404/;"},
    {name = "Radio Cantinho Da Madeira", url = "http://109.71.41.6:8129/stream"},
    {name = "Rádio MEO Music", url = "http://centova.radio.com.pt:8495/;"},
    {name = "Smoothfm Soul", url = "https://stream-icy.bauermedia.pt/smoothsoul.aac"},
    {name = "80ROCK", url = "http://rs2.ptservidor.com:8003/stream?type=.mp3"},
    {name = "Radio Valdevez", url = "https://centova.radio.com.pt/proxy/508?mp=/stream"},
    {name = "Novecinco3Cinco", url = "https://centova.radio.com.pt/proxy/522?mp=/stream&1715267171"},
    {name = "Terranova 105", url = "http://centova.radios.pt/proxy/404?mp=/stream"},
    {name = "Rádio Barcelos", url = "http://centova.radio.com.pt:8563/;"},
    {name = "Radio Comercial Rock", url = "https://stream-icy.bauermedia.pt/rcrock.aac"},
    {name = "Posto Emissor Do Funchal FM", url = "http://centova.radio.com.pt:9426/;"},
    {name = "Rádio Clube Da Feira", url = "http://centova.radio.com.pt:9544/;"},
    {name = "Singa FM", url = "http://centova.radio.com.pt:8487/;"},
    {name = "Radio Nova", url = "http://centova.radios.pt:9528/"},
    {name = "Posto Emissor Do Funchal Canal 1 - OM", url = "http://centova.radio.com.pt:9422/"},
    {name = "Rádio Voz De Santo Tirso", url = "https://radios.justweb.pt/8024/stream?type=http&nocache=246"},
    {name = "Antena 1 - Main", url = "https://radiocast.rtp.pt/antena180a.mp3"},
    {name = "M80 Rádio – Indie", url = "https://stream-icy.bauermedia.pt/m80indie.aac"},
    {name = "M80 Rádio – Soul", url = "https://stream-icy.bauermedia.pt/m80soul.aac"},
    {name = "Jovembsk", url = "https://stream-54.zeno.fm/ppgb4k7vhqztv?zs=16hfH25BROGMPgJQytuZKg"},
    {name = "Radio Linear", url = "http://nl.digitalrm.pt:8184/stream"},
    {name = "Basspoint FM", url = "http://cast.evsportugal.com:8014/autodj"},
    {name = "Cantinho Dos Emigrantes", url = "https://cast.redewt.net:9825/stream"},
    {name = "Orbital FM", url = "https://ec2.yesstreaming.net:3025/stream"},
    {name = "La French Radio Portugal", url = "https://www.radioking.com/play/lfr-portugal"},
    {name = "M 80 Rádio", url = "https://stream-icy.bauermedia.pt/m80.mp3"},
    {name = "Rádio SBSR", url = "http://centova.radios.pt:8435/;"},
    {name = "Rádio Baía", url = "https://streamingv2.shoutcast.com/observador_64.aac"},
    {name = "Radar", url = "http://proic1.evspt.com/radar_mp3"},
    {name = "RUA FM", url = "https://centova.radio.com.pt/proxy/037?mp=/stream"},
    {name = "Monsanto", url = "https://s9.yesstreaming.net:9029/"},
    {name = "Rádio Altitude FM", url = "http://centova.radios.pt:9034/;"},
    {name = "Radio Nostalgia Lisboa", url = "http://online-radio.eu/export/winamp/27495-radio-nostalgia-lisboa"},
    {name = "922 KFM", url = "https://s9.yesstreaming.net:9012/stream"},
    {name = "Jovembsk Mix", url = "http://stream.zeno.fm/4nc1mzdp81xuv"},
    {name = "Rádio Montalegre", url = "http://centova.radio.com.pt:9566/;"},
    {name = "RUC Rádio Universidade De Coimbra", url = "https://stream.ruc.pt/high.m3u"},
    {name = "VFM 946", url = "http://cast.redewt.net:9141/live"},
    {name = "Rádio Antena Minho", url = "http://centova.radio.com.pt:9464/;"},
    {name = "Fama Rádio", url = "http://digitalfm.dynu.com:8000/digitalfm64"},
    {name = "Rádio Nove3Cinco", url = "http://centova.radio.com.pt:9522/;"},
    {name = "Alvor FM", url = "http://centova.radio.com.pt:8469/;"},
    {name = "Rádio Horizonte Algarve", url = "http://centova.radio.com.pt:9458/;"},
    {name = "Batida FM", url = "http://stream-icy.bauermedia.pt/batidafm.aac"},
    {name = "Rádio Portalegre", url = "http://centova.radio.com.pt:9492/;"},
    {name = "Rádio Onda Viva", url = "http://centova.radio.com.pt:9524/;"},
    {name = "Rádio Antena Livre", url = "http://centova.radio.com.pt:8571/;"},
    {name = "Rádio Internacional Odemira", url = "https://c30.radioboss.fm:18510/stream?1655151777664"},
    {name = "Rádio Barca", url = "http://centova.radio.com.pt:8483/;"},
    {name = "Rádio Popular Afifense", url = "http://centova.radio.com.pt:8471/;"},
    {name = "Rádio Limite", url = "http://centova.radio.com.pt:9408/;"},
    {name = "Rádio Atlântida", url = "http://centova.radio.com.pt:8505/;"},
    {name = "Rádio Vidigueira", url = "http://centova.radio.com.pt:8567/;"},
    {name = "Terra Quente FM", url = "http://centova.radio.com.pt:9402/;"},
    {name = "Radio Alto Ave", url = "https://centova.radio.com.pt/proxy/517?mp=/stream"},
    {name = "Estádio 962", url = "https://radios2.justweb.pt:8008/stream?type=http&nocache=65"},
    {name = "97Fm Rádio Clube De Pombal", url = "https://centova.radios.com.pt/proxy/410?mp=/stream"},
    {name = "Rádio Pico", url = "http://centova.radios.pt:9420/stream"},
    {name = "Antena 2 - Main", url = "https://radiocast.rtp.pt/antena280a.mp3"},
    {name = "Rádio Lisboa", url = "http://radiolisboa.ddns.net:8080/stream/1/"},
    {name = "Caria - Rádio Natal", url = "https://stream-57.zeno.fm/zb5w8yybqxhvv?zs=UFTgWO6XTcKToIndJPUT6w"},
    {name = "Rádio Clube De Mafra", url = "https://centova.radio.com.pt/proxy/551?mp=/stream"},
    {name = "SFTD RADIO", url = "http://hyades.shoutca.st:8270/stream/1/"},
    {name = "Cascais FM 1054", url = "https://play.radioregional.pt:8220/stream/2/;/stream.mp3"},
    {name = "Radio Portuguesa Do Var", url = "https://sonic.servsonic.com:7003/;"},
    {name = "Antena Livre De Gouveia", url = "https://centova.radio.com.pt/proxy/456?mp=/stream"},
    {name = "Radio Portugal Mais", url = "https://sv15.hdradios.net:7432/stream"},
    {name = "XL FM Lisboa", url = "http://radios2.justweb.pt:8028/stream"},
    {name = "Rádio Tágide", url = "https://radiotag.radioca.st/stream"},
    {name = "Rádio Foz Do Mondego", url = "https://nl.digitalrm.pt:8216/stream"},
    {name = "Rádio Popular De Source", url = "https://nl.digitalrm.pt:8072/stream?1671016403075="},
    {name = "Rádio Clube De Lamego", url = "http://audio.ptisp.com:8110/;"},
    {name = "Rádio Regional Do Centro", url = "https://nl.digitalrm.pt:8030/stream?1671017145140="},
    {name = "Rádio RCS 912 FM", url = "http://centova.radio.com.pt:8445/stream"},
    {name = "Nitfm", url = "https://sp0.redeaudio.com/8028/stream/"},
    {name = "Rádio Clube Madeira 1068 FM", url = "https://audio.serv.pt/8020/stream.mp3"},
    {name = "Rádio Zarco Madeira 896 FM", url = "https://audio.serv.pt/8014/stream.mp3"},
    {name = "Rádio Sol Madeira 1037 FM", url = "https://audio.serv.pt/8010/stream.mp3"},
    {name = "Rádio Palmeira Madeira 961 FM", url = "https://audio.serv.pt/8018/stream.mp3"},
    {name = "Lusophonica", url = "https://stream.radiojar.com/dxkmh6hv1f8uv?1651072328"},
    {name = "Radio ADM", url = "https://centova4.transmissaodigital.com:20014/stream.mp3"},
    {name = "Rádio 5", url = "https://radios.justweb.pt/8042/stream"},
    {name = "REWIND 2000'S", url = "https://2000.streeemer.com/listen/2000s/radio.aac"},
    {name = "Ultra FM", url = "http://centova.radio.com.pt:9506/;"},
    {name = "Rádio Alto Ave", url = "http://centova.radio.com.pt:8517/;"},
    {name = "Rádio Universitária Do Minho", url = "http://centova.radio.com.pt:9558/;"},
    {name = "Radio Nova Era", url = "https://centova.radio.com.pt/proxy/478?mp=/stream"},
    {name = "Rádio Ansiães", url = "http://centova.radio.com.pt:8419/;"},
    {name = "Rádio Caria", url = "http://centova.radio.com.pt:8521/;"},
    {name = "Rádio Castelo Branco", url = "http://centova.radio.com.pt:9462/;"},
    {name = "Rádio Condestável", url = "http://centova.radio.com.pt:8427/;"},
    {name = "Rádio Cova Da Beira", url = "http://centova.radio.com.pt:8467/;"},
    {name = "Rádio Granada FM", url = "http://centova.radio.com.pt:8549/;"},
    {name = "Rádio Lagoa", url = "http://centova.radio.com.pt:9488/;"},
    {name = "Rádio Miudos", url = "http://109.71.41.6:8020/live"},
    {name = "Antena Livre", url = "http://centova.radio.com.pt:9456/;"},
    {name = "Rádio Elmo", url = "http://centova.radio.com.pt:8463/;"},
    {name = "Rádio Cister", url = "http://centova.radio.com.pt:8453/;"},
    {name = "Rádio Clube De Sintra", url = "http://centova.radio.com.pt:8445/;"},
    {name = "Rádio Do Concelho De Mafra", url = "http://centova.radio.com.pt:8551/;"},
    {name = "Rádio Felgueiras", url = "http://centova.radio.com.pt:8459/;"},
    {name = "Tejo Rádio Jornal", url = "http://centova.radio.com.pt:8531/;"},
    {name = "Torres Novas FM", url = "http://centova.radio.com.pt:8475/;"},
    {name = "Rádio Clube De Grândola", url = "http://link.radios.pt/rcg"},
    {name = "FOQO", url = "http://185.32.188.17:8003/stream"},
    {name = "Rádio Clube De Arganil", url = "http://176.9.43.216:8135/stream"},
    {name = "Rádio Ondas Do Lima", url = "http://centova.radio.com.pt:8407/;"},
    {name = "Universidade FM", url = "http://centova.radio.com.pt:8405/;"},
    {name = "Rádio Riba-Távora", url = "http://centova.radio.com.pt:9542/;"},
    {name = "TSF Rádio Madeira", url = "http://centova.radio.com.pt:9470/;"},
    {name = "TSF Rádio Açores", url = "http://centova.radio.com.pt:8243/;"},
    {name = "Rádio Castrense", url = "http://centova.radio.com.pt:8431/;"},
    {name = "Rádio Regional De Arouca", url = "http://centova.radio.com.pt:8485/;"},
    {name = "TLA Rádio", url = "http://centova.radio.com.pt:8545/;"},
    {name = "Alto Tamega FM", url = "http://188.93.231.97:9300/;"},
    {name = "Rádio Alto Minho", url = "https://ec2.yesstreaming.net:3705/stream"},
    {name = "Rádio Antena Nove", url = "http://centova.radio.com.pt:8565/stream/1/"},
    {name = "PT Radio Christmas", url = "https://c19.radioboss.fm:18041/stream"},
    {name = "Radio Marginal 981 FM", url = "http://centova.radios.pt:8499/stream"},
    {name = "RTP - Radio Zigzag", url = "https://radiocast.rtp.pt/zigzag80a.mp3"},
    {name = "RDP Internacional - Main", url = "https://radiocast.rtp.pt/rdpint80a.mp3"},
    {name = "Radio Festival Do Norte", url = "https://centova.radio.com.pt/proxy/520?mp=/stream?nocache=123456789"},
    {name = "A1", url = "http://radiocast.rtp.pt/antena180a.mp3"},
    {name = "Onda Livre", url = "https://centova.radio.com.pt/proxy/572?mp=/stream"},
    {name = "Radio Observador", url = "https://playerservices.streamtheworld.com/api/livestream-redirect/OBSERVADORAAC.aac?dist=web-popup&devicename=aac"},
    {name = "Diana FM", url = "http://centova.radio.com.pt:9460/;"},
    {name = "Onda Nacional", url = "https://cast.redewt.net:9823/stream"},
    {name = "Rádio Movimento", url = "https://stream.rcast.net/61025"},
    {name = "Engenharia Rádio", url = "http://engradio.fe.up.pt:8080/live?type=.mp3"},
    {name = "BBN Portuguese", url = "https://audio-edge-5bkfj.fra.h.radiomast.io/ec065d59-f358-48c9-a288-4efc797e5860"},
    {name = "Radio Biblia", url = "https://servidor30-4.brlogic.com:7398/live?source=website"},
    {name = "Estação Diária", url = "http://centova.radio.com.pt:9430/;"},
    {name = "91FM", url = "https://sp0.redeaudio.com/9878/stream"},
    {name = "RADIO SAO MIGUEL", url = "https://nl.digitalrm.pt:8140/stream"},
    {name = "Rádio Valdevez", url = "http://centova.radios.pt:9508/stream"},
}

return stations