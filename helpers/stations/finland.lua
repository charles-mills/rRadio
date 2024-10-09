local stations = {
    {name = "Yle Radio Suomi, Helsinki", url = "http://icecast.live.yle.fi/radio/YleRS/icecast.audio"},
    {name = "Radio Helsinki 256 Kbs", url = "http://77.86.233.1:8002/"},
    {name = "Järviradio", url = "https://jarviradio.radiotaajuus.fi:9000/jr"},
    {name = "Doubleclap Radio", url = "https://s3.radio.co/scfd7273b2/listen"},
    {name = "Yle Radio1Hifi 256 Kbs", url = "http://icecast.live.yle.fi/radio/YleRadio1Hifi/icecast.audio"},
    {name = "Basso", url = "https://stream-redirect.bauermedia.fi/basso/bassoradio_64.aac?aw_0_1st.bauer_loggedin=false&aw_0_1st.playerid=BMUK_tunein"},
    {name = "Kaaos Radio Chiptune", url = "http://stream.kaaosradio.fi:8000/chip"},
    {name = "Radio Patmos", url = "https://s3.yesstreaming.net:7011/radio"},
    {name = "Tick Tock Radio - 1950", url = "https://streaming.ticktock.radio/tt/1950/icecast.audio"},
    {name = "Radio Nova", url = "https://stream.radioplay.fi/radionova/radionova_64.aac?aw_0_1st.skey=1692715205&aw_0_1st.bauer_loggedin=false"},
    {name = "Nostalgia", url = "https://stream-redirect.bauermedia.fi/nostalgia/nostalgia_64.aac?aw_0_1st.bauer_loggedin=false&aw_0_1st.playerid=BMUK_tunein"},
    {name = "Sea FM", url = "https://s3.myradiostream.com/4976/listen.mp3"},
    {name = "Yle Radio Suomi, Oulu Radio", url = "http://icecast.live.yle.fi/radio/YleOulu/icecast.audio"},
    {name = "YLE X3M", url = "http://icecast.live.yle.fi/radio/YleX3M/icecast.audio"},
    {name = "Kaaosradio - 24H", url = "http://stream.kaaosradio.fi:8000/stream.m3u"},
    {name = "Tampereen Kiakkoradio: Tappara", url = "https://st.downtime.fi/kiakko-tappara.aac"},
    {name = "Roll FM", url = "http://stream.rollfm.fi/"},
    {name = "Radio Keskisuomalainen", url = "https://cast.radiokeskisuomalainen.fi/radiokeskisuomalainen"},
    {name = "Kaaos Radio Techno Electro", url = "http://stream.kaaosradio.fi:8000/stream2"},
    {name = "RÄP", url = "https://stream.bauermedia.fi/basso/rap_64.aac"},
    {name = "Kasari", url = "https://stream-redirect.bauermedia.fi/kasari/kasari_64.aac?aw_0_1st.bauer_loggedin=false&aw_0_1st.playerid=BMUK_tunein"},
    {name = "NRJ", url = "https://stream-redirect.bauermedia.fi/nrj/nrj_64.aac?aw_0_1st.bauer_loggedin=false&aw_0_1st.playerid=BMUK_tunein"},
    {name = "Radio SUN", url = "http://st.downtime.fi/sun.mp3"},
    {name = "Radio Dei", url = "http://isojako.radiodei.fi:8000/yleisohjelma"},
    {name = "Radio Ramona", url = "http://185.123.117.122:8000/ramona.mp3"},
    {name = "KISS", url = "http://stream.bauermedia.fi/kiss/kiss_64.aac"},
    {name = "NRJ Suomi", url = "http://stream.bauermedia.fi/nrj/nrj_128.mp3"},
    {name = "Finest Fm", url = "http://212.47.220.188:8000/listen.mp3"},
    {name = "Radio Pooki", url = "http://stream.bauermedia.fi/radiopooki/radiopooki_64.aac"},
    {name = "Iskelmä", url = "https://stream.bauermedia.fi/iskelma/iskelma_128.mp3"},
    {name = "Bassoradio", url = "https://stream.radioplay.fi/basso/bassoradio_64.aac"},
    {name = "Sveriges Radio - SR Sisuradio", url = "http://sverigesradio.se/topsy/direkt/226-hi-aac.pls"},
    {name = "Karjalainen Syke", url = "https://stream.radiorex.fi:8000/radiorex"},
    {name = "Radio Helsinki 128 Kbs", url = "http://radio.radiohelsinki.fi/"},
    {name = "TOP51", url = "https://stream-redirect.bauermedia.fi/top51/top51_64.aac?aw_0_1st.bauer_loggedin=false&aw_0_1st.playerid=BMUK_tunein"},
    {name = "Sea FM Radio", url = "http://s3.myradiostream.com:4976/;"},
    {name = "Yle Radio Suomi, Turku", url = "http://icecast.live.yle.fi/radio/YleTurku/icecast.audio"},
    {name = "Radio Dei Helsinki", url = "http://isojako.radiodei.fi:8000/helsinki"},
    {name = "Kaaosradio - 24H Chill", url = "http://stream.kaaosradio.fi:8000/chill"},
    {name = "Radio Helsinki 98,5 Mhz", url = "http://opml.radiotime.com/Tune.ashx?id=s97243&formats=aac,ogg,mp3&partnerId=16&serial=afe4c1a95cc7f3a92c47dbad1b283293"},
    {name = "LBC", url = "http://ice-sov.musicradio.com/LBCLondon"},
    {name = "Ysäri", url = "https://stream-redirect.bauermedia.fi/ysari/ysari_64.aac?aw_0_1st.bauer_loggedin=false&aw_0_1st.playerid=BMUK_tunein"},
    {name = "Radio Voima", url = "https://cast2.radiovoima.fi/voima.mp3"},
    {name = "Radio Musa", url = "http://n09.radiojar.com/n6yg5q0z8vzuv.m4a"},
    {name = "Radio Dei Oulu", url = "http://isojako.radiodei.fi:8000/oulu"},
    {name = "Rondo Classic", url = "http://rondo.iradio.fi:8000/klasupro-hi.mp3"},
    {name = "Radio Classic 128Kbps", url = "https://stream.bauermedia.fi/classic/classic_128.mp3"},
    {name = "Radio Hear", url = "http://hear.fi:8000/hear.mp3"},
    {name = "Radioverkko", url = "http://kuuntele.radioverkko.fi:8000/live"},
    {name = "Radio KAAKKO", url = "http://wr2.downtime.fi/kaakko.aac"},
    {name = "Radio Dei Kokkola", url = "http://isojako.radiodei.fi:8000/kruunupyy"},
    {name = "Radio Dei Pohjanmaa", url = "http://isojako.radiodei.fi:8000/lapua"},
    {name = "Radio Santa Claus", url = "https://streaming.radiostreamlive.com/radiosantaclaus_devices"},
    {name = "Radio Suomirock", url = "https://stream.bauermedia.fi/suomirock/suomirock_128.mp3"},
    {name = "Radio City", url = "https://stream.bauermedia.fi/radiocity/radiocity_64.aac?aw_0_1st.bauer_loggedin=false&aw_0_1st.skey=1692709153"},
    {name = "Savon Aallot", url = "https://cast.savonaallot.fi/savonaallot"},
    {name = "Radio Basso", url = "https://stream.bauermedia.fi/basso/bassoradio_64.aac"},
    {name = "Radio Natale", url = "https://streaming.radiostreamlive.com/radionatale_devices-low?token=%3C?%20echo%20rand%20(1,200000);%20?%3E"},
    {name = "Radio Dei Rovaniemi", url = "http://isojako.radiodei.fi:8000/rovaniemi"},
    {name = "Radio Dei Kemi", url = "http://isojako.radiodei.fi:8000/tornio"},
    {name = "Radio Dei Turku Ja Eurajoki", url = "http://isojako.radiodei.fi:8000/turkueurajoki"},
    {name = "Radio Dei Kristiinankaupunki", url = "http://isojako.radiodei.fi:8000/kristiinankaupunki"},
    {name = "Radio Tuottaja1", url = "https://kaupunkiradio.radiotaajuus.fi:9013/radio"},
    {name = "Radio 957", url = "http://stream.bauermedia.fi/radio957/radio957_64.aac"},
    {name = "Radio Tempo", url = "https://cast.radiotempo.fi/radiotempo"},
    {name = "Radio Dei Kajaani", url = "https://stream.dei.fi:8443/kajaani"},
    {name = "Radio Dei Lahti", url = "https://stream.dei.fi:8443/lahti"},
    {name = "Rondo Classic Klasu Pro", url = "http://stream.iradio.fi:8000/klasupro-hi.mp3"},
}

return stations