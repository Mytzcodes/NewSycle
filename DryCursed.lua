--[[
  DryCursed v1.0.0  -  registry ID, codec & pengamat packet ByteNet untuk game 112863874972771
  Kompatibel Lua 5.3 / Luau. Hanya MEMBACA & MENDEKODE; tidak ada fungsi kirim (lihat docs/01-arsitektur.md, bagian anti-cheat).

  Pakai:
    local DC = loadstring(readfile("DryCursed.lua"))()
    DC.start()                                   -- sambung ke ByteNet (read-only) + muat peta ID live
    DC.on("moved", function(d) print(d.id, d.x, d.y) end)
    print(DC.Id.punch, DC.Name[68])              -- 68  punch   (tanpa hex)
    print(DC.pretty(DC.decode(DC.fromHex("09 01 26 08 00 00 00"))))

  Data di bawah dibangkitkan dari ekspor ScriptExport_112863874972771 + DOCUMENTRY (Net.lua + BytenetStorage.World).
--]]
local D = {}
D.packets = {
	displayChanged = {id=1,dir="s2c",rel="reliable",group="tiles",desc="Isi display box di x,y (daftar id, jumlah, waktu `at`).",schema={k="struct",sid=67,f={{"y","uint16"},{"x","uint16"},{"w","uint8"},{"list",{k="optional",of={k="array",of={k="struct",sid=66,f={{"id","uint16"},{"at",{k="optional",of="float64"}},{"n","uint32"}}}}}}}}},
	note = {id=2,dir="s2c",rel="reliable",group="rpc",desc="Push generik server: `e` = indeks di daftar NOTE, `w` = world tag, `a` = nilai campur.",schema={k="struct",sid=78,f={{"e","uint8"},{"w","uint8"},{"a",{k="array",of={k="struct",sid=77,f={{"j",{k="optional",of="bool"}},{"b",{k="optional",of="bool"}},{"s",{k="optional",of={k="array",of="string"}}},{"n",{k="optional",of="float64"}}}}}}}}},
	act = {id=3,dir="c2s",rel="reliable",group="presence",desc="Aksi/animasi pemain (`kind`) di posisi x,y. Dijaga penghitung seq.",schema={k="struct",sid=3,f={{"y","float32"},{"kind","uint8"},{"x","float32"}}}},
	treeChanged = {id=4,dir="s2c",rel="reliable",group="tiles",desc="Status pohon di x,y: `p` progres/waktu tanam, `f` buah, `s` status (opsional = tidak ada pohon).",schema={k="struct",sid=19,f={{"y","uint16"},{"x","uint16"},{"w","uint8"},{"tree",{k="optional",of={k="struct",sid=18,f={{"p","float64"},{"s","bool"},{"f","uint16"}}}}}}}},
	entered = {id=5,dir="s2c",rel="reliable",group="presence",desc="Pemain masuk dunia: nama, negara, skin, daftar pakaian (`worn`), userId Roblox.",schema={k="struct",sid=5,f={{"name","string"},{"country","string"},{"id","uint16"},{"worn",{k="array",of="uint16"}},{"userId","float64"},{"skin","uint8"}}}},
	list = {id=6,dir="c2s",rel="reliable",group="rpc",desc="Minta daftar dunia. Balasan: `worldsAnswer`.",schema={k="struct",sid=35,f={{"seq","uint16"}}}},
	donation = {id=7,dir="c2s",rel="reliable",group="commerce",desc="Donasi/ambil dari kotak donasi. Balasan: `donAnswer`.",schema={k="struct",sid=33,f={{"y","uint16"},{"x","uint16"},{"note",{k="optional",of="string"}},{"take",{k="optional",of={k="array",of="uint32"}}},{"n",{k="optional",of="uint16"}},{"seq","uint16"},{"give",{k="optional",of="uint16"}}}}},
	move = {id=8,dir="c2s",rel="unreliable",group="presence",desc="Posisi & kecepatan pemain lokal (unreliable, tick `t` uint16). Dikirim tiap beberapa frame.",schema={k="struct",sid=1,f={{"y","float32"},{"x","float32"},{"flags","uint8"},{"t","uint16"},{"vx","float32"},{"vy","float32"}}}},
	busy = {id=9,dir="c2s",rel="reliable",group="presence",desc="Penanda sibuk (0/1), mis. saat membuka panel. Terlihat di capture bersama `seq`.",schema="uint8"},
	moveTo = {id=10,dir="s2c",rel="reliable",group="presence",desc="Server memindahkan pemain ke x,y (w = world tag).",schema={k="struct",sid=61,f={{"y",{k="optional",of="float64"}},{"x",{k="optional",of="float64"}},{"w","uint8"}}}},
	burned = {id=11,dir="s2c",rel="reliable",group="presence",desc="Efek terbakar (float64, durasi/ID pemain). [diduga]",schema="float64"},
	trade = {id=12,dir="c2s",rel="reliable",group="commerce",desc="Aksi trade (`act` uint8, target userId, item, jumlah). Balasan: `answer`.",schema={k="struct",sid=34,f={{"on",{k="optional",of="bool"}},{"act","uint8"},{"id",{k="optional",of="uint16"}},{"userId",{k="optional",of="float64"}},{"seq","uint16"},{"n",{k="optional",of="float64"}}}}},
	wear = {id=13,dir="c2s",rel="reliable",group="presence",desc="Ganti pakaian: map slot(string) -> id item. Dijaga penghitung seq.",schema={k="map",key="string",val="uint16"}},
	openPack = {id=14,dir="c2s",rel="reliable",group="items",desc="Buka pack/paket item. Balasan: `bagAnswer`.",schema={k="struct",sid=28,f={{"seq","uint16"},{"id","uint16"}}}},
	left = {id=15,dir="s2c",rel="reliable",group="presence",desc="Pemain dengan `id` (uint16 sesi) keluar dunia.",schema="uint16"},
	drop = {id=16,dir="c2s",rel="reliable",group="items",desc="Jatuhkan item: id, jumlah `n`, posisi. Dijaga penghitung seq.",schema={k="struct",sid=7,f={{"id","uint16"},{"x","float32"},{"y","float32"},{"n","uint16"}}}},
	answer = {id=17,dir="s2c",rel="reliable",group="rpc",desc="Balasan umum {ok,msg,seq}.",schema={k="struct",sid=36,f={{"ok","bool"},{"msg",{k="optional",of="string"}},{"seq","uint16"}}}},
	feed = {id=18,dir="c2s",rel="reliable",group="items",desc="Beri makan/isi provider di x,y.",schema={k="struct",sid=24,f={{"y","uint16"},{"x","uint16"}}}},
	worldsAnswer = {id=19,dir="s2c",rel="reliable",group="rpc",desc="Daftar dunia (top, active, recent, counts, mine).",schema={k="struct",sid=46,f={{"seq","uint16"},{"lists",{k="optional",of={k="struct",sid=45,f={{"top",{k="optional",of="string"}},{"active",{k="array",of="string"}},{"recent",{k="array",of="string"}},{"counts",{k="map",key="string",val="uint16"}},{"mine",{k="array",of="string"}}}}}}}}},
	ask = {id=20,dir="c2s",rel="reliable",group="rpc",desc="RPC generik: `fn` = indeks nama di daftar ASK, `a` = argumen tipe-campur, `seq`. Balasan: `said`.",schema={k="struct",sid=74,f={{"a",{k="array",of={k="struct",sid=73,f={{"b",{k="optional",of="bool"}},{"t",{k="optional",of={k="map",key="string",val={k="struct",sid=72,f={{"b",{k="optional",of="bool"}},{"l",{k="optional",of={k="array",of="float64"}}},{"s",{k="optional",of="string"}},{"n",{k="optional",of="float64"}}}}}}},{"s",{k="optional",of="string"}},{"n",{k="optional",of="float64"}}}}}},{"fn","uint8"},{"seq","uint16"}}}},
	hubChanged = {id=21,dir="s2c",rel="reliable",group="commerce",desc="Status hub di x,y.",schema={k="struct",sid=70,f={{"y","uint16"},{"x","uint16"},{"w","uint8"},{"dir",{k="optional",of="string"}}}}},
	accessGiven = {id=22,dir="s2c",rel="reliable",group="world",desc="Pemain diberi akses ke dunia (`world`, `by`).",schema={k="struct",sid=58,f={{"world","string"},{"by","string"}}}},
	useOn = {id=23,dir="c2s",rel="reliable",group="presence",desc="Pakai item pada pemain lain (`target`, `mode`, posisi). Balasan: `answer`.",schema={k="struct",sid=27,f={{"y","float32"},{"x","float32"},{"target","uint16"},{"mode","uint8"},{"seq","uint16"},{"id","uint16"}}}},
	dropTaken = {id=24,dir="s2c",rel="reliable",group="items",desc="Drop `uid` diambil (sisa `n`).",schema={k="struct",sid=21,f={{"uid","uint32"},{"w","uint8"},{"n","uint32"}}}},
	took = {id=25,dir="s2c",rel="reliable",group="items",desc="Hasil `take`: jumlah didapat `got` (cocokkan lewat `seq`).",schema={k="struct",sid=9,f={{"seq","uint16"},{"got","uint16"}}}},
	inventorySync = {id=26,dir="s2c",rel="reliable",group="items",desc="Sinkron inventori penuh: slot (id,jumlah) + kapasitas.",schema={k="struct",sid=65,f={{"slots",{k="array",of={k="struct",sid=64,f={{"id","uint16"},{"n","uint32"}}}}},{"capacity","uint16"}}}},
	convert = {id=27,dir="c2s",rel="reliable",group="items",desc="Konversi lock/item `from` -> `to`.",schema={k="struct",sid=23,f={{"to","uint16"},{"from","uint16"}}}},
	leave = {id=28,dir="c2s",rel="reliable",group="presence",desc="Keluar dunia (tanpa payload).",schema="nothing"},
	toggle = {id=29,dir="c2s",rel="reliable",group="tiles",desc="Toggle objek di x,y (pintu/saklar). Dijaga penghitung seq.",schema={k="struct",sid=14,f={{"y","uint16"},{"x","uint16"}}}},
	look = {id=30,dir="s2c",rel="reliable",group="presence",desc="Perubahan tampilan pemain: skin + pakaian.",schema={k="struct",sid=10,f={{"id","uint16"},{"worn",{k="array",of="uint16"}},{"skin","uint8"}}}},
	acted = {id=31,dir="s2c",rel="reliable",group="presence",desc="Siaran `act` pemain lain (`id` + `kind` + posisi).",schema={k="struct",sid=4,f={{"id","uint16"},{"kind","uint8"},{"y","float32"},{"x","float32"}}}},
	tile = {id=32,dir="c2s",rel="reliable",group="tiles",desc="Letakkan/ubah tile: layer, x, y, id, flip. Dijaga penghitung seq.",schema={k="struct",sid=6,f={{"y","uint16"},{"x","uint16"},{"flip","bool"},{"id","uint16"},{"layer","uint8"}}}},
	take = {id=33,dir="c2s",rel="reliable",group="items",desc="Ambil drop `uid` sebanyak `want`. Balasan: `took`.",schema={k="struct",sid=8,f={{"want","uint16"},{"uid","uint32"},{"seq","uint16"}}}},
	vipPass = {id=34,dir="s2c",rel="reliable",group="world",desc="Daftar userId VIP/akses di dunia `w`.",schema={k="struct",sid=55,f={{"w","uint8"},{"list",{k="array",of="uint32"}}}}},
	recycle = {id=35,dir="c2s",rel="reliable",group="items",desc="Daur ulang item id sebanyak n (tanpa `seq`).",schema={k="struct",sid=22,f={{"id","uint16"},{"n","uint16"}}}},
	cycle = {id=36,dir="c2s",rel="reliable",group="items",desc="Ganti/siklus item (uint16 id). [diduga]",schema="uint16"},
	knocked = {id=37,dir="s2c",rel="reliable",group="presence",desc="Pemain terpental: arah `dir` (int8) dan `power`.",schema={k="struct",sid=59,f={{"power",{k="optional",of="float32"}},{"dir","int8"}}}},
	seq = {id=38,dir="c2s",rel="reliable",group="rpc",desc="Penghitung packet anti-cheat: `n` naik 1 setiap kirim packet terjaga (lihat Arsitektur).",schema={k="struct",sid=16,f={{"n","uint32"}}}},
	levelUp = {id=39,dir="s2c",rel="reliable",group="world",desc="Pemain naik level: nama, level, userId, hadiah gems.",schema={k="struct",sid=57,f={{"name","string"},{"gems",{k="optional",of="float64"}},{"level","uint16"},{"userId","float64"},{"reward",{k="optional",of="float64"}}}}},
	tileChanged = {id=40,dir="s2c",rel="reliable",group="tiles",desc="Siaran perubahan tile di dunia `w`.",schema={k="struct",sid=17,f={{"y","uint16"},{"x","uint16"},{"flip","bool"},{"id","uint16"},{"layer","uint8"},{"w","uint8"}}}},
	spin = {id=41,dir="c2s",rel="reliable",group="tiles",desc="Putar roda (wheel) di x,y. Dijaga penghitung seq.",schema={k="struct",sid=15,f={{"y","uint16"},{"x","uint16"}}}},
	moved = {id=42,dir="s2c",rel="unreliable",group="presence",desc="Posisi pemain lain; sama dengan `move` + `id` pemain.",schema={k="struct",sid=2,f={{"y","float32"},{"x","float32"},{"flags","uint8"},{"id","uint16"},{"t","uint16"},{"vx","float32"},{"vy","float32"}}}},
	said = {id=43,dir="s2c",rel="reliable",group="rpc",desc="Balasan RPC generik `ask` (cocokkan `seq`).",schema={k="struct",sid=76,f={{"seq","uint16"},{"a",{k="optional",of={k="array",of={k="struct",sid=75,f={{"j",{k="optional",of="bool"}},{"b",{k="optional",of="bool"}},{"s",{k="optional",of={k="array",of="string"}}},{"n",{k="optional",of="float64"}}}}}}}}}},
	useFx = {id=44,dir="s2c",rel="reliable",group="presence",desc="Efek visual pemakaian item (dari->ke, `who`, `said`).",schema={k="struct",sid=71,f={{"y",{k="optional",of="float64"}},{"x",{k="optional",of="float64"}},{"to",{k="optional",of="float64"}},{"from","float64"},{"id","uint16"},{"who",{k="optional",of="string"}},{"said",{k="optional",of="string"}}}}},
	vendChanged = {id=45,dir="s2c",rel="reliable",group="commerce",desc="Status vending di x,y: stok, harga, pendapatan.",schema={k="struct",sid=69,f={{"y","uint16"},{"x","uint16"},{"w","uint8"},{"info",{k="optional",of={k="struct",sid=68,f={{"y","uint16"},{"x","uint16"},{"stock","float64"},{"cost","float64"},{"id",{k="optional",of="uint16"}},{"earned","float64"},{"per","float64"}}}}}}}},
	dropAdded = {id=46,dir="s2c",rel="reliable",group="items",desc="Drop baru di dunia: `uid` unik, id, jumlah, posisi, `by` pemilik/penjatuh.",schema={k="struct",sid=20,f={{"y","float64"},{"uid","uint32"},{"by",{k="optional",of="float64"}},{"id","uint16"},{"x","float64"},{"w","uint8"},{"n","uint32"}}}},
	donationFull = {id=47,dir="s2c",rel="reliable",group="commerce",desc="Kotak donasi di x,y penuh/tidak (`full`).",schema={k="struct",sid=52,f={{"y","uint16"},{"x","uint16"},{"w","uint8"},{"full","bool"}}}},
	forceDie = {id=48,dir="s2c",rel="reliable",group="presence",desc="Server memaksa pemain respawn (tanpa payload).",schema="nothing"},
	bagAnswer = {id=49,dir="s2c",rel="reliable",group="rpc",desc="Balasan yang mengubah tas: item tambah/hapus, gems, slot.",schema={k="struct",sid=39,f={{"ok","bool"},{"remove",{k="optional",of={k="array",of={k="struct",sid=38,f={{"id","uint16"},{"n","uint32"}}}}}},{"rolled","bool"},{"slots",{k="optional",of="uint16"}},{"gems",{k="optional",of="float64"}},{"msg",{k="optional",of="string"}},{"seq","uint16"},{"add",{k="optional",of={k="array",of={k="struct",sid=37,f={{"id","uint16"},{"n","uint32"}}}}}}}}},
	worldClosed = {id=50,dir="s2c",rel="reliable",group="world",desc="Dunia ditutup; string = alasan/nama. [diduga]",schema="string"},
	worldNotice = {id=51,dir="s2c",rel="reliable",group="world",desc="Pesan dunia: teks + suara opsional.",schema={k="struct",sid=56,f={{"sound",{k="optional",of="string"}},{"text","string"}}}},
	impulse = {id=52,dir="s2c",rel="reliable",group="presence",desc="Dorongan fisik (vx,vy) ke pemain lokal.",schema={k="struct",sid=60,f={{"kind",{k="optional",of="string"}},{"vx","float32"},{"vy","float32"}}}},
	donated = {id=53,dir="s2c",rel="reliable",group="commerce",desc="Notifikasi donasi (item, nama, userId, jumlah).",schema={k="struct",sid=53,f={{"id","uint16"},{"name","string"},{"userId","float64"},{"n","uint16"}}}},
	harvest = {id=54,dir="c2s",rel="reliable",group="tiles",desc="Panen pohon di x,y. Dijaga penghitung seq.",schema={k="struct",sid=13,f={{"y","uint16"},{"x","uint16"}}}},
	surgeryTile = {id=55,dir="s2c",rel="reliable",group="tiles",desc="Status tile meja operasi (`on`).",schema={k="struct",sid=51,f={{"y","uint16"},{"x","uint16"},{"w","uint8"},{"on","bool"}}}},
	wheelSpun = {id=56,dir="s2c",rel="reliable",group="tiles",desc="Hasil roda diputar: nama pemutar, userId, angka `n`.",schema={k="struct",sid=50,f={{"y","uint16"},{"x","uint16"},{"name","string"},{"userId","float64"},{"w","uint8"},{"n","uint16"}}}},
	display = {id=57,dir="c2s",rel="reliable",group="commerce",desc="Isi/ambil display box. Balasan: `bagAnswer`.",schema={k="struct",sid=30,f={{"y","uint16"},{"x","uint16"},{"item",{k="optional",of="uint16"}},{"at",{k="optional",of="float64"}},{"seq","uint16"},{"n",{k="optional",of="uint16"}}}}},
	providerChanged = {id=58,dir="s2c",rel="reliable",group="tiles",desc="Status provider/mesin penghasil item di x,y (`s`: p,f,n).",schema={k="struct",sid=48,f={{"y","uint16"},{"x","uint16"},{"w","uint8"},{"s",{k="optional",of={k="struct",sid=47,f={{"p","float64"},{"f",{k="optional",of="float64"}},{"n",{k="optional",of="float64"}}}}}}}}},
	splice = {id=59,dir="c2s",rel="reliable",group="items",desc="Gabung seed di x,y (`seed`). Balasan: `spliced`.",schema={k="struct",sid=11,f={{"y","uint16"},{"x","uint16"},{"seq","uint16"},{"seed","uint16"}}}},
	donAnswer = {id=60,dir="s2c",rel="reliable",group="rpc",desc="Balasan khusus donasi: tampilan kotak, item diambil/diberi.",schema={k="struct",sid=44,f={{"view",{k="optional",of={k="struct",sid=41,f={{"each","uint16"},{"count","uint16"},{"max","uint16"},{"owner","bool"},{"mine","uint16"},{"gifts",{k="optional",of={k="array",of={k="struct",sid=40,f={{"note",{k="optional",of="string"}},{"by","string"},{"id","uint16"},{"g","uint32"},{"n","uint16"}}}}}}}}}},{"why",{k="optional",of="string"}},{"taken",{k="optional",of={k="array",of={k="struct",sid=43,f={{"id","uint16"},{"from","string"},{"n","uint16"}}}}}},{"seq","uint16"},{"given",{k="optional",of={k="struct",sid=42,f={{"id","uint16"},{"n","uint16"}}}}}}}},
	spawnMoved = {id=61,dir="s2c",rel="reliable",group="presence",desc="Titik spawn dunia dipindah (`stay` = pemain tetap di tempat). [diduga]",schema={k="struct",sid=54,f={{"y","uint16"},{"x","uint16"},{"w","uint8"},{"stay","bool"}}}},
	hubBuy = {id=62,dir="c2s",rel="reliable",group="commerce",desc="Beli lewat hub (posisi hub+vending). Balasan: `bagAnswer`.",schema={k="struct",sid=32,f={{"id","uint16"},{"vx","uint16"},{"per","uint32"},{"cost","uint32"},{"hx","uint16"},{"hy","uint16"},{"seq","uint16"},{"vy","uint16"}}}},
	vend = {id=63,dir="c2s",rel="reliable",group="commerce",desc="Operasi vending machine (`act`, harga `cost`, `per`). Balasan: `bagAnswer`.",schema={k="struct",sid=31,f={{"y","uint16"},{"x","uint16"},{"per",{k="optional",of="float64"}},{"act","uint8"},{"cost",{k="optional",of="float64"}},{"b",{k="optional",of="float64"}},{"seq","uint16"},{"a",{k="optional",of="float64"}}}}},
	switchChanged = {id=64,dir="s2c",rel="reliable",group="tiles",desc="Status saklar: `public`, `off`.",schema={k="struct",sid=49,f={{"y","uint16"},{"x","uint16"},{"public","bool"},{"w","uint8"},{"off","bool"}}}},
	spliced = {id=65,dir="s2c",rel="reliable",group="items",desc="Hasil splice (`made`).",schema={k="struct",sid=12,f={{"seq","uint16"},{"made","uint16"}}}},
	spray = {id=66,dir="c2s",rel="reliable",group="items",desc="Semprot item id (x,y opsional). Balasan: `answer`.",schema={k="struct",sid=26,f={{"y",{k="optional",of="uint16"}},{"x",{k="optional",of="uint16"}},{"seq","uint16"},{"id","uint16"}}}},
	doorPass = {id=67,dir="c2s",rel="reliable",group="items",desc="Kirim password pintu di x,y. Balasan: `answer`.",schema={k="struct",sid=25,f={{"y","uint16"},{"x","uint16"},{"seq","uint16"},{"pass","string"}}}},
	punch = {id=68,dir="c2s",rel="reliable",group="presence",desc="Pukul pemain lain; nilai = `id` pemain target (uint16). Dijaga penghitung seq.",schema="uint16"},
	itemsGiven = {id=69,dir="s2c",rel="reliable",group="items",desc="Item diberikan ke pemain (`items`, `how`).",schema={k="struct",sid=63,f={{"items",{k="array",of={k="struct",sid=62,f={{"id","uint16"},{"from",{k="optional",of="string"}},{"of",{k="optional",of="uint32"}},{"n","uint32"}}}}},{"how",{k="optional",of="string"}}}}},
	buy = {id=70,dir="c2s",rel="reliable",group="commerce",desc="Beli item toko dengan `key` (string). Balasan: `bagAnswer`.",schema={k="struct",sid=29,f={{"seq","uint16"},{"key","string"}}}},
}
D.asks = {"GetInventory","GetGems","GetLevel","GetProfile","GetPlayerLevel","GetSettings","SaveSettings","EditLock","Vip","EditDoor","DoorInfo","Broadcast","SuperBroadcastPrice","MoveDoor","MoveLock","SwapWorld","WorldCommand","EditSwitch","EditWeather","Bulletin","EditSign","SecurityCamera","Surgery","HubList","Challenge","GiftTarget","Guild","UpdateLog","ActiveCodes","PickTitle","ReportPlayer","ModCommand","StaffBackpack","ChooseName","RenameName","Quests","Friends","TradeHistory","CollectHistory","VendSearch","UseDoor","TopDonors","LockeBuy","UseHotChocolate"}
D.notes = {"FriendAlert","ChallengeNotice","GuildNotice","QuestDone","ModNotice","WorldFx","SuperBroadcast","SignChanged","WeatherChanged","Combined"}
D.calls = {
	LeaveWorld = {ask="leave",reply=nil},
	SetBusy = {ask="busy",reply=nil},
	Recycle = {ask="recycle",reply=nil},
	CycleItem = {ask="cycle",reply=nil},
	ConvertLock = {ask="convert",reply=nil},
	FeedProvider = {ask="feed",reply=nil},
	DoorPass = {ask="doorPass",reply="answer"},
	Spray = {ask="spray",reply="answer"},
	UseOnPlayer = {ask="useOn",reply="answer"},
	OpenPack = {ask="openPack",reply="bagAnswer"},
	BuyItem = {ask="buy",reply="bagAnswer"},
	DisplayItem = {ask="display",reply="bagAnswer"},
	VendItem = {ask="vend",reply="bagAnswer"},
	HubBuy = {ask="hubBuy",reply="bagAnswer"},
	Donation = {ask="donation",reply="donAnswer"},
	Trade = {ask="trade",reply="answer"},
	ListWorlds = {ask="list",reply="worldsAnswer"},
}
D.events = {
	ProviderChanged = {packet="providerChanged",world=true},
	SwitchChanged = {packet="switchChanged",world=true},
	WheelSpun = {packet="wheelSpun",world=true},
	SurgeryTile = {packet="surgeryTile",world=true},
	DonationFull = {packet="donationFull",world=true},
	Donated = {packet="donated",world=false},
	SpawnMoved = {packet="spawnMoved",world=true},
	VipPass = {packet="vipPass",world=true},
	WorldNotice = {packet="worldNotice",world=false},
	LevelUp = {packet="levelUp",world=false},
	AccessGiven = {packet="accessGiven",world=false},
	WorldClosed = {packet="worldClosed",world=false},
	Knocked = {packet="knocked",world=false},
	Impulse = {packet="impulse",world=false},
	ForceDie = {packet="forceDie",world=false},
	Burned = {packet="burned",world=false},
	MoveTo = {packet="moveTo",world=true},
	ItemsGiven = {packet="itemsGiven",world=false},
	InventorySync = {packet="inventorySync",world=false},
	DisplayChanged = {packet="displayChanged",world=true},
	VendChanged = {packet="vendChanged",world=true},
	HubChanged = {packet="hubChanged",world=true},
	UseOnPlayerFx = {packet="useFx",world=false},
}

