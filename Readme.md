# DryCursed

Framework + dokumentasi protokol jaringan game **112863874972771** (dunia tile 2D bergaya Growtopia di Roblox), dibangun dari dua ekspor yang Anda unggah.

| File | Isi |
|---|---|
| `DryCursed.lua` | Framework satu-file: registry ID, codec, dekoder, pendengar packet, util dunia |
| `protocol.json` | Seluruh protokol (70 packet, skema urutan-wire, RPC, event) untuk alat lain |
| `ids.json` | Peta `nama <-> ID` (+ daftar ASK/NOTE) — pengganti hex |
| `docs/` | 01 Arsitektur · 02 Alur & algoritma · 03 API framework · 04 Referensi packet · 05 RPC/Call/Event · 06 Remote legacy |
| `tools/decode_packets.py` | Dekoder offline: tempel hex dari debugger, keluar nama packet |

## Mulai cepat
```lua
local DC = loadstring(readfile("DryCursed.lua"))()
DC.start()

DC.on("tileChanged", function(d)
    print(("tile %d,%d layer %d -> id %d"):format(d.x, d.y, d.layer, d.id))
end)

print(DC.Id.tileChanged)   --> 40   (bukan hex)
print(DC.describe("punch"))
```

## Konsep utama: hex diganti ID
Packet ByteNet diawali **1 byte ID**. ID itu **tidak tetap**: server memberi nomor saat startup dan menyimpannya di
`ReplicatedStorage.BytenetStorage.World`. `DC.start()` membaca peta itu, jadi `DC.Id.punch` selalu benar untuk server yang sedang
Anda masuki. Jika game update dan skema bergeser, `DC.refresh()` melapor `changed / stale / new`, dan packet bermasalah ditolak
(tidak salah-dekode diam-diam).

## Status & batasan
* Dekoder/encoder diuji: sampel capture asli (`busy`, `act`, `seq`) cocok; round-trip 70/70 packet lolos; deteksi skema-berubah lolos. Uji memakai interpreter Lua 5.3 dengan shim `buffer`; **belum dijalankan di runtime Roblox/executor**.
* Arah (`c2s`/`s2c`) dan deskripsi packet disimpulkan dari struktur kode klien; yang bertanda *[diduga]* belum dikonfirmasi (kode server tidak ada di ekspor).
* Sengaja **tidak ada fungsi kirim**: server menjaga kiriman dengan penghitung packet (`SeqService`/`PacketGateService`). Framework ini untuk analisis, logging, dan dokumentasi.
