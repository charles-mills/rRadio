local stations = {
    {name = "Cawtv", url = "https://stream-151.zeno.fm/m8aakwyw9u8uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJtOGFha3d5dzl1OHV2IiwiaG9zdCI6InN0cmVhbS0xNTEuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6InduaFkwZzFCUkNDb21NVWczTC1yVFEiLCJpYXQiOjE3MjQ2NzcyODcsImV4cCI6MTcyNDY3NzM0N30.kCaP9HuAvf3MhEn63IvMzkb-llGR4_xjJtQuNO-zpVE"},
    {name = "Estéreo Romance", url = "https://stereoromance.radioca.st/streams/128kbps.m3u"},
    {name = "Exa FM", url = "https://14553.live.streamtheworld.com:443/XHPSFMAAC.aac"},
    {name = "La Voz Del Norte", url = "https://stream-176.zeno.fm/cbd1wweamzzuv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJjYmQxd3dlYW16enV2IiwiaG9zdCI6InN0cmVhbS0xNzYuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6ImFaTjBWNHNaU2ZLeDUwQ0xobjg2ZkEiLCJpYXQiOjE3MjQ2OTg2NDMsImV4cCI6MTcyNDY5ODcwM30.-za5WcSUZrgJinS32egSqfRzcaM0rmkfSDBLCAMTKI0"},
    {name = "Masaya Rebelde", url = "https://stream-173.zeno.fm/bhutktvbfv8uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJiaHV0a3R2YmZ2OHV2IiwiaG9zdCI6InN0cmVhbS0xNzMuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IjhNOGFqUmZ1UVhtTW9PUWd1WFM4dnciLCJpYXQiOjE3MjQ2NzM1MTksImV4cCI6MTcyNDY3MzU3OX0.O7Y350kiqPdciUlm_f0tu08oQAQNTrv5F_gt8qVEJaU"},
    {name = "Radio Católica De Nicaragua", url = "http://198.27.68.65:8555/stream"},
    {name = "Radio Comunidad", url = "https://stream-157.zeno.fm/q70e6btc2d0uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJxNzBlNmJ0YzJkMHV2IiwiaG9zdCI6InN0cmVhbS0xNTcuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IndpanY0NjlrUjhHeTVENDVjLThOR2ciLCJpYXQiOjE3MjQ2NTc0MTMsImV4cCI6MTcyNDY1NzQ3M30.1ciUTSfxsA6tWnFpljaAvSegj8JuzN5pkF5uVkJRsw4"},
    {name = "Radio Estereo Música", url = "http://stream-152.zeno.fm/8mwf6ssgtceuv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiI4bXdmNnNzZ3RjZXV2IiwiaG9zdCI6InN0cmVhbS0xNTIuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IjZReGY2VXFlU0lhVEtUUjdkOGxOaWciLCJpYXQiOjE3MjQ2ODgwNzksImV4cCI6MTcyNDY4ODEzOX0.x2w6xypGgqKVz8uFLQEWq4dOUbM6wH7agmYOcMEy40U"},
    {name = "Radio Estrella Del Mar", url = "https://streamer.radio.co/sd5242d0b6/listen"},
    {name = "Radio Hermanos", url = "https://stream-160.zeno.fm/vq7z0a3u7mruv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJ2cTd6MGEzdTdtcnV2IiwiaG9zdCI6InN0cmVhbS0xNjAuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IkRDVHAxSnNzVG1DckFjblBqUlQycGciLCJpYXQiOjE3MjQ2NjY1NDAsImV4cCI6MTcyNDY2NjYwMH0.QcNpU8uaV4j4aHo7TSqrhus1u_rEvKLraBMoBOiwz8M"},
    {name = "RADIO MARIA NICARAGUA", url = "http://dreamsiteradiocp4.com:8048/stream"},
    {name = "Radio Nicaragua", url = "https://online.radionicaragua.com.ni/stream.mp3"},
    {name = "Radio Oxigeno", url = "https://polaris.hostingnica.net/8060/stream/1/"},
    {name = "Radio República", url = "https://stream-151.zeno.fm/3kruxu5a9s8uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiIza3J1eHU1YTlzOHV2IiwiaG9zdCI6InN0cmVhbS0xNTEuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6Ikd2UmoyVHBhUk9lRmZmZDY0SVpqTHciLCJpYXQiOjE3MjQ2Njc4NjQsImV4cCI6MTcyNDY2NzkyNH0.xT7x-siEkYtGnluSKHceHnd4rhbgsbnwX_20Nx8V3OY"},
    {name = "Radio Sendas FM", url = "http://74.91.125.187:8028/stream"},
    {name = "Radio Vandalica Nicaragua", url = "https://stream-159.zeno.fm/caq3fwn1fnruv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJjYXEzZnduMWZucnV2IiwiaG9zdCI6InN0cmVhbS0xNTkuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IkJoWkszdkRpUnRlZVE4dGNQbl9OOHciLCJpYXQiOjE3MjQ2ODcxMDQsImV4cCI6MTcyNDY4NzE2NH0.D3RmkXt_YwzRpp0EERgOPhU4YariODCgkYPPNLLq_sU"},
    {name = "Radio Vos Matagalpa", url = "https://c13.radioboss.fm:18504/radiovosmatagalpa"},
    {name = "Union Nacional Patriotica", url = "https://stream-171.zeno.fm/ap6umv11pzzuv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJhcDZ1bXYxMXB6enV2IiwiaG9zdCI6InN0cmVhbS0xNzEuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6ImNXbVJCQ3czVDZ5ZnNWLUFXWHZvUXciLCJpYXQiOjE3MjQ2ODI3OTUsImV4cCI6MTcyNDY4Mjg1NX0.MAIzJs1dzL6z24PIE6v0Eb9UVaBiiTIJICZ27UKZB-8"},
}

return stations
