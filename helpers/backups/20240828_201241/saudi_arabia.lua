local stations = {
    {name = "MX2✨", url = "https://stream.zeno.fm/66gp9qukxaquv"},
    {name = "القارئ محمد أيوب", url = "https://qurango.net/radio/mohammed_ayyub"},
    {name = "مختصر السيرة", url = "https://qurango.net/radio/almukhtasar_fi_alsiyra"},
    {name = "Quran Radio", url = "https://n09.radiojar.com/0tpy1h0kxtzuv?rj-ttl=5&rj-tok=AAABjKoABHgAdULpynjQ7EwB6A"},
    {name = "صور من حياة الصحابة", url = "https://qurango.net/radio/sahabah"},
    {name = "ماهر المعيقلي", url = "https://backup.qurango.net/radio/maher"},
    {name = "1017 Your Love FM", url = "https://radio.905heartfm.com:8000/radio.mp3"},
    {name = "1018 ARTYS FM", url = "https://stream-174.zeno.fm/g2yddxs13hhvv?zs=bUaXJsFmTMaYYSvqOak4Ng&zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJnMnlkZHhzMTNoaHZ2IiwiaG9zdCI6InN0cmVhbS0xNzQuemVuby5mbSIsImp0aSI6ImJVYVhKc0ZtVE1hWVlTdnFPYWs0TmciLCJpYXQiOjE3MTI4NDA4OTEsImV4cCI6MTcxMjg0MDk1MX0.e21Ftv-FhU9QKVsOkmpm9fXoJpj39q1As5rG88dCn0E&zttl=5"},
    {name = "1059 Like FM", url = "https://likeradiostream.com/likeretro"},
    {name = "1069 OFW Cool Radio FM", url = "https://s3.voscast.com:7711/live"},
    {name = "13Xby MX2", url = "https://stream.zeno.fm/rduelmumm6buv"},
    {name = "1Dee", url = "http://65.108.98.93:8303/1Dee"},
    {name = "A F R O 505 By MX2", url = "https://stream.zeno.fm/7wozjkc8x0vvv"},
    {name = "AFN 360 Global Gravity 1059 FM", url = "http://17793.live.streamtheworld.com/AFN_GRV_SC"},
    {name = "AHLA AL QASEED FM", url = "https://ahlalqaseedfm-radio.mbc.net/ahlalqaseedfm-radio.m3u8"},
    {name = "Al Arabiya FM", url = "https://fm.alarabiya.net/fm/myStream/playlist.m3u8"},
    {name = "Alifalif FM", url = "https://alifalifjobs.com/radio/8000/AlifAlifLive.mp3"},
    {name = "ALULA FM 1072", url = "http://ice55.securenetsystems.net/DASH62"},
    {name = "Annahj - Islam Arabic - إذاعة النهج الواضح", url = "https://node33.obviousapproach.com:9000/stream"},
    {name = "Asmaaxxʙʏ MX2", url = "https://stream.zeno.fm/nkukhjz4vgtuv"},
    {name = "BBC Arabic 1413 AM", url = "http://stream.live.vc.bbcmedia.co.uk/bbc_world_service"},
    {name = "BBC Radio 1 KSA FM 1001", url = "http://as-hls-ww-live.akamaized.net/pool_904/live/ww/bbc_radio_one/bbc_radio_one.isml/bbc_radio_one-audio%3d96000.norewind.m3u8"},
    {name = "Ddnizz", url = "https://stream.zeno.fm/m8d8duscobutv"},
    {name = "Favradio FM 1015", url = "http://stream.hornhost.com:8109/"},
    {name = "Fred Film Radioلغة عربية", url = "https://s10.webradio-hosting.com/proxy/fredradioar/stream"},
    {name = "GMA News TV Middle East HD", url = "https://stream.gmanews.tv/ioslive/livestream/playlist.m3u8"},
    {name = "HOUB Radio حُب", url = "http://nap.casthost.net:8028/stream"},
    {name = "Islamic Tagalog Radio", url = "https://islamicbulletin.site:8030/stream"},
    {name = "Kapatid FM 958", url = "https://qp-pldt-live-grp-05-prod.akamaized.net/out/u/radyo5_qp.m3u8"},
    {name = "Maura Radio AR ✨", url = "https://stream.zeno.fm/fpasc3up26ptv"},
    {name = "Maura ✨ ENG", url = "https://stream.zeno.fm/ro5mutzm5ngtv"},
    {name = "Mbc", url = "http://211.221.46.79:1935/live/mp4:BusanMBC.Live-FM-0415/playlist.m3u8"},
    {name = "MBC FM", url = "https://mbcfm-radio.mbc.net/mbcfm-radio.m3u8"},
    {name = "MIX FM KSA", url = "https://s1.voscast.com:11377/live.mp3"},
    {name = "MOOD FM", url = "https://moodfm-radio.mbc.net/moodfm-radio.m3u8"},
    {name = "Mp3Quran Main", url = "https://qurango.net/radio/mix"},
    {name = "Mp3Quran Tarateel", url = "https://qurango.net/radio/tarateel"},
    {name = "OFW Tambayan FM 1007", url = "https://stream-170.zeno.fm/82bb4d2uz68uv?zs=CnZDUKriSmSeaRAwyMpGoQ&zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiI4MmJiNGQydXo2OHV2IiwiaG9zdCI6InN0cmVhbS0xNzAuemVuby5mbSIsImp0aSI6IkNuWkRVS3JpU21TZWFSQXd5TXBHb1EiLCJpYXQiOjE3MTI4MzUxMDgsImV4cCI6MTcxMjgzNTE2OH0.eNzYZ6jQPY5RL2uohAGhp8G7cFwGXB9BjFUeX7mysXo&zttl=5"},
    {name = "Old Time Radio KSA 720 AM", url = "https://ais-sa3.cdnstream1.com/2607_128.mp3"},
    {name = "Panorama FM", url = "https://panoramafm-radio.mbc.net/panoramafm-radio.m3u8"},
    {name = "PHR 1053 FM Precious Hearts Radio", url = "https://stream-172.zeno.fm/yyzp7bv9qchvv?zs=FS8fstfMQw-0L-XNabOKtg&zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJ5eXpwN2J2OXFjaHZ2IiwiaG9zdCI6InN0cmVhbS0xNzIuemVuby5mbSIsImp0aSI6IkZTOGZzdGZNUXctMEwtWE5hYk9LdGciLCJpYXQiOjE3MTI5Mjg1MDQsImV4cCI6MTcxMjkyODU2NH0.lfZDEwX6ZNFFGIqdubaoRgrWWlEpvGJp4jIbELmANmg&zttl=5"},
    {name = "Pinoy Radio KSA FM 955", url = "http://streaming.radio.co/s55a9c4931/low"},
    {name = "QURAN KAREEM", url = "https://quraanfm-radio.mbc.net/quraanfm-radio.m3u8"},
    {name = "Radio Asharq", url = "https://svs.itworkscdn.net/asharqradioalive/asharqradioa/playlist.m3u8"},
    {name = "Radio Asharq With Bloomberg راديو الشرق مع بلومبرغ", url = "https://l3.itworkscdn.net/asharqradioalive/asharqradioa/icecast.audio"},
    {name = "Radio Disney KSA 1170 AM", url = "https://listen.radioking.com/radio/453221/stream/508076"},
    {name = "Radio Enas", url = "https://www.lflouss.com/radio.php"},
    {name = "Radio Enas 2", url = "https://www.lflouss.com/www.BookOfHonesty.com.mp3"},
    {name = "Radio Maria Middle East", url = "http://dreamsiteradiocp2.com/proxy/rmphilippine?mp=/stream?ver=748140"},
    {name = "Radiosunna", url = "http://andromeda.shoutca.st:8189/stream"},
    {name = "Radyo Pilipinas KSA 1044 AM", url = "http://58.97.187.52:5007/rp4"},
    {name = "Remix S-DJ", url = "https://stream.zeno.fm/pdeizhgrtrstv"},
    {name = "ROTANA FM", url = "http://curiosity.shoutca.st:6035/;"},
    {name = "Saudi Aramco Studio X 80S And 90S", url = "https://live.flashbackcentral.co.uk/radio/8050/tunein.mp3"},
    {name = "Saudi Quran", url = "http://stream.radiojar.com/0tpy1h0kxtzuv"},
    {name = "Saudi Quran1", url = "http://n01.radiojar.com/0tpy1h0kxtzuv?rj-ttl=5&rj-tok=AAABjrUiYUAAxwNU2wDdcOap9w"},
    {name = "Saudia Radio", url = "https://s5.radio.co/s49bbdfa2a/listen"},
    {name = "SBA Radio Saudi International - 980 FM", url = "https://radio4.reans.net/radio/8410/radio.mp3?loveradio.com"},
    {name = "SBA Saudia Radio 1036 FM", url = "https://cast3.my-control-panel.com/proxy/idmzsayawpinoy/stream"},
    {name = "Skyradio FM 1055", url = "https://cp11.serverse.com/proxy/skyradio/stream"},
    {name = "SLOM FM | BY MX2", url = "https://stream.zeno.fm/ipqhjdw0tahvv"},
    {name = "TFC Middle East HD", url = "https://tfcguam-abscbn-ono.amagi.tv/index.m3u8"},
    {name = "UFM 955", url = "https://gbradio.cdn.tibus.net/U105?aw_0_1st.playerId=wireless-website&_=477645"},
    {name = "Voice Of Grace", url = "https://securestreams5.reliastream.com:1820/;"},
    {name = "WANASAH", url = "https://wanasahfm-radio.mbc.net/wanasahfm-radio.m3u8"},
    {name = "Wanasah FM", url = "https://wanasahfm-radio.mbc.net/wanasahfm-radio_1.m3u8"},
    {name = "WILD HEART FM 971", url = "https://62.138.18.102:8133/stream"},
    {name = "إذاعة السنة", url = "http://andromeda.shoutca.st:8189/live"},
    {name = "إذاعة طريق السلف", url = "https://airtime.salafwayfm.ly/"},
    {name = "الشيخ إدريس أبكر برواية حفص", url = "http://server2.quraan.us:9300/;*.mp3"},
    {name = "الشيخ توفيق الصايغ برواية حفص", url = "http://quraan.us:9796/;*.mp3"},
    {name = "القارئ علي الحذيفي رواية قالون", url = "https://qurango.net/radio/ali_alhuthaifi_qalon"},
    {name = "تفسير القرآن الكريم", url = "https://qurango.net/radio/tafseer"},
    {name = "سعد الغامدي", url = "https://www.lflouss.com/radio_saad_alghamdi.php"},
    {name = "سورة البقرة ماهر المعيقلي رواية حفص - جودة عالية", url = "https://www.lflouss.com/radio2.php"},
    {name = "فتاوى الشيخ ابن عثيمين", url = "http://server2.quraan.us:9890/;*.mp3"},
    {name = "قرآن", url = "http://quraan.us:9842/;"},
    {name = "مقدمة رسالة ابن أبي زيد القيرواني1", url = "https://www.al-badr.net/download/esound/choroohat/abuzaid_alkirawani/001.mp3"},
}

return stations