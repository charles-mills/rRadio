local stations = {
    {name = "Kuma FM 1010", url = "http://5.39.16.62:8004/tre"},
    {name = "Nõmmeraadio", url = "http://149.210.138.12:8000/nommeraadio"},
    {name = "Duo Rock", url = "http://le03.euddn.net/26f040cf1322b21f28059dfc6e3718434443e4dab82c15399c63e82134c4edce7927c42d7de732c0c43a10ca07f2df22248842298ec52c26c1e5d1c0a095b9e6b4c4c2ae5f230cdc9d85f12a60c94d847e6d4ff34f4341c318c3398fa8db05ce91cd6b2a28bea9e53d1a86056e6693b95f0fdde53c9bcadde13afc412ec4ecdd098a0a886aa475450e6be21e0aa1640a977700189e8bc300ac6d7e28ad2fd655/rokk.aac"},
    {name = "Elmari Tantsuõhtu 247", url = "http://le06.euddn.net/ae8821b28a7ca7c6ddaf673b4ee3c0458a952561d983bb63ec515fa5d7770f7309dc7883405cad14b4e6d606be0c2e88cf797f09212f2fac552f26ffe4c1ce6aec65ef71ad9508fefc3ec62528c09b3ec49f63d556f3f18b205a4443f6074e9675c7e31610197735b447dc2343bf9fe282cfc05c4272b471b2bd5b07b254d9cf4ddd6dba52319f62a590b206d5144be1c6a4fb61bfa69e3344f293ba1432ef47ef3ea702ad52b3c3d19db1cce7f44d8b04927aef2c3cc776aaf8fa295de1faea/elmaritantsuohtu.aac"},
    {name = "Myhits", url = "http://le04.euddn.net/2517c1b4350b5ce29aa716f7f6c0f8edd8bd700ca9a9833596bb1f7c9b3804d12729a72a85dee6b2cb7e777f7884c7991ab6fb59aaf4d8c04dca16532b73ee602050bbc9db390034c3bc513ee3f46a2afde7ee9d6518d0bfd7b44579452c32fa913fe99badff2439ba2bc3c66d988376d14f8df4bf6d9bc600db66a5792f5e762b7f93f99c1f15f633127e7131df69c6d5d5225a6262ba7ed1e0e855c5253d9bf56bbb4ad2e7eb6890abeebebf5e89d3/myhits.aac"},
    {name = "IDA", url = "https://broadcast.idaidaida.net:8000/stream"},
    {name = "ERR Raadio 2 - 320Kbps", url = "http://icecast.err.ee/raadio2korge.mp3"},
    {name = "Kaguraadio", url = "https://locomanoco.vlevelscdn.net/radio/kaguraadio.stream/playlist.m3u8"},
    {name = "Finest Radio", url = "https://shoutcast.finestfm.fi/stream/1/:80/;stream"},
    {name = "R2Extra Altpop", url = "https://lonestarr.err.ee/live/r2altkorge/index.m3u8?id=95846420454178&short=true"},
    {name = "Raadio Tallinn", url = "http://icecast.err.ee/raadiotallinn.mp3?type=.mp3/;stream.mp3"},
    {name = "Raadio Duo", url = "https://le03.euddn.net/643e1d6549b37ef476e9291c8a2416f4c7a26fd8c57720075bfc75e9f8989cec756cd63e9bedeab335cb6d27c3cf06643a3b5e57c811be0e6789ef0d2b81e1d1a37bb18b37f32cd4af628f7044d43fa5f323de0c4edf8f1019b07a3fdeb4bac2410fbbe27a31a7c3f9c3d63da38af0935a770bf4447693219bf8317e70ab02c958b988455d7b1b47dc0715c9eaf503c9ecccde7213c5b4c9a328e2377aeac41517a186c7148f9b516b9cd799b32b8d8c/radioduo.aac"},
    {name = "Raadio Elmar", url = "https://le04.euddn.net/a68cd668d2b366806c04b5850b5bc2f3e37fada7afa1e98adcc7bc0532b509d4c41e14a72367a753f817edfc58e4cecd3dab7a8cb91870167f1d63dd1aba4698af38b7d0e3a7006098459eeed25313ed10c89fa01ff1ac157f28956856410c37edc5908b7aa9cd938df3848e9fa9be2f9cf5ce818a2f2634ef828ea32058a65b0f6d2f2673b5932ce6d0b9d878fa59cf87e3ca95f3f27c0ceb4b4e042608fcf7665d822658e5825bc811e57f4092c378/elmar.aac"},
    {name = "Sss-Radio", url = "http://217.146.76.112:8000/sss-radio"},
    {name = "ERR Klassikaraadio", url = "http://icecast.err.ee/klassikaraadio.mp3"},
    {name = "ERR Raadio 4", url = "http://icecast.err.ee/raadio4.mp3?type=.mp3/;stream.mp3"},
    {name = "Klara Nostalgia", url = "https://icecast.err.ee/klaranostalgia.mp3"},
    {name = "Raadio Kuku", url = "https://le01.euddn.net/0c94e80fb73bb74ba08ef54204f1a5b8f88dd5b6a25c34ef5e819a20f96be1e75a5899c0032d7cfdf7c5d39d9974fde51ca938411dd27942e7fd25b15603745477322f5e4bf80c0c508c4fc22c70864ed51c6fa8775587b215b33885859e118a08519ddcbd4f00bc1384c538c1216368243d46ca0fa259e557ad6a64f1cb37f0ef52a56ba280f53bcb532811f615d527ab65a2c640021459f927474f475a33a664885ea28cd2da92e15d1991dd1598d6/kuku_high.mp3"},
    {name = "Duo Party", url = "https://le01.euddn.net/d08f4b4f98f2b6cb22200470b43b099302a4124625cf7cb0231e6a81a49a87b97ccab5368c59b570004edc9d8340384163a67155c1551a3b5a3b4552e8d5d4ac239e16bcd41da4f9072b5b45bce3c3b62c7fd3eb60f4bf9dfb5b1f70ba89a7ed2ca84ad1a5c7bc80ac1e12c9f97da5e697a92de1c3f98f38792b36d095de6873822ce914325a0c3c0e8783d258719163a7a2bb799c8c25b6d5eb6d602494059cfdb05f2366f229cb34c7998825f1b2d9/duodance.aac"},
    {name = "Hard FM Estonia", url = "http://s5.radio.co/s69e02764f/listen"},
    {name = "DFM", url = "https://le10.euddn.net/6ba757fbb07c38b4203333f8da597dfe02364614545d611faee0cae3d5054c28998483e6a36ae77e8017007b680acfd8f3d9469776bc6bf03bec160af728b4e948a98efed04587b8dfe7a058ed6643a614aa6443b182f8f2ae0ccbd5fbb35c505217badbf4aff456020c96c0a214f787619f1c7ac0b589b36b9388395e577132f54b72799791f65ab27e574488f80f605c7d5d207c982f533fa02509dd85d1d6/dfm.mp3"},
    {name = "Pereraadio Tallinn", url = "http://icecast.pereraadio.ee:8000/Tallinn"},
    {name = "Pereraadio Tartu", url = "http://icecast.pereraadio.ee:8000/Tartu"},
    {name = "Radio Eli", url = "http://icecast.pereraadio.ee:8000/RadioEli"},
    {name = "ERR Raadio 2", url = "http://icecast.err.ee/raadio2.mp3"},
    {name = "Klara Klassika 128 Kbps Ogg Opus | Eesti Rahvusringhääling | Erree", url = "http://icecast.err.ee/klaraklassika.opus"},
    {name = "Klara Jazz", url = "https://icecast.err.ee/klarajazz.mp3"},
    {name = "Klara Klassika", url = "https://icecast.err.ee/klaraklassika.mp3"},
    {name = "Semeinoje Radio", url = "http://icecast.pereraadio.ee:8000/Semeinoje"},
    {name = "R2 Eesti", url = "https://icecast.err.ee/r2eestikorge.mp3"},
    {name = "Relax FM Eesti", url = "https://edge05.cdn.bitflip.ee:8888/relax?_i=5b849172"},
    {name = "Raadio 7", url = "https://edge05.cdn.bitflip.ee:8888/R7"},
    {name = "Pereraadio Kuressaare", url = "http://icecast.pereraadio.ee:8000/Kuressaare"},
    {name = "Sky Plus", url = "https://edge01.cdn.bitflip.ee:8888/SKYPLUS?_i=416d8856"},
    {name = "Klassikaraadio 128 Kbps Ogg Opus | Eesti Rahvusringhääling | Klassikaraadioerree", url = "http://icecast.err.ee/klassikaraadio.opus"},
    {name = "Rock FM", url = "https://edge02.cdn.bitflip.ee:8888/rck?_i=5f5ab186"},
    {name = "Raadio Relax FM", url = "https://edge02.cdn.bitflip.ee:8888/relax?_i=5b849172"},
    {name = "Retro FM Estonia", url = "https://edge02.cdn.bitflip.ee:8888/RETRO?_i=258f436b"},
    {name = "Relax Cafe", url = "https://edge05.cdn.bitflip.ee:8888/cafe?_i=416d8856"},
    {name = "Tartu Pereraadio", url = "http://bee.pereraadio.ee:8000/"},
    {name = "NRJ Tallinn", url = "https://edge03.cdn.bitflip.ee:8888/NRJ"},
    {name = "Raadio Relax International", url = "https://edge03.cdn.bitflip.ee:8888/international?_i=5b849172"},
    {name = "Raadio Tallinn 128 Kbps Ogg Opus | Eesti Rahvusringhääling | Raadiotallinnerree", url = "http://icecast.err.ee/raadiotallinn.opus"},
    {name = "Raadio 2 128 Kbps Ogg Opus | Eesti Rahvusringhääling | R2Erree", url = "http://icecast.err.ee/raadio2.opus"},
    {name = "VIKERRAADIO", url = "http://icecast.err.ee/vikerraadiokorge.mp3"},
    {name = "NRJ", url = "https://edge01.cdn.bitflip.ee:8888/NRJ?_i=5b8169cb"},
    {name = "Sooviraadio", url = "http://media.uunox.net:8888/;"},
    {name = "Võmba FM", url = "https://c4.radioboss.fm:18123/stream"},
    {name = "R2Chill", url = "http://icecast.err.ee/r2chill.opus"},
    {name = "Star Fm", url = "https://ice.leviracloud.eu/star96-aac"},
    {name = "Star FM Eesti", url = "https://ice.leviracloud.eu/starFMEesti96-aac"},
    {name = "Sky-Radio", url = "https://edge03.cdn.bitflip.ee:8888/SKY?_i=5b849172"},
    {name = "Klara Nostalgia 128 Kbps Ogg Opus | Eesti Rahvusringhääling | Erree", url = "http://icecast.err.ee/klaranostalgia.opus"},
    {name = "Sky Plus Dnb", url = "https://edge03.cdn.bitflip.ee:8888/NRJdnb"},
    {name = "Tre Raadio Rapla", url = "https://cdn.treraadio.ee/rapla-tre"},
    {name = "R2Pop", url = "http://icecast.err.ee/r2pop.opus"},
    {name = "Tre Raadio Ring FM", url = "https://cdn.treraadio.ee/ringfm"},
    {name = "R2P", url = "https://icecast.err.ee/r2p.opus"},
    {name = "Tre Raadio Pärnu", url = "http://cdn.treraadio.ee/parnu-tre"},
    {name = "Tre Raadio Ruut FM", url = "https://cdn.treraadio.ee/ruutfm"},
    {name = "R2Rock", url = "http://icecast.err.ee/r2rock.opus"},
    {name = "R2Altpop", url = "http://icecast.err.ee/r2alternatiiv.opus"},
    {name = "Vikerraadio 128 Kbps Ogg Opus | Eesti Rahvusringhääling | Vikerraadioerree", url = "http://icecast.err.ee/vikerraadio.opus"},
    {name = "Äripäeva Raadio", url = "https://ice.leviracloud.eu/aripaev128-mp3"},
    {name = "Tre Raadio Kesk-Eesti", url = "http://cdn.treraadio.ee/kesk-eesti-tre"},
    {name = "Power Hit Radio", url = "https://ice.leviracloud.eu/phr96-aac?"},
    {name = "Tre Raadio Virumaa", url = "http://sc2.treraadio.ee/viru-tre"},
    {name = "Tre Raadio Põhja-Eesti", url = "http://cdn.treraadio.ee/pohja-tre"},
    {name = "Радио 4 Raadio 4 128 Kbps Ogg Opus | Eesti Rahvusringhääling | R4Erree", url = "http://icecast.err.ee/raadio4.opus"},
}

return stations