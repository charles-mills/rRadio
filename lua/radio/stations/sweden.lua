local stations = {
    {name = "Aordreamer", url = "http://178.33.33.176:8060/stream1"},
    {name = "Hitcity", url = "http://89.160.63.63/hitcity392kbps"},
    {name = "Country Rocks Radio", url = "http://stream.dbmedia.se/crr96"},
    {name = "Guldkanalen Malmölund", url = "http://stream.dbmedia.se/gk96"},
    {name = "Guldkanalen Helsingborg", url = "http://stream.dbmedia.se/gkhbg96"},
    {name = "Himlen TV7", url = "http://vod.tv7.fi:1935/tv7-se/mp4:tv7-se.stream_720p/playlist.m3u8"},
    {name = "Distfm – 100% ROCK", url = "http://listen.to.distfm.se:7006/stream"},
    {name = "Al Quran Radio", url = "http://n0e.radiojar.com/0tpy1h0kxtzuv?rj-ttl=5&rj-tok=AAABkZYrib4AZILibVCkzmm9JA"},
    {name = "Dunken FM", url = "http://stream.nsp.se:8000/DFM_MP3_Hi"},
    {name = "FUN RADIO 95,3 Sweden", url = "http://stream.funradio.se:81/live192"},
    {name = "Gold FM 1024", url = "http://goldfm.nu:8082/goldfm_mp3"},
    {name = "Helsinborgs Närradio", url = "http://deb.patrikmalmgrenrask.se:8010/"},
    {name = "Bozradio", url = "http://das-edge11-live365-dal03.cdnstream.com/a80252"},
    {name = "Guldkanalen 80-Tal", url = "https://stream.dbmedia.se/gk80tal96"},
    {name = "Dansbandskanalense*", url = "https://stream.dbmedia.se/dbkMP3"},
    {name = "Lite FM 1011", url = "http://streaming.943.se/lite.mp3"},
    {name = "Narradion Boden", url = "http://radio.bodensradio.se:8000/stream.ogg"},
    {name = "Göteborgs Närradio 1026 Mhz", url = "http://lyssna.fnf.nu:8080/gnf102.mp3"},
    {name = "Magic Radio", url = "http://stream.magicradio.se/magic"},
    {name = "Best Of Ericaderadio", url = "https://radio.ericade.net/sc/stream/2/"},
    {name = "Dagnys Jukebox", url = "http://streaming2.nordblommedia.se:443/dagny.mp3"},
    {name = "Mix Megapol", url = "http://edge-bauerse-01-gos2.sharp-stream.com/mixmegapol_instream_se_mp3?ua=WEB&"},
    {name = "Northern Metal Radio", url = "https://dc5.serverse.com/proxy/lvzgnvcj/stream"},
    {name = "Bitjam", url = "http://marmalade.scenesat.com:8086/bitjam.ogg"},
    {name = "106,7 Rockklassiker", url = "http://edge-bauerse-03-gos2.sharp-stream.com/rockklassiker_instream_se_mp3?ua=WEB&"},
    {name = "Mix Megapol GBG", url = "http://edge-bauerse-05-gos2.sharp-stream.com/mixmegapolgbg_instream_se_mp3?"},
    {name = "Mixmegapol", url = "http://edge-bauerse-02-thn.sharp-stream.com/rockklassiker_instream_se_mp3?ua=WEB&"},
    {name = "Bandit Metal", url = "http://wr03-ice.stream.khz.se/wr03_mp3"},
    {name = "Bandit Alternative", url = "http://wr05-ice.stream.khz.se/wr05_mp3"},
    {name = "Lugna Favoriter Stockholm", url = "http://fm03-ice.stream.khz.se/fm03_mp3?"},
    {name = "Julkanalen", url = "http://fm10-ice.stream.khz.se/fm10_mp3"},
    {name = "Bandit Rock", url = "http://fm02-ice.stream.khz.se/fm02_mp3"},
    {name = "Gold 102,4", url = "http://gold24.xnk.nu:8080/;"},
    {name = "NRJ Sweden", url = "http://edge-bauerse-02-thn.sharp-stream.com/nrj_instreamtest_se_mp3?"},
    {name = "Northern Metal Radio Extreme", url = "https://s2.free-shoutcast.com/stream/18092"},
    {name = "Banjalučki Sevdah Radio Šeherčani", url = "https://stream-172.zeno.fm/wazhcyi9ak5vv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJ3YXpoY3lpOWFrNXZ2IiwiaG9zdCI6InN0cmVhbS0xNzIuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IjE5cnd0MG05UmktTkIyVFk2NXhmOEEiLCJpYXQiOjE3MjQ4NTA2MjQsImV4cCI6MTcyNDg1MDY4NH0.A5u5qriQX5FpseMiIex0fyCeJJG8ooIVZ24RrXJT-AE"},
    {name = "Go Country", url = "https://wr14-ice.stream.khz.se/wr14_mp3"},
    {name = "Bandit Classic Rock", url = "https://wr11-ice.stream.khz.se/wr11_mp3"},
    {name = "Bandit Írock", url = "https://fm02-ice.stream.khz.se/fm02_mp3"},
    {name = "Disco 54", url = "https://wr15-ice.stream.khz.se/wr15_mp3"},
    {name = "Gamla Favoritter", url = "https://wr09-ice.stream.khz.se/wr09_mp3"},
    {name = "Pop Rock", url = "http://62.101.46.15:8000/poporock"},
    {name = "P4 Örebro", url = "http://http-live.sr.se/p4orebro-aac-192"},
    {name = "Radio 88 Partille", url = "http://62.209.164.60:8000/mp128.mp3"},
    {name = "P4 Östergötland", url = "http://http-live.sr.se/p4ostergotland-aac-192?DIST=TuneIn&TGT=TuneIn&maxServers=2&gdpr=1&us_privacy=1YNY&gdpr_consent=CPSxGf7PSxGf7AcABBENB9CsAP_AAAAAACiQIfhBACZEDAFBAGBpAIsAAAAAAAAAACAwAAAAACAACDgAAAQAgAAAAAgAACAAAAgAIAAAAAAAAAAABAAAAAAAAADEAAAAAAEAAABAAAAAAAAAAAAAAICAAAAAAAAQAAAAkAwAPv____f_7-3_3__5_3---_e_V_99zLv9____39nP___9v-_9___4AAAEgkB4ACoAGQAOAAgABkADSAIgAigBMACeAKUAaoA7wEiAMNAYeAyIBkgDJwGXAM5AZ8A0gBp0DWANZAbrA5EDlQHLgOsAeOA-UIAZAC2AOcBiADFgGQgMjAZMA0IBowDSgGpgNoAbcA3QBwQDpAHYAOzAd0A8CB5IHlAPaAe6A-QB9gYAOAFsBkYDQgG6AOJAdmA90NAMARUAkQBh4DGAGTgM5AZ4Az4ByQDlAHWAPwEABgAtgNCAboA4kB2YD3REAkBIgDDwGTgM5AZ8A5IBygDrAH4CoBgATAFNgLzAYeAyIBnIDPAGfANyAckA5QB-AoAIA0IBrwDiQH2DIBYATAF5gMPAZEAzkBngDPgHJAOUAfEA_AYADAaEA4kB9g6BeABUADIAHAAQAAyABpAEQARQAmABPAC-AGIAUoA7wCLAF1ARUAkQBhoDDwGJAMYAY8AyQBk4DKgGWAMuAZyAz4BokDSANJAaWA04BqoDWAGxgN1AcXA5IDlQHLgOsAeOA9IB6oD5QH1gPwHAHwAtgDnAHcAQgBiADFgGQgMmAZeA0KBooGjANKAaaA1MBrwDaAG2ANuAcTA48DkAHSAOwAdmA8CB5IHlAPaAe6A-IB9gD8QH7EICwAGQAmABfADEAO8BIgDDwGJAMiAZOAzkBngDPgGiANJAaWA1UBwADkgHWAPHAfgQAIADnAaEA0UBpQDUwG2ANuAcSA6MB2EDyQPKAeiA90B8QD7AH7EoDAAGQAOABEACYAF8AMQApQBqgDvALqAioBIgDDwGRAMnAZYAzkBngDPgGkANYAcAA6wB-BIAUAO4BiwDSgG5AOJAdIA7AB5QD2gH2FIEoAFQAMgAcABAADIAGkARABFACYAE8AKQAXwAxAClAGqAO8AiwCRAGGgMPAYwAyIBkgDJwGXAM5AZ4Az6BpAGkwNYA1kBsYDdYHJgcoA5cB1gDxwHygPwKAFABzgDuALqAxYBkwDRAGlANNgakBqYDXgHBAOJAdgA7MB5QD2gHugPiAfYA_YA.f_gAAAAAAAAA&partnertok=eyJhbGciOiJIUzI1NiIsImtpZCI6InR1bmVpbiIsInR5cCI6IkpXVCJ9.eyJ0cnVzdGVkX3BhcnRuZXIiOnRydWUsImlhdCI6MTY0MjA5OTA4OSwiaXNzIjoidGlzcnYifQ.lHS2wM3X_1OBMWllZXm4SFuLlvIaF92RC0UI7VYlDfc"},
    {name = "Linköpings Närradio", url = "https://stream.linkopingsnarradio.se:8005/radioprogram"},
    {name = "NRJ", url = "http://live-bauerse-fm.sharp-stream.com/nrj_instreamtest_se_mp3"},
    {name = "Pirate Rock Västkustens Bästa Rock", url = "http://stream.piraterock.se:8101/webradio"},
    {name = "Borås Närradio", url = "http://lyssna.fnf.nu:8080/radioboras.mp3"},
    {name = "MRS 905 Stockholm", url = "http://radiostreamone.mine.nu/MRS9050one"},
    {name = "Raggarradio", url = "http://151.80.42.191:8252/;?1689860071314"},
    {name = "Puls FM Borås", url = "http://stream.pulsfm.se:8908/stream"},
    {name = "Radio Treby", url = "http://streaming.943.se/treby878"},
    {name = "P4 Kalmar", url = "https://http-live.sr.se/p4kalmar-mp3-192"},
    {name = "Radio 94,3", url = "http://stream.radio943.se:8000/stream_high"},
    {name = "Puls FM Varberg", url = "http://varberg.pulsfm.se:8708/stream/1/"},
    {name = "Radio Falköping", url = "http://radio.fnf.nu/fnf.mp3"},
    {name = "Göteborgs Närradio 949 Mhz", url = "http://lyssna.fnf.nu:8080/gnf094.mp3"},
    {name = "Bandit Ballads", url = "https://wr21-ice.stream.khz.se/wr21_aac"},
    {name = "Gold FM Växjö, Sweden", url = "https://live-bauerse-fm.sharp-stream.com/goldfm_web_se_aacp?direct=true&amp;listenerid=undefined&amp;aw_0_1st.bauer_listenerid=undefined&amp;aw_0_1st.playerid=BMUK_inpage_html5&amp;aw_0_1st.skey=1678939562&amp;aw_0_1st.bauer_loggedin=false&amp;aw_0_req.userConsentV2=CPot5gAPot5gAAGABCENC7CsAP_AAE_AABJ4IoNF5GdUTXFBOH59YJtwKYxXx1BwoKAhBgAFA4AAyJIELJAGVEEaJAyKACACAAYAIEIBAABAEAFAAAgAYIEBIACEAEEEJAAAIAAAEEABIEQAEAAMAAAAUAIAgEBWEhAggBQA4RJETMBACoABCUAwigkEAAAAAgAAAAAAQAAAAAAAAAAAAAAAAAAAgAQNvgEAAIAJ-AXUA7YB-wF2gNoAbeAoEgVgAIAAXABQAFQAMgAcAA8ACAAGQANIAiACKAEwAJ4AVQA3gBzAD8AISARABEgCOAEsAKUAZAA-AB-wD_AQAAigBGACOAEmAJSAT8AoIBigDaAIdATKAtgBeYDDQGSAMnAbeBEMIAKABIAD8ARQA5wCBgHVATYApsBdQDFg0AgAZABAACMAEmgLQAtIB1QEOgMnDABADZAHUATYApsRAHAGQAQAAjABJgDqgIdAZOIABAAkATYKgDgAUACYAI4AjkBaAFpAWwAvMUACAOqAmwZAFACYAI4AjgC2AF5jAAYB1QEnAJsHQMwAFwAUABUADIAHAAQAAuABkADQAH0ARABFACYAE8AKoAYgAzABvADmAH6ARABEgCWAFGAKUAZAAygBogD9AH-AQMAigBFgCMAEcAJMASkAn4BQYC0ALSAYoA2gB1AEOgJUAVYAtgBdoC8wGGgMkAZOAywBt44AsACQAH4AUAAyACKAEcAOcAdwBAACIgGBAOOAdIA6oCYoEyATKAmwBSACmwFqALqAYsQgNgALAAoABkAFwATAAqgBiADMAG8ARwApQBlAD_AIoARwAlIBQYC0ALSAYoA2gB1AEqAKsAWwAu0Bk4DgCIAEA_ZAAOAOcA6oB2wEnAJiATYApAlAbAAQAAsACgAGQAOABEACYAFUAMQAZoBEAESAI4AUYApQBlAEcgLQAtIBigDqAIdAWwAu0BeYDJwGWANvAcASADgBkAFyAO4AgAB1QE2AMWKQKAAFwAUABUADIAHAAQAAyABpAEQARQAmABPACkAFUAMQAZgA5gB-gEQARIAowBSgDIAGUANEAfoBFgCMAEcAJSAUEA2gCHQEnAKsAWwAu0BeYDDQGSAMnAZYA28qABAP2UAKAAkAB-AGQANoAjgBcgDnAHcAQAAkQBigDqgHbATEAmUBNgCkAFNgMWAakAAA.YAAAAAAAAAAA"},
    {name = "Mix Megapol 104,3", url = "https://live-bauerse-fm.sharp-stream.com/mixmegapol_instream_se_mp3"},
    {name = "P4 Västernorrland", url = "https://http-live.sr.se/p4vasternorrland-mp3-192"},
    {name = "Radio Skövde", url = "http://video.webbplay.se:1935/liveradio/narradio/playlist.m3u8"},
    {name = "Radio Sandviken", url = "http://rssand.se:4027/;"},
    {name = "Hitmix90'S", url = "https://wr19-ice.stream.khz.se/wr19_mp3"},
    {name = "Radioapans Knattekanal Sveriges Radio Barnradion", url = "https://http-live.sr.se/knattekanalen-aac-192"},
    {name = "Radio 88 Partille - Golden Hits", url = "https://streaming.943.se/radio88dans"},
    {name = "Radio Gbg Sevdah", url = "https://stream.radiogbg.se:8050/relay4"},
    {name = "Power Hit Radio", url = "https://fm04-ice.stream.khz.se/fm04_mp3"},
    {name = "Power Club", url = "https://wr06-ice.stream.khz.se/wr06_mp3"},
    {name = "Radio Hope", url = "https://s2.radio.co/sfbf5f5b85/listen"},
    {name = "Retreat Radio", url = "http://retreatradio.out.airtime.pro:8000/retreatradio_b"},
    {name = "Rocket FM Rock Home Of Stockholm", url = "http://stream.thsradio.se:8000/rocket_hi.mp3"},
    {name = "Scenesat Radio AAC+ Mobile", url = "http://oscar.scenesat.com:8000/scenesatmed"},
    {name = "Scenesat Radio MP3", url = "http://oscar.scenesat.com:8000/scenesatmax"},
    {name = "Radio Payam", url = "https://stream-172.zeno.fm/vd7p6g922rhvv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJ2ZDdwNmc5MjJyaHZ2IiwiaG9zdCI6InN0cmVhbS0xNzIuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IlVWNGtVNURwVGZpd1pjTXd4djJFQ3ciLCJpYXQiOjE3MjQ4MzAxOTgsImV4cCI6MTcyNDgzMDI1OH0.ZLYUflN4rL58yty4G0JipVKTqBZush5yvaa5a0OTtu0"},
    {name = "Radio Bubbla", url = "http://live.radio.bubb.la/stream.mp3"},
    {name = "Radio Sotenäs", url = "https://sc1.radiosotenas.se/"},
    {name = "Radio Nostalgi", url = "https://live-bauerse-fm.sharp-stream.com/nostalgi_aacp"},
    {name = "Radio 45", url = "https://ssl-streaming.nordblommedia.se/amal.mp3"},
    {name = "SR P2", url = "https://edge1.sr.se/p2-flac"},
    {name = "SR P2 Musik HLS 192 RW", url = "https://live-cdn.sr.se/pool2/p2musik/p2musik.isml/p2musik-audio%3d192000.m3u8"},
    {name = "Stockholm FM 1011 Mhz Sweden", url = "http://live.narradio.se:8030/;stream.mp3"},
    {name = "Stocholm Närradio FM 953", url = "http://live.narradio.se:8020/;stream.mp3"},
    {name = "Radio Sydväst Närradio Stockholm FM 889", url = "http://radiosydvast.duckdns.org:12932/stream"},
    {name = "Radio Laholm", url = "http://stream-153.zeno.fm/tf8vczzxrg0uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJ0Zjh2Y3p6eHJnMHV2IiwiaG9zdCI6InN0cmVhbS0xNTMuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IkVQZUxqNmwzUWxTWXVuYXM5UUQxa0EiLCJpYXQiOjE3MjQ4NTE0NTEsImV4cCI6MTcyNDg1MTUxMX0.eZh6Gm8G_iZoM26M2VfSzzzf8C8qIUJuNzF7UixBAOA"},
    {name = "Skärgårdsradion", url = "http://fm06-ice.stream.khz.se/fm06_mp3"},
    {name = "Stockholm FM 880 Mhz Sweden", url = "http://live.narradio.se:8010/;stream.mp3"},
    {name = "Sveriges Radio - Ekot Sänder Direkt", url = "http://http-live.sr.se/ekotsanderdirekt-aac-192"},
    {name = "Sveriges Radio - P1", url = "http://http-live.sr.se/p1-aac-192"},
    {name = "Soul Classics", url = "https://wr08-ice.stream.khz.se/wr08_mp3"},
    {name = "Miracle TV", url = "http://miracle_manager-01.stream.boxigy.com/hls/miracle1_high/index.m3u8"},
    {name = "RIX FM Fresh", url = "https://wr04-ice.stream.khz.se/wr04_mp3"},
    {name = "RIX FM 106,7", url = "https://fm01-ice.stream.khz.se/fm01_aac"},
    {name = "Star FM", url = "http://fm05-ice.stream.khz.se/fm05_mp3"},
    {name = "Sveriges Radio - P2 Språk Och Musik", url = "http://http-live.sr.se/p2-aac-192"},
    {name = "Star 70'S", url = "http://wr10-ice.stream.khz.se/wr10_mp3"},
    {name = "Svensk Folkmusik - Akka Radio", url = "http://mediaserv38.live-streams.nl:8107/stream"},
    {name = "Sveriges Radio - P3 Din Gata", url = "http://http-live.sr.se/dingata-aac-192"},
    {name = "Sveriges Radio - P4 Plus", url = "http://http-live.sr.se/srextra17-aac-192"},
    {name = "Sveriges Radio - P6", url = "http://http-live.sr.se/srinternational-aac-192"},
    {name = "Sveriges Radio - SR Extra 1", url = "http://http-live.sr.se/srextra01-aac-192"},
    {name = "Sveriges Radio - SR Extra 10", url = "http://http-live.sr.se/srextra10-aac-192"},
    {name = "Sveriges Radio - SR Extra 4", url = "http://http-live.sr.se/srextra04-aac-192"},
    {name = "Sveriges Radio - SR Extra 7", url = "http://http-live.sr.se/srextra07-aac-192"},
    {name = "RIX FM", url = "https://fm01-ice.stream.khz.se/fm01_mp3"},
    {name = "Sveriges Radio - P2", url = "http://http-live.sr.se/p2musik-aac-192"},
    {name = "SVT P1 192Kps", url = "http://http-live.sr.se/p1-mp3-192"},
    {name = "Radio10 Classic", url = "https://streaming.radio.co/sfbb7cdc28/listen"},
    {name = "Radio10 Worship", url = "https://s2.radio.co/sadf67c8ed/listen"},
    {name = "Stockholm FM 88,0 Sweden", url = "http://radiostreamsix.mine.nu/18000"},
    {name = "Retro FM Skåne", url = "https://live-bauerse-fm.sharp-stream.com/retrofm_aacp?ua=WEB&aw_0_1st.playerid=SBS_RP_WEB&aw_0_1st.skey=1575715192&companionAds=true&listenerId=@@GUID@@"},
    {name = "Sveriges Radio - Radioapans Knattekanal", url = "https://http-live.sr.se/knattekanalen-mp3-192"},
    {name = "SR P2 Musik HLS 48 RW", url = "https://live-cdn.sr.se/pool2/p2musik/p2musik.isml/p2musik-audio%3d48000.m3u8"},
    {name = "Sveriges Radion P4 Östergötland", url = "https://http-live.sr.se/p4ostergotland-mp3-192"},
    {name = "Sveriges Radio P4 Stockholm", url = "https://http-live.sr.se/p4stockholm-mp3-192"},
    {name = "Sveriges Radio - SR Extra 6", url = "http://http-live.sr.se/srextra06-aac-192"},
    {name = "Sveriges Radio - SR Extra 3", url = "http://http-live.sr.se/srextra03-aac-192"},
    {name = "Sveriges Radio - SR Extra 5", url = "http://http-live.sr.se/srextra05-aac-192"},
    {name = "Sveriges Radio - SR Extra 2", url = "http://http-live.sr.se/srextra02-aac-192"},
    {name = "Sveriges Radio - SR Extra 8", url = "http://http-live.sr.se/srextra08-aac-192"},
    {name = "Wolf Fm", url = "http://192.121.234.119:1220/stream.flv"},
    {name = "Sveriges Radio - SR Extra 9", url = "http://http-live.sr.se/srextra09-aac-192"},
    {name = "Svensk Pop", url = "http://edge-bauerse-01-gos2.sharp-stream.com/svenskpop_se_mp3?"},
    {name = "Spinning Seal FM", url = "https://stream-173.zeno.fm/9q3ez3k3fchvv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiI5cTNlejNrM2ZjaHZ2IiwiaG9zdCI6InN0cmVhbS0xNzMuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IkZ5VmJEaVJZUWtxbV9ZSFh0Q29UWVEiLCJpYXQiOjE3MjQ4MDkyNzIsImV4cCI6MTcyNDgwOTMzMn0.YfNbpwbHbYdrADI_MaansJ1okQnT423Laa7cNSGdnqc"},
    {name = "Translation Of The Quran In Swedish", url = "https://server3.quraan.us:8036/"},
    {name = "Sveriges Radio P2", url = "https://http-live.sr.se/p2musik-aac-320"},
    {name = "Sveriges Radio - P4 Halland", url = "https://static-cdn.sr.se/laddahem/podradio/2022/03/karlavagnen_hur_gick_det_till_nar_du_traff_20220326_0017174611.mp3"},
    {name = "Zapa Music 247", url = "https://stream-153.zeno.fm/l5rfoayhm3ktv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJsNXJmb2F5aG0za3R2IiwiaG9zdCI6InN0cmVhbS0xNTMuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IllSdEc4clpvVHBpaEtVRUZBclRGTkEiLCJpYXQiOjE3MjQ4NDQ3NDcsImV4cCI6MTcyNDg0NDgwN30.vN-uoAgBH2M03uoKkCW7QMcmy7_c4652zJH_5KcC-CQ"},
    {name = "The ERICADE Radio Network", url = "https://radio.ericade.net/sc/stream/1/"},
    {name = "SR P2 Musik HLS 96 RW", url = "https://live-cdn.sr.se/pool2/p2musik/p2musik.isml/p2musik-audio%3d96000.m3u8"},
    {name = "Vinyl FM", url = "https://edge-bauerse-06-thn.sharp-stream.com/vinylfm_instream_se_mp3?"},
    {name = "Sveiges Radio - P4 Kristianstad", url = "https://http-live.sr.se/p4kristianstad-mp3-192"},
    {name = "Sveiges Radio - P4 Malmöhus", url = "https://http-live.sr.se/p4malmo-mp3-192"},
    {name = "Star 80'S", url = "http://wr02-ice.stream.khz.se/wr02_mp3"},
    {name = "Star 90'S", url = "http://wr12-ice.stream.khz.se/wr12_mp3"},
    {name = "Sveriges Radio - P3", url = "https://http-live.sr.se/p3-mp3-192"},
    {name = "STAR FM 107,1", url = "https://fm05-ice.stream.khz.se/fm05_mp3"},
    {name = "Sveriges Radio - SR Sápmi", url = "http://http-live.sr.se/srsapmi-aac-192"},
    {name = "Sveriges Radio P1", url = "https://http-live.sr.se/p1-mp3-192"},
    {name = "Liveatc ESSL Twrappcontrol", url = "http://s1-fmt2.liveatc.net:80/essl?nocache=2024082720282639527"},
    {name = "Sveriges Radio P4 Göteborg", url = "https://http-live.sr.se/p4goteborg-mp3-192"},
    {name = "Sveriges Radio P4 Gotland", url = "https://http-live.sr.se/p4gotland-mp3-192"},
    {name = "Göteborgs Närradio 1031 Mhz", url = "http://lyssna.fnf.nu:8080/gnf103.mp3"},
    {name = "Radio Rivendell", url = "https://play.radiorivendell.com/radio/8000/radio.mp3"},
    {name = "Radio Orinoco", url = "https://icecast.radio-orinoco.com/orinoco"},
    {name = "Radio Rainbow", url = "https://wr20-ice.stream.khz.se/wr20_mp3?platform=web"},
}

return stations