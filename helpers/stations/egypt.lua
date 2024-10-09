local stations = {
    {name = "إذاعة القرآن الكريم من القاهرة", url = "http://n12.radiojar.com/8s5u5tpdtwzuv?listening-from-radio-garden=1620219571863&rj-tok=AAABeTyl2zYARSWbLVnrEOlqGw&rj-ttl=5"},
    {name = "Nogoum FM", url = "https://audio.nrpstream.com/listen/nogoumfm/radio.mp3?refresh=1668723970691"},
    {name = "MEGA FM", url = "http://nebula.shoutca.st:8211/mp3"},
    {name = "Radio 9090 909", url = "http://9090streaming.mobtada.com/9090FMEGYPT"},
    {name = "SHA3BY FM", url = "https://radio95.radioca.st/;"},
    {name = "إذاعة محمود خليل الحصري", url = "https://qurango.net/radio/mahmoud_khalil_alhussary_warsh"},
    {name = "Tes3Enat FM", url = "http://178.33.135.244:20095/;?DIST=TuneIn&TGT=TuneIn&maxServers=2&partnertok=eyJhbGciOiJIUzI1NiIsImtpZCI6InR1bmVpbiIsInR5cCI6IkpXVCJ9.eyJ0cnVzdGVkX3BhcnRuZXIiOnRydWUsImlhdCI6MTYzNjA1OTE3OCwiaXNzIjoidGlzcnYifQ.Me0snc2PBcQhvlzte9L7zQxa-IHgNinhu3XdNJ6_Xa8"},
    {name = "On Sports FM", url = "https://carina.streamerr.co:2020/stream/OnSportFM"},
    {name = "Radio 9090", url = "https://9090streaming.mobtada.com/9090FMEGYPT"},
    {name = "878 Mix FM", url = "https://stream-29.zeno.fm/na3vpvn10qruv"},
    {name = "محطة مصر", url = "https://s3.radio.co/s9cb11828c/listen"},
    {name = "إذاعة مشاري العفاسي", url = "https://qurango.net/radio/mishary_alafasi"},
    {name = "إذاعة مصطفى إسماعيل", url = "https://qurango.net/radio/mustafa_ismail"},
    {name = "NRJ EGYPT", url = "http://nrjstreaming.ahmed-melege.com/nrjegypt"},
    {name = "Amr Diab Radio", url = "https://stream-40.zeno.fm/xa4yhh4k838uv?zs=gojgaFRaRrK1wgGIwdv6xA"},
    {name = "إذاعة ياسر الدوسري", url = "https://qurango.net/radio/yasser_aldosari"},
    {name = "القران الكريم من القاهره1", url = "http://n0e.radiojar.com/8s5u5tpdtwzuv?rj=&rj-tok=AAABg5BDP0EA2ElNLJYUJTsVcg&rj-ttl=5"},
    {name = "إذاعة القرآن الكريم القاهرة", url = "https://stream.radiojar.com/8s5u5tpdtwzuv"},
    {name = "---تراتيل قصيرة متميزة---", url = "https://qurango.net/radio/tarateel"},
    {name = "Nilefm", url = "https://audio.nrpstream.com/listen/nile_fm/radio.mp3"},
    {name = "90S FM", url = "https://fastcast4u.com/player/prontofm/?pl=vlc&c=0"},
    {name = "Radio Hits 882 Cairo", url = "https://radiohits882.radioca.st/;"},
    {name = "Diab FM", url = "http://stream-36.zeno.fm/rf64mx02qa0uv?zs=omRb6KEjQ3u0-JsaJKdhQg"},
    {name = "الشيخ ناصر القطامي", url = "http://server2.quraan.us:9886/"},
    {name = "إذاعة الشيخ أحمد العجمي برواية حفص", url = "http://server2.quraan.us:9852/;*.mp3"},
    {name = "إذاعة ماهر المعيقلي", url = "https://backup.qurango.net/radio/maher"},
    {name = "إذاعة الشيخ أبو بكر الشاطري برواية حفص", url = "http://quraan.us:9892/;*.mp3"},
    {name = "إذاعة القرآن الكريم", url = "https://n0a.radiojar.com/0tpy1h0kxtzuv?rj-ttl=5&rj-tok=AAABhdgGORQA-2acfyF3_4WY2g"},
    {name = "مختصر التفسير", url = "https://qurango.net/radio/mukhtasartafsir"},
    {name = "El Gouna Radio", url = "http://online-radio.eu/export/winamp/9080-el-gouna-radio"},
    {name = "Radio Misrfone", url = "http://s2.voscast.com:8612/;"},
    {name = "Radio القارئ علي حجاج السويسي", url = "http://live.mp3quran.net:9842/"},
    {name = "EGONAIR", url = "https://radio.socialgenix.com/8004/stream"},
    {name = "القارئ محمد أيوب", url = "https://qurango.net/radio/mohammed_ayyub"},
    {name = "اذاعة القرآن الكريم", url = "http://stream.radiojar.com/0tpy1h0kxtzuv"},
    {name = "تكبيرات العيد", url = "http://live.mp3quran.net:9728/"},
    {name = "Abderrasheed Sufis", url = "http://quraan.us:9866/;"},
    {name = "هواها بيطري", url = "https://s44.myradiostream.com/:9204/listen.mp3?listening-from-radio-garden-1696014326?nocache-1696021004"},
    {name = "القران الكريم من القاهره", url = "http://n0c.radiojar.com/8s5u5tpdtwzuv?rj-ttl=5&amp;rj-tok=AAABdI5Qnd0AEmvTTG5DVtU31A&amp;autoplay=1%22%20type=%22audio/mpeg"},
    {name = "Beautiful Recitation", url = "https://qurango.net/radio/salma"},
    {name = "Nile FM", url = "https://audio.nrpstream.com/public/nile_fm/playlist.pls"},
    {name = "Coptic Voice Radio", url = "http://stream.clicdomain.com.br:5828/;"},
    {name = "Tiba Radio", url = "http://s1.voscast.com:10026/;"},
    {name = "Abdulrasheed Soufi", url = "https://qurango.net/radio/abdulrasheed_soufi_assosi.mp3"},
    {name = "إذاعة طريق السلف", url = "https://airtime.salafwayfm.ly/"},
    {name = "XX", url = "https://stream.zeno.fm/n63xpx3o8imuv"},
    {name = "تفسير بن عثيمين", url = "https://qurango.net/radio/tafseer"},
    {name = "SOLLY", url = "https://stream.zeno.fm/juwfhuodjgmuv"},
}

return stations