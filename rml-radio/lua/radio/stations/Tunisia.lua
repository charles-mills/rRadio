local stations = {
    {name = "Al Quran Radio", url = "http://n01.radiojar.com/0tpy1h0kxtzuv?rj-ttl=5&rj-tok=AAABkYzw-98Ab-j2AIrTz2G69w"},
    {name = "Alhayet FM", url = "https://manager8.streamradio.fr:2885/stream"},
    {name = "Diwan FM", url = "https://streaming.diwanfm.net/stream"},
    {name = "Diwanfm", url = "https://streaming.diwanfm.net/stream"},
    {name = "Express FM", url = "http://expressfm.ice.infomaniak.ch/expressfm-64.mp3"},
    {name = "Express Radio", url = "https://expressfm.ice.infomaniak.ch/expressfm-64.mp3"},
    {name = "Jawhara FM", url = "https://streaming2.toutech.net/jawharafm"},
    {name = "Knooz FM", url = "http://streaming.knoozfm.net:8000/knoozfm"},
    {name = "Lotfi Slama", url = "https://azuracast.conceptradio.fr:8000/radio.mp3"},
    {name = "Mosaique FM", url = "https://radio.mosaiquefm.net/mosalive"},
    {name = "Mosaique FM DJ", url = "https://radio.mosaiquefm.net/mosadj"},
    {name = "Mosaique FM Gold", url = "https://radio.mosaiquefm.net/mosagold"},
    {name = "Mosaique FM Tarab", url = "https://radio.mosaiquefm.net/mosatarab"},
    {name = "Mosaique FM Tounsi", url = "https://radio.mosaiquefm.net/mosatounsi"},
    {name = "Mosaiquefm", url = "https://radio.mosaiquefm.net/mosalive"},
    {name = "Oasis-Fm", url = "https://stream3.rcast.net/69919"},
    {name = "Oxygène FM", url = "http://radiooxygenefm.ice.infomaniak.ch/radiooxygenefm-64.mp3"},
    {name = "Oxygene Fm", url = "http://stream.radios-arra.fr:8000/oxygenefm"},
    {name = "Quran", url = "http://quraan.us:9842/;"},
    {name = "Radio Coran", url = "http://n09.radiojar.com/0tpy1h0kxtzuv?rj-ttl=5&rj-tok=AAABkY5QZ3kA0mbTMtZ4I2Go9A"},
    {name = "Radio Fouedb Music", url = "https://das-edge09-live365-dal03.cdnstream.com/a82574"},
    {name = "Radio IFM", url = "https://live.ifm.tn/radio/8000/ifmlive"},
    {name = "Radio MED", url = "http://stream6.tanitweb.com/radiomed"},
    {name = "Radio Misk", url = "https://live.misk.art/stream"},
    {name = "Radio Quran Karim", url = "http://5.135.194.225:8000/live"},
    {name = "Radio Tunisia Med", url = "https://azuracast.conceptradio.fr:8000/radio.mp3"},
    {name = "Radio Tunisie Gafsa", url = "http://rtstream.tanitweb.com/gafsa"},
    {name = "Radio Tunisie Jeunes", url = "http://rtstream.tanitweb.com/jeunes"},
    {name = "Radio Tunisie Kef", url = "http://rtstream.tanitweb.com/kef"},
    {name = "Radio Tunisie Monastir", url = "http://rtstream.tanitweb.com/monastir"},
    {name = "Radio Tunisie Nationale", url = "http://rtstream.tanitweb.com/nationale"},
    {name = "Radio Tunisie Sfax", url = "http://rtstream.tanitweb.com/sfax"},
    {name = "Radio Tunisie Tataouine", url = "http://rtstream.tanitweb.com/tataouine"},
    {name = "Radio Zitouna FM", url = "https://stream.radiozitouna.tn/radio/8030/radio.mp3"},
    {name = "RTCI", url = "http://rtstream.tanitweb.com/rtci"},
    {name = "Sabra FM", url = "https://manager5.streamradio.fr:1905/stream"},
    {name = "Sfax FM", url = "http://rtstream.tanitweb.com/sfax"},
    {name = "Sodais", url = "https://backup.qurango.net/radio/abdulrahman_alsudaes"},
    {name = "Sunnah Radio", url = "http://andromeda.shoutca.st:8189/stream"},
    {name = "Zitouna FM", url = "https://stream.radiozitouna.tn/radio/8030/radio.mp3"},
    {name = "آيات السكينة", url = "https://qurango.net/radio/sakeenah"},
    {name = "أذكار الصباح", url = "https://qurango.net/radio/athkar_sabah"},
    {name = "أذكار المساء", url = "https://qurango.net/radio/athkar_masa"},
    {name = "إذاعة السنة", url = "http://andromeda.shoutca.st:8189/live"},
    {name = "إذاعة الفتاوى العامة", url = "https://qurango.net/radio/fatwa"},
    {name = "إذاعة القرآن الكريم", url = "http://n0e.radiojar.com/0tpy1h0kxtzuv?rj-ttl=5&rj-tok=AAABkY7n-k0AMU6SXWMBxq7BNQ"},
    {name = "إذاعة القرآن الكريم", url = "http://n09.radiojar.com/0tpy1h0kxtzuv?rj-ttl=5&rj-tok=AAABkY-ReqwAArPpcsR1ayAtKg"},
    {name = "إذاعة القرآن الكريم", url = "http://n06.radiojar.com/0tpy1h0kxtzuv?rj-ttl=5&rj-tok=AAABkZB_OdEAKBF6tgu3tJACsw"},
    {name = "إذاعة طريق السلف", url = "https://airtime.salafwayfm.ly/"},
    {name = "إذاعة علي جابر", url = "https://qurango.net/radio/ali_jaber"},
    {name = "إذاعة محمد أيوب", url = "https://qurango.net/radio/mohammed_ayyub"},
    {name = "إذاعة محمد أيوب", url = "https://qurango.net/radio/mohammed_ayyub"},
    {name = "إذاعة ميراث الأنبياء", url = "https://radio.al7eah.net/8028/;"},
    {name = "الإختيارات الفقهية لإبن باز", url = "https://qurango.net/radio/alaikhtiarat_alfiqhayh_bin_baz"},
    {name = "المختصر في التفسير", url = "https://qurango.net/radio/mukhtasartafsir"},
    {name = "النهج الواضح", url = "https://node33.obviousapproach.com:9000/stream"},
    {name = "النهج الواضح 1", url = "https://node33.obviousapproach.com:9000/stream"},
    {name = "النهج الواضح 3", url = "https://node33.obviousapproach.com:9002/stream"},
    {name = "النهج الواضح قرآن كريم", url = "https://node33.obviousapproach.com:9001/stream"},
    {name = "تراتيل", url = "https://qurango.net/radio/tarateel"},
    {name = "تفسير بن عثيمين رحمه الله تعالى", url = "https://qurango.net/radio/tafseer"},
    {name = "تكبيرات العيد", url = "https://qurango.net/radio/eid"},
    {name = "راديو جنجر للاطفال", url = "https://arabkidsradio.art/radio/8000/radio.mp3"},
    {name = "راديو فن Fenn Radio", url = "https://stream-154.zeno.fm/76e9f1gsduhvv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiI3NmU5ZjFnc2R1aHZ2IiwiaG9zdCI6InN0cmVhbS0xNTQuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IjdIZzNYcE8xVFZLTHRuSTJXOU5sSnciLCJpYXQiOjE3MjQ3MDExMTYsImV4cCI6MTcyNDcwMTE3Nn0.cE9ABIY9yzqYcccYTLanlaDXlomb7BksBKaHXZjuFW0"},
    {name = "ستة شوال", url = "https://qurango.net/radio/SixDaysOfShawwal"},
    {name = "عشر ذي الحجة", url = "https://qurango.net/radio/ten_dhul_hijjah"},
    {name = "فتاوى بن عثيمين رحمه الله تعالى", url = "http://server2.quraan.us:9890/;*.mp3"},
    {name = "في ضلال السيرة النبوية", url = "https://qurango.net/radio/fi_zilal_alsiyra"},
    {name = "قراءات متنوعة", url = "https://qurango.net/radio/mix"},
    {name = "قراءات متنوعة", url = "https://qurango.net/radio/mix"},
    {name = "ميراث الأنبياء", url = "https://radio.al7eah.net/8010/stream"},
    {name = "يوم عاشوراء", url = "https://qurango.net/radio/TheDayofAshoora"},
}

return stations