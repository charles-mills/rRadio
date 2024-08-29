local stations = {
    {name = "1013 KOPENHAG FM", url = "https://canli.arabeskinmerkezi.com/9180/stream"},
    {name = "100% Kim Larsen", url = "http://stream2.wlmm.dk/kimlarsenmp3"},
    {name = "2Town Radio", url = "http://streaming.radio.co/sd9d980ff0/listen"},
    {name = "80'S Hits", url = "https://live-bauerdk.sharp-stream.com/DK_HQ_RP04.aac"},
    {name = "902 FM", url = "http://s38.myradiostream.com:8598/.mp3"},
    {name = "Alfa Gold", url = "https://radioserver.dk/alfaevent"},
    {name = "Always Elvis Radio", url = "http://radioserver.dk/alwayselvisradio"},
    {name = "ANR", url = "http://stream.anr.dk/anr"},
    {name = "Classic Dance [DK]", url = "https://stream.classicpop.dk/dance"},
    {name = "Classic FM", url = "http://webradio.classicfm.dk/classichorsens"},
    {name = "Classic FM Fyn", url = "https://netradio.classicfm.dk/cla12a"},
    {name = "Classic POP [DK]", url = "https://stream.classicpop.dk/stream"},
    {name = "Classic Pop 90'Er Hits [DK]", url = "https://stream.classicpop.dk/event"},
    {name = "Classic Rock Danmark", url = "https://netradio.classicfm.dk/classicrock"},
    {name = "Classicfm", url = "http://netradio.classicfm.dk/cla8d"},
    {name = "Danmarks Radio P2", url = "https://live-icy.dr.dk/A/A27L.mp3"},
    {name = "Danmarks Radio P4; Trekanten", url = "http://live-icy.gss.dr.dk/A/A13H.mp3.m3u"},
    {name = "Danmarks Radio P6", url = "https://live-icy.dr.dk/A/A29H.mp3"},
    {name = "Dansktop Kanalen", url = "https://netradio.classicfm.dk/dansktop"},
    {name = "Den Tunge Radio", url = "https://26453.live.streamtheworld.com/SAM08AAC276.mp3"},
    {name = "Det Rigtige Faaborg", url = "http://stream2.wlmm.dk/detrigtigefaaborg"},
    {name = "DFM Radio Television International", url = "http://stereo.dfm.nu:8205/dfm_1"},
    {name = "Din Radio", url = "http://stream.wlmm.dk/DinRadiomp3"},
    {name = "DR 6 Beat", url = "http://live-icy.gss.dr.dk:8000/A/A29H.mp3"},
    {name = "DR Nyheder", url = "http://live-icy.gss.dr.dk/A/A02L.mp3.m3u"},
    {name = "DR P1", url = "http://live-icy.gss.dr.dk/A/A03H.mp3"},
    {name = "DR P1 AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p1/masterab.m3u8"},
    {name = "DR P1 HLS 96", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p1/playlist-96000.m3u8"},
    {name = "DR P2", url = "http://live-icy.gss.dr.dk/A/A04H.mp3.m3u"},
    {name = "DR P2 AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p2/masterab.m3u8"},
    {name = "DR P2 HLS 96", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p2/playlist-96000.m3u8"},
    {name = "DR P3", url = "http://live-icy.gss.dr.dk:8000/A/A05H.mp3"},
    {name = "DR P3 AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p3/masterab.m3u8"},
    {name = "DR P3 HLS 96", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p3/playlist-96000.m3u8"},
    {name = "DR P4 Bornholm", url = "https://live-icy.dr.dk/A/A30H.mp3"},
    {name = "DR P4 Bornholm AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p4bornholm/masterab.m3u8"},
    {name = "DR P4 Esbjerg", url = "http://live-icy.gss.dr.dk/A/A15H.mp3"},
    {name = "DR P4 Esbjerg AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p4esbjerg/masterab.m3u8"},
    {name = "DR P4 Fyn", url = "http://live-icy.gss.dr.dk:8000/A/A07H.mp3"},
    {name = "DR P4 Fyn AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p4fyn/masterab.m3u8"},
    {name = "DR P4 København", url = "http://live-icy.gss.dr.dk/A/A08H.mp3"},
    {name = "DR P4 København AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p4kobenhavn/masterab.m3u8"},
    {name = "DR P4 København MP3", url = "http://live-icy.dr.dk/A/A08H.mp3"},
    {name = "DR P4 København HLS 96", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p4kobenhavn/playlist-96000.m3u8"},
    {name = "DR P4 Midt Vest", url = "http://live-icy.gss.dr.dk/A/A09H.mp3.m3u"},
    {name = "DR P4 Midt-Vest AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p4midtvest/masterab.m3u8"},
    {name = "DR P4 Midtvest", url = "http://live-icy.gss.dr.dk/A/A09H.mp3"},
    {name = "DR P4 Nordjylland", url = "http://live-icy.dr.dk/A/A10H.mp3.m3u"},
    {name = "DR P4 Nordjylland AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p4nordjylland/masterab.m3u8"},
    {name = "DR P4 Østjylland", url = "http://live-icy.gss.dr.dk:8000/A/A14H.mp3"},
    {name = "DR P4 Østjylland AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p4ostjylland/masterab.m3u8"},
    {name = "DR P4 Østjyllands Radio", url = "http://live-icy.gss.dr.dk/A/A14H.mp3.m3u"},
    {name = "DR P4 Sjælland", url = "http://live-icy.gss.dr.dk:8000/A/A11H.mp3"},
    {name = "DR P4 Sjælland AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p4sjaelland/masterab.m3u8"},
    {name = "DR P4 Syd", url = "http://live-icy.gss.dr.dk/A/A12H.mp3"},
    {name = "DR P4 Syd AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p4syd/masterab.m3u8"},
    {name = "DR P4 Trekanten", url = "http://live-icy.gss.dr.dk:8000/A/A13H.mp3"},
    {name = "DR P4 Trekanten AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p4trekanten/masterab.m3u8"},
    {name = "DR P5", url = "http://live-icy.gss.dr.dk/A/A25H.mp3.m3u"},
    {name = "DR P5 Bornholm AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p5bornholm/masterab.m3u8"},
    {name = "DR P5 Esbjerg", url = "https://live-icy.dr.dk/A/A26H.mp3"},
    {name = "DR P5 Esbjerg AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p5esbjerg/masterab.m3u8"},
    {name = "DR P5 Fyn", url = "https://drliveradio.akamaized.net/hls/live/2022411/p5fyn/playlist-96000.m3u8"},
    {name = "DR P5 Fyn AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p5fyn/masterab.m3u8"},
    {name = "DR P5 København AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p5kobenhavn/masterab.m3u8"},
    {name = "DR P5 Midt-Vest AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p5midtvest/masterab.m3u8"},
    {name = "DR P5 Midtvest", url = "https://live-icy.dr.dk/A/A17H.mp3"},
    {name = "DR P5 Nordjylland AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p5nordjylland/masterab.m3u8"},
    {name = "DR P5 Østjylland", url = "https://live-icy.dr.dk/A/A24H.mp3"},
    {name = "DR P5 Østjylland AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p5ostjylland/masterab.m3u8"},
    {name = "DR P5 Sjælland AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p5sjaelland/masterab.m3u8"},
    {name = "DR P5 Syd", url = "https://drliveradio.akamaized.net/hls/live/2022411/p5syd/masterab.m3u8"},
    {name = "DR P5 Syd AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p5syd/masterab.m3u8"},
    {name = "DR P5 Trekanten", url = "http://live-icy.gss.dr.dk/A/A23H.mp3.m3u"},
    {name = "DR P5 Trekanten AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p5trekanten/masterab.m3u8"},
    {name = "DR P6 Beat", url = "http://live-icy.gss.dr.dk/A/A29H.mp3"},
    {name = "DR P6 BEAT AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p6beat/masterab.m3u8"},
    {name = "DR P6 Beat HLS 96", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p6beat/playlist-96000.m3u8"},
    {name = "DR P6 Jazz", url = "https://drliveradio.akamaized.net/hls/live/2022411/p8jazz/playlist-320000.m3u8"},
    {name = "DR P8 JAZZ", url = "http://live-icy.gss.dr.dk/A/A22H.mp3.m3u"},
    {name = "DR P8 JAZZ AAC", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p8jazz/masterab.m3u8"},
    {name = "DR P8 Jazz HLS 96", url = "https://drliveradio1.akamaized.net/hls/live/2097651/p8jazz/playlist-96000.m3u8"},
    {name = "DR Ramasjangultra Radio", url = "http://live-icy.gss.dr.dk/A/A24H.mp3"},
    {name = "DRR", url = "http://radioserver.dk/abc"},
    {name = "Esbjerg Classic FM", url = "https://webradio.classicfm.dk/classicvejle"},
    {name = "Femernfm", url = "https://cast1.asurahosting.com/proxy/femernfm/stream"},
    {name = "Globus Guld", url = "http://stream.wlmm.dk/listen.pls?sid=1"},
    {name = "Globus Guld Jul", url = "https://stream.probroadcast.dk/guldjul"},
    {name = "Globus Guld Kolding", url = "http://media.wlmm.dk:8000/guldkolding"},
    {name = "Globus Guld Tonder", url = "http://media.wlmm.dk:8000/guldtoender"},
    {name = "GLR - Gentofte Lokal Radio", url = "https://live-bauerdk.sharp-stream.com/thevoice_dk_mp3"},
    {name = "Gofm", url = "https://radioserver.dk/gofm"},
    {name = "Jazzkanalen", url = "http://ca6.rcast.net:4058/;stream"},
    {name = "København Jazz Radio", url = "https://asima.out.airtime.pro:8000/radiojazzcopenhagen_a"},
    {name = "Limfjord Plus", url = "http://media.limfjordnetradio.dk/plus128"},
    {name = "Limfjord Plus Slager", url = "http://media.limfjordnetradio.dk/plusslager128"},
    {name = "Lumi Radio", url = "http://stream2.wlmm.dk/syddanmark.m3u"},
    {name = "Midtfjord Radio Radio Nibenitten", url = "http://stream.midtfjordradio.dk/netradio"},
    {name = "Mix FM Gribskov, Retro Nord", url = "https://netradio.mixfm.dk/stream"},
    {name = "Musaiko", url = "http://fluo.muzaiko.saluton.dk:8000/radio.mp3"},
    {name = "Myrock", url = "https://live-bauerdk.sharp-stream.com/myrock_dk_mp3"},
    {name = "Nordic Lodge Copenhagen", url = "http://radio.streemlion.com:1160/stream"},
    {name = "Nordsjællands Kristne Radio", url = "http://studie.hkr.dk:8000/stream.mp3"},
    {name = "Norea Radio", url = "http://radio.norea.dk:8080/;"},
    {name = "Nova", url = "http://live-bauerdk.sharp-stream.com/nova128.mp3"},
    {name = "NOVA - Horsens 1036 FM", url = "https://live-bauerdk.sharp-stream.com/nova_dk_mp3"},
    {name = "Nova 100 Dansk", url = "https://live-bauerdk.sharp-stream.com/DK_HQ_RP11.aac"},
    {name = "Party Fm", url = "http://stream1.partyfm.dk/Party320"},
    {name = "Partyfm", url = "http://stream.partyfm.dk/Party320/"},
    {name = "POP FM DK", url = "http://live-bauerdk.sharp-stream.com/popfm128.mp3"},
    {name = "Psyradio - Chillout", url = "http://komplex2.psyradio.org:8020/chillout/;"},
    {name = "Psyradio - Progressive", url = "http://ipx.psyradio.org:8010/;"},
    {name = "Psyradio - Psytrance", url = "http://ipx.psyradio.org:8030/;"},
    {name = "Radio 100", url = "https://live-bauerdk.sharp-stream.com/radio100_dk_mp3"},
    {name = "Radio 208", url = "http://stream.wlmm.dk:8010/radio208"},
    {name = "Radio 40Plus", url = "http://stream.radiosolutions.dk/radio40plus"},
    {name = "Radio ABC", url = "http://netradio.radioabc.dk/"},
    {name = "Radio Alfa", url = "https://radioserver.dk/alfa"},
    {name = "Radio Alfa Aarhus", url = "https://radioserver.dk/alfaaarhus"},
    {name = "Radio Alfa Midtjylland", url = "https://radioserver.dk/alfamidt"},
    {name = "Radio Alfa Silkeborg", url = "https://radioserver.dk/alfasilk"},
    {name = "Radio Alfa Skive", url = "https://radioserver.dk/alfaskive"},
    {name = "Radio Alfa Viborg", url = "https://radioserver.dk/alfaviborg"},
    {name = "Radio ALR", url = "http://streamer.radio.co/s6a9beb92e/listen"},
    {name = "Radio Boost", url = "http://6434.cloudrad.io:8066/;"},
    {name = "Radio Diablo", url = "https://icecast1.radiostuff.dk/Diablo128"},
    {name = "Radio Fasanen Frederiksberg", url = "https://c14.radioboss.fm:18228/stream"},
    {name = "Radio Folk", url = "http://stream.radiojar.com/fqt2y0ds97zuv"},
    {name = "Radio Freja", url = "http://solid67.streamupsolutions.com:15507/stream"},
    {name = "Radio Globus", url = "https://stream.probroadcast.dk/radioglobus"},
    {name = "Radio Haderslev", url = "http://media.wlmm.dk/radiohaderslevmp3"},
    {name = "Radio Helsingør FM", url = "https://stream.radiohelsingor.dk/rh"},
    {name = "Radio Humleborg", url = "https://stream2.rcast.net/64145"},
    {name = "Radio Klitholm", url = "http://stream.radioklitholm.dk:8000/stream"},
    {name = "Radio Koge", url = "http://stream.wlmm.dk/stream/53/;"},
    {name = "Radio Limfjord", url = "http://media.limfjordnetradio.dk/limfjord128"},
    {name = "Radio M", url = "https://radioserver.dk/radiom"},
    {name = "Radio Mælkebøtten", url = "http://live2.rcast.net:8722/;stream"},
    {name = "Radio MFK", url = "https://stream1.radiomfk.dk/radiomfk"},
    {name = "Radio Midtsjælland", url = "http://player.radiomidt.dk/broadwave.mp3"},
    {name = "Radio Nord", url = "http://netradio.radionord.dk:8000/RadioNord"},
    {name = "Radio Nordjyske", url = "http://stream.anr.dk/nordjyske"},
    {name = "Radio Odsherred", url = "http://87.104.40.139:88/broadwave.mp3"},
    {name = "Radio Ost FM", url = "http://stream.wlmm.dk/oestfmmp3"},
    {name = "Radio Østsjælland Rollo", url = "http://stream.radiosolutions.dk/rollo"},
    {name = "Radio Playback", url = "https://stream02.radioplayback.dk/stream"},
    {name = "Radio Ringkøbing", url = "http://netradio.radioringkobing.dk:8000/;"},
    {name = "Radio SLR", url = "http://stream.wlmm.dk/stream/54/"},
    {name = "Radio Soft", url = "http://tx-bauerdk.sharp-stream.com/http_live.php?i=radiosoft_dk_mp3"},
    {name = "Radio Soft - Københavns NR - Bispebjerg LR - Bella Chr", url = "https://live-bauerdk.sharp-stream.com/radiosoft_dk_tunein_mp3"},
    {name = "Radio Solo", url = "https://radioserver.dk/solo"},
    {name = "Radio Stinesen", url = "https://st1.stinesen.dk/StineM320"},
    {name = "Radio Sydhavs Øerne", url = "https://stream.probroadcast.dk/sydhavsradiomp3"},
    {name = "Radio Varde", url = "http://stream.wlmm.dk/radiovardemp3"},
    {name = "Radio Viborg", url = "https://webradio.radioviborg.dk/viborg"},
    {name = "Radio Victoria", url = "http://stream.wlmm.dk/NyRadiomp3"},
    {name = "Radio Viva", url = "http://stream.wlmm.dk/radioviva"},
    {name = "Radio Viva - Kolding", url = "https://stream.probroadcast.dk/radioviva"},
    {name = "Radio VLR", url = "https://netradio.vlr.dk/vlr8d"},
    {name = "Radio VLR - Classic Christmas", url = "https://netradio.vlr.dk/popup2"},
    {name = "Radio4", url = "http://netradio.radio4.dk/radio4"},
    {name = "Rar", url = "http://techno-low.rautemusik.fm/"},
    {name = "Retro Millennium", url = "https://tx-2.retro-radio.dk/TX-2"},
    {name = "Retro Radio", url = "http://stream128.retro-radio.dk/retro"},
    {name = "Retro-Radio Jul", url = "http://isstream.kanalplus.fm/TX-1"},
    {name = "Retro-Radio Millennium", url = "http://tx-2.retro-radio.dk/TX-2"},
    {name = "Retro1", url = "http://streammp3.retro-radio.dk/retro-mp3"},
    {name = "Rockkanalen", url = "http://www.kanalplus.fm/rockkanalen/kp96.pls"},
    {name = "Roskilde Dampradio", url = "https://stream.rcast.net/60962"},
    {name = "Skaga FM", url = "http://stream.wlmm.dk/skagafm.m3u"},
    {name = "Skala FM", url = "http://webradio.skala.fm/kolding"},
    {name = "Tango Copenhagen Radio", url = "https://tangocopenhagen.stream.laut.fm/tangocopenhagen?t302=2021-01-15_18-47-40&uuid=64db9a91-4a6e-4bc8-ba24-26a2fa7f24d0"},
    {name = "Technobasefm - Aacplus 96K", url = "http://listen.technobase.fm/tunein-aacplus-pls"},
    {name = "Technobasefm - MP3 192K", url = "http://listen.technobase.fm/tunein-mp3-pls"},
    {name = "The Lake Radio", url = "http://hyades.shoutca.st:8627/"},
    {name = "The Voice", url = "http://live-bauerdk.sharp-stream.com/voice128.mp3"},
    {name = "UMLANDO Radio", url = "https://a2.asurahosting.com:6520/radio.mp3"},
    {name = "Vinyl Hits", url = "http://stream.vinylhits.dk/vinylaac"},
    {name = "Vinylhitsdk", url = "http://stream.vinylhits.dk/vinylmp3"},
    {name = "Vox Pop", url = "http://stream.midlar.fo/voxpop-128"},
    {name = "WMR - World Music Radio", url = "https://stream.probroadcast.dk/wmr"},
    {name = "World Music Radio", url = "http://stream.wlmm.dk:8010/wmr"},
    {name = "X FM K", url = "https://uniradio.out.airtime.pro/uniradio_a"},
    {name = "Ymse Radio", url = "https://radio.ymseimpro.org/"},
}

return stations