--========================================================================
-- DryCursed core  (Lua/Luau-compatible; tanpa sintaks khusus Luau)
--========================================================================
local DC = {}
DC.VERSION = "1.0.0"
DC.GAME_ID = 112863874972771
DC.LIB     = "ByteNet v0.4.3 (namespace World)"

DC.Id     = {}   -- nama  -> id        contoh: DC.Id.punch  --> 68
DC.Name   = {}   -- id    -> nama      contoh: DC.Name[68]  --> "punch"
DC.Packet = D.packets
DC.Ask    = D.asks     -- indeks fn  -> nama RPC generik (1-based)
DC.Note   = D.notes    -- indeks e   -> nama push generik (1-based)
DC.Calls  = D.calls
DC.Events = D.events

------------------------------------------------------------------ writer
local Writer = {}
Writer.__index = Writer
local function newWriter() return setmetatable({ buf = buffer.create(256), cur = 0, size = 256 }, Writer) end
function Writer:need(n)
	if self.cur + n > self.size then
		local ns = self.size * 2
		if ns < self.cur + n then ns = self.cur + n end
		local nb = buffer.create(ns)
		buffer.copy(nb, 0, self.buf, 0, self.cur)
		self.buf, self.size = nb, ns
	end
end
function Writer:u8(v)  self:need(1); buffer.writeu8(self.buf, self.cur, v);  self.cur = self.cur + 1 end
function Writer:u16(v) self:need(2); buffer.writeu16(self.buf, self.cur, v); self.cur = self.cur + 2 end
function Writer:u32(v) self:need(4); buffer.writeu32(self.buf, self.cur, v); self.cur = self.cur + 4 end
function Writer:i8(v)  self:need(1); buffer.writei8(self.buf, self.cur, v);  self.cur = self.cur + 1 end
function Writer:i16(v) self:need(2); buffer.writei16(self.buf, self.cur, v); self.cur = self.cur + 2 end
function Writer:i32(v) self:need(4); buffer.writei32(self.buf, self.cur, v); self.cur = self.cur + 4 end
function Writer:f32(v) self:need(4); buffer.writef32(self.buf, self.cur, v); self.cur = self.cur + 4 end
function Writer:f64(v) self:need(8); buffer.writef64(self.buf, self.cur, v); self.cur = self.cur + 8 end
function Writer:str(s) self:need(#s); buffer.writestring(self.buf, self.cur, s); self.cur = self.cur + #s end
function Writer:finish()
	local out = buffer.create(self.cur)
	buffer.copy(out, 0, self.buf, 0, self.cur)
	return out
end

------------------------------------------------------------------ tipe dasar
local PRIM = {
	uint8   = { read = function(b, o) return buffer.readu8(b, o), 1 end,  write = function(w, v) w:u8(v) end },
	uint16  = { read = function(b, o) return buffer.readu16(b, o), 2 end, write = function(w, v) w:u16(v) end },
	uint32  = { read = function(b, o) return buffer.readu32(b, o), 4 end, write = function(w, v) w:u32(v) end },
	int8    = { read = function(b, o) return buffer.readi8(b, o), 1 end,  write = function(w, v) w:i8(v) end },
	int16   = { read = function(b, o) return buffer.readi16(b, o), 2 end, write = function(w, v) w:i16(v) end },
	int32   = { read = function(b, o) return buffer.readi32(b, o), 4 end, write = function(w, v) w:i32(v) end },
	float32 = { read = function(b, o) return buffer.readf32(b, o), 4 end, write = function(w, v) w:f32(v) end },
	float64 = { read = function(b, o) return buffer.readf64(b, o), 8 end, write = function(w, v) w:f64(v) end },
	bool    = { read = function(b, o) return buffer.readu8(b, o) == 1, 1 end, write = function(w, v) w:u8(v and 1 or 0) end },
	string  = {
		read  = function(b, o) local n = buffer.readu16(b, o); return buffer.readstring(b, o + 2, n), n + 2 end,
		write = function(w, v) w:u16(#v); w:str(v) end,
	},
	nothing = { read = function() return nil, 0 end, write = function() end },
}

local readNode, writeNode

readNode = function(node, b, o)
	if type(node) == "string" then return PRIM[node].read(b, o) end
	local k = node.k
	if k == "struct" then
		local out, total = {}, 0
		for _, fld in ipairs(node.order) do
			local v, n = readNode(fld[2], b, o + total)
			out[fld[1]] = v
			total = total + n
		end
		return out, total
	elseif k == "array" then
		local n = buffer.readu16(b, o)
		local out, total = {}, 2
		for i = 1, n do
			local v, m = readNode(node.of, b, o + total)
			out[i] = v
			total = total + m
		end
		return out, total
	elseif k == "optional" then
		if buffer.readu8(b, o) == 0 then return nil, 1 end
		local v, m = readNode(node.of, b, o + 1)
		return v, m + 1
	elseif k == "map" then
		local n = buffer.readu16(b, o)
		local out, total = {}, 2
		for _ = 1, n do
			local key, m1 = readNode(node.key, b, o + total); total = total + m1
			local val, m2 = readNode(node.val, b, o + total); total = total + m2
			out[key] = val
		end
		return out, total
	end
	error("tipe tidak dikenal: " .. tostring(k))
end

writeNode = function(node, w, v)
	if type(node) == "string" then return PRIM[node].write(w, v) end
	local k = node.k
	if k == "struct" then
		for _, fld in ipairs(node.order) do writeNode(fld[2], w, v[fld[1]]) end
	elseif k == "array" then
		w:u16(#v)
		for i = 1, #v do writeNode(node.of, w, v[i]) end
	elseif k == "optional" then
		if v == nil then w:u8(0) else w:u8(1); writeNode(node.of, w, v) end
	elseif k == "map" then
		local n = 0
		for _ in pairs(v) do n = n + 1 end
		w:u16(n)
		for key, val in pairs(v) do writeNode(node.key, w, key); writeNode(node.val, w, val) end
	end
end

------------------------------------------------------------------ urutan field (dari peta live)
-- ByteNet server menentukan urutan field & ID packet saat runtime, lalu menyimpannya di
-- ReplicatedStorage.BytenetStorage.World (StringValue JSON). applyOrder memakai peta itu.
local function applyOrder(node, structs)
	if type(node) == "string" then return true end
	local k = node.k
	if k == "struct" then
		local order, n = {}, #node.f
		local live = structs and structs[node.sid]
		if live then
			local count = 0
			for _ in pairs(live) do count = count + 1 end
			if count ~= n then return false end
			for _, fld in ipairs(node.f) do
				local idx = live[fld[1]]
				if type(idx) ~= "number" or idx < 1 or idx > n then return false end
				order[idx] = fld
			end
			for i = 1, n do if order[i] == nil then return false end end
		else
			for i, fld in ipairs(node.f) do order[i] = fld end
		end
		node.order = order
		for _, fld in ipairs(node.f) do
			if not applyOrder(fld[2], structs) then return false end
		end
		return true
	elseif k == "array" or k == "optional" then
		return applyOrder(node.of, structs)
	elseif k == "map" then
		return applyOrder(node.key, structs) and applyOrder(node.val, structs)
	end
	return true
end

local SNAP = {}   -- id snapshot (dari ekspor), dipakai bila peta live tidak tersedia
for name, p in pairs(D.packets) do
	p.name = name
	SNAP[name] = p.id
	applyOrder(p.schema, nil)
end

local byId = {}
local function rebuild()
	for k in pairs(DC.Id) do DC.Id[k] = nil end
	for k in pairs(DC.Name) do DC.Name[k] = nil end
	for k in pairs(byId) do byId[k] = nil end
	for name, p in pairs(D.packets) do
		if p.id then
			DC.Id[name] = p.id
			DC.Name[p.id] = name
			byId[p.id] = p
		end
	end
end
rebuild()

--- DC.refresh([json|table]) -> ok, laporan
-- Baca peta ID/urutan field LIVE dari server. Tanpa argumen: baca BytenetStorage.World.
function DC.refresh(src)
	local live = src
	if live == nil then
		local rs = game:GetService("ReplicatedStorage")
		local store = rs:FindFirstChild("BytenetStorage")
		local sv = store and store:FindFirstChild("World")
		if not sv then return false, "BytenetStorage.World tidak ditemukan (pakai snapshot)" end
		live = sv.Value
	end
	if type(live) == "string" then
		local ok, res = pcall(function() return game:GetService("HttpService"):JSONDecode(live) end)
		if not ok then return false, "JSON tidak valid" end
		live = res
	end
	if type(live) ~= "table" or type(live.packets) ~= "table" then return false, "format peta tidak dikenal" end
	local report = { changed = {}, stale = {}, missing = {}, new = {} }
	for name, p in pairs(D.packets) do
		local lid = live.packets[name]
		if lid == nil then
			p.id = nil; p.stale = true
			report.missing[#report.missing + 1] = name
		else
			if lid ~= SNAP[name] then report.changed[#report.changed + 1] = name end
			p.id = lid
			if applyOrder(p.schema, live.structs) then
				p.stale = false
			else
				p.stale = true   -- skema berubah: jangan dekode, update dokumentasi
				applyOrder(p.schema, nil)
				report.stale[#report.stale + 1] = name
			end
		end
	end
	for name in pairs(live.packets) do
		if not D.packets[name] then report.new[#report.new + 1] = name end
	end
	rebuild()
	return true, report
end

------------------------------------------------------------------ decode / encode
--- DC.decode(buf) -> daftar {name,id,data}, errMsg|nil
-- Satu buffer ByteNet bisa memuat BANYAK packet berurutan: [id][payload][id][payload]...
function DC.decode(buf)
	local out, o, len = {}, 0, buffer.len(buf)
	while o < len do
		local id = buffer.readu8(buf, o)
		local p = byId[id]
		if not p then return out, ("id %d tidak dikenal pada offset %d"):format(id, o) end
		if p.stale then return out, ("skema '%s' kedaluwarsa (server berubah)"):format(p.name) end
		local ok, v, n = pcall(readNode, p.schema, buf, o + 1)
		if not ok then return out, ("gagal baca '%s': %s"):format(p.name, tostring(v)) end
		out[#out + 1] = { name = p.name, id = id, data = v }
		o = o + 1 + n
	end
	return out, nil
end

--- DC.encode(name, data) -> buffer   (untuk uji/round-trip & alat offline; TIDAK mengirim apa pun)
function DC.encode(name, data)
	local p = D.packets[name] or error("packet tidak dikenal: " .. tostring(name), 2)
	if p.stale or not p.id then error("skema '" .. name .. "' kedaluwarsa", 2) end
	local w = newWriter()
	w:u8(p.id)
	writeNode(p.schema, w, data)
	return w:finish()
end

--- DC.fromHex("09 01 26 08 00 00 00") -> buffer  (membaca log hex dari debugger)
function DC.fromHex(hex)
	hex = hex:gsub("[^%x]", "")
	local n = #hex // 2
	local b = buffer.create(n)
	for i = 1, n do buffer.writeu8(b, i - 1, tonumber(hex:sub(i * 2 - 1, i * 2), 16)) end
	return b
end

local function fmt(v, depth)
	depth = depth or 0
	if type(v) ~= "table" then return tostring(v) end
	local parts = {}
	if #v > 0 then
		for i = 1, #v do parts[#parts + 1] = fmt(v[i], depth + 1) end
		return "[" .. table.concat(parts, ", ") .. "]"
	end
	local items = {}
	for k, val in pairs(v) do items[#items + 1] = { tostring(k), val } end
	table.sort(items, function(a, b) return a[1] < b[1] end)
	for _, it in ipairs(items) do parts[#parts + 1] = it[1] .. "=" .. fmt(it[2], depth + 1) end
	return "{" .. table.concat(parts, ", ") .. "}"
end

--- DC.pretty(hasilDecode) -> string satu baris per packet
function DC.pretty(res)
	local lines = {}
	for _, r in ipairs(res) do lines[#lines + 1] = ("#%d %s %s"):format(r.id, r.name, fmt(r.data)) end
	return table.concat(lines, "\n")
end

------------------------------------------------------------------ introspeksi
local function typeStr(t)
	if type(t) == "string" then return t end
	if t.k == "struct" then
		local s = {}
		for _, f in ipairs(t.order) do s[#s + 1] = f[1] .. ": " .. typeStr(f[2]) end
		return "{ " .. table.concat(s, ", ") .. " }"
	elseif t.k == "array" then return typeStr(t.of) .. "[]"
	elseif t.k == "optional" then return typeStr(t.of) .. "?"
	elseif t.k == "map" then return "map<" .. typeStr(t.key) .. ", " .. typeStr(t.val) .. ">" end
end

--- DC.describe("punch") -> "#68 punch [c2s, reliable] uint16 - ..."
function DC.describe(name)
	local p = D.packets[name]
	if not p then return nil end
	return ("#%s %s [%s, %s] %s - %s"):format(tostring(p.id), name, p.dir, p.rel, typeStr(p.schema), p.desc)
end

--- DC.list([group|dir]) -> daftar info packet terurut ID. group: presence|tiles|items|commerce|rpc|world ; dir: c2s|s2c
function DC.list(filter)
	local out = {}
	for _, p in pairs(D.packets) do
		if p.id and (filter == nil or p.group == filter or p.dir == filter) then out[#out + 1] = p end
	end
	table.sort(out, function(a, b) return a.id < b.id end)
	return out
end

------------------------------------------------------------------ pendengar (hanya BACA)
local listeners, anyListeners, conns, started = {}, {}, {}, false

local function ingest(buf)
	local res, err = DC.decode(buf)
	for _, r in ipairs(res) do
		local ls = listeners[r.name]
		if ls then for _, fn in ipairs({ table.unpack(ls) }) do pcall(fn, r.data, r) end end
		for _, fn in ipairs({ table.unpack(anyListeners) }) do pcall(fn, r) end
	end
	if err and DC.onError then pcall(DC.onError, err) end
end
DC._ingest = ingest   -- bisa diumpan dari debugger eksternal: DC._ingest(buffer)

--- DC.on("moved", function(data, rec) ... end) -> fungsi disconnect
function DC.on(name, fn)
	assert(D.packets[name], "packet tidak dikenal: " .. tostring(name))
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], fn)
	return function()
		for i, f in ipairs(listeners[name]) do if f == fn then table.remove(listeners[name], i) break end end
	end
end
function DC.once(name, fn)
	local off
	off = DC.on(name, function(...) off(); fn(...) end)
	return off
end
--- DC.onAny(function(rec) ... end) -> disconnect
function DC.onAny(fn)
	table.insert(anyListeners, fn)
	return function()
		for i, f in ipairs(anyListeners) do if f == fn then table.remove(anyListeners, i) break end end
	end
end

--- DC.start(): refresh peta live lalu sambungkan ke ByteNetReliable/Unreliable.OnClientEvent (read-only)
function DC.start()
	if started then return true end
	local ok, rep = DC.refresh()
	local rs = game:GetService("ReplicatedStorage")
	for _, n in ipairs({ "ByteNetReliable", "ByteNetUnreliable" }) do
		local r = rs:WaitForChild(n, 10)
		if r then conns[#conns + 1] = r.OnClientEvent:Connect(ingest) end
	end
	started = true
	return ok, rep
end
function DC.stop()
	for _, c in ipairs(conns) do c:Disconnect() end
	conns, started = {}, false
end

------------------------------------------------------------------ util dunia
--- World tag: hash 8-bit nama dunia (dipakai kolom `w` di banyak packet)
function DC.worldTag(name)
	local h = 0
	for i = 1, #name do h = (h * 31 + string.byte(name, i)) % 256 end
	return h
end

--- Grid dunia: RLE teks "id*jumlah,id,..." (port Shared.WorldCodec). grid[y][x], 0-based.
DC.Grid = {}
function DC.Grid.decode(str, width, height)
	local grid = {}
	for y = 0, height - 1 do grid[y] = {} end
	local i = 0
	for tok in string.gmatch(str, "[^,]+") do
		local a, b = string.match(tok, "^(%d+)%*(%d+)$")
		local v = tonumber(a or tok)
		for _ = 1, tonumber(b or 1) do
			grid[i // width][i % width] = v
			i = i + 1
		end
	end
	return grid
end
function DC.Grid.encode(grid, width, height)
	local out, cur, run = {}, nil, 0
	local function flush()
		if cur ~= nil then out[#out + 1] = run > 1 and (cur .. "*" .. run) or tostring(cur) end
	end
	for y = 0, height - 1 do
		for x = 0, width - 1 do
			local v = grid[y][x]
			if v == cur then run = run + 1 else flush(); cur, run = v, 1 end
		end
	end
	flush()
	return table.concat(out, ",")
end

return DC
