-- ============================================================
-- MONITOR DATA FARM + DETEKSI JUAL/PANEN + SISTEM RELOG
-- ============================================================

local folderPath = "DataFarm"
local fileName = "datagag.json"
local fullPath = folderPath .. "/" .. fileName

-- ✅ Berkas perintah relog
local fileRelog = folderPath .. "/relog.txt"
local fileRelogAccept = folderPath .. "/relogaccept.txt"

if not isfolder(folderPath) then
    makefolder(folderPath)
end

-- ============================================================
-- FUNGSI PENDUKUNG
-- ============================================================

local function formatAngka(angka)
    if not angka or angka == 0 then return "0" end
    local abs = math.abs(angka)
    local suf, val = "", angka
    if abs >= 1e12 then val = angka/1e12; suf = "T"
    elseif abs >= 1e9 then val = angka/1e9; suf = "B"
    elseif abs >= 1e6 then val = angka/1e6; suf = "M"
    elseif abs >= 1e3 then val = angka/1e3; suf = "K" end
    return suf~="" and string.format("%.2f%s",val,suf) or string.format("%.0f",angka)
end

-- ✅ SEKARANG LEBIH SEDERHANA: HANYA AMBIL ALAT DALAM TAS
local function isFarmingItem(item)
    return item:IsA("Tool") and not item:FindFirstAncestorWhichIsA("Character")
end

local function tabelKeJson(tbl)
    if type(tbl)~="table" then return "{}" end
    local bagian = {}
    for k,v in pairs(tbl) do
        if type(v)=="string" then
            bagian[#bagian+1] = string.format('"%s":"%s"',k,v:gsub('"','\\"'))
        elseif type(v)=="number" then
            bagian[#bagian+1] = string.format('"%s":%s',k,v)
        elseif type(v)=="table" then
            bagian[#bagian+1] = string.format('"%s":%s',k,tabelKeJson(v))
        end
    end
    return "{"..table.concat(bagian,",").."}"
end

-- ============================================================
-- ✅ FUNGSI UTAMA: AMBIL DAN BANDINGKAN (DETEKSI JUAL & PANEN)
-- ============================================================

local dataSebelum = ""
local daftarBeratSebelum = {} -- Simpan daftar barang berat sebelumnya untuk cek jual

local function ambilDanTulis()
    local plr = game:GetService("Players").LocalPlayer
    if not plr then return end

    local uang = 0
    local barang = {}
    local hasilPanen = {}
    local daftarBeratSekarang = {} -- Untuk bandingkan
    local totalBerat = 0
    local totalSemua = 0

    -- Ambil uang
    pcall(function()
        local ls = plr:FindFirstChild("leaderstats")
        if ls then
            local val = ls:FindFirstChild("Sheckles") or ls:FindFirstChild("Money")
            if val then uang = val.Value end
        end
    end)

    -- Ambil semua barang
    local lokasi = {plr:FindFirstChildOfClass("Backpack")}
    for _,tempat in lokasi do
        if tempat then
            for _,item in tempat:GetChildren() do
                if isFarmingItem(item) then
                    local nama = item.Name
                    local jumlah = item:GetAttribute("Count") or 1
                    local berat = item:GetAttribute("Weight") or 0
                    local mutasi = item:GetAttribute("Mutation") or ""

                    if jumlah <= 0 then continue end

                    if berat > 0 then
                        local namaPenuh = mutasi~="" and mutasi~="None" 
                            and string.format("%s [%s]", nama, mutasi) or nama
                        -- Simpan untuk bandingkan jual
                        daftarBeratSekarang[namaPenuh] = jumlah
                        -- Masuk daftar
                        if not hasilPanen[namaPenuh] then
                            hasilPanen[namaPenuh] = {jumlah=0, beratTotal=berat*jumlah}
                        else
                            hasilPanen[namaPenuh].jumlah += jumlah
                            hasilPanen[namaPenuh].beratTotal += berat*jumlah
                        end
                        totalBerat += berat * jumlah
                    else
                        barang[nama] = (barang[nama] or 0) + jumlah
                    end
                    totalSemua += jumlah
                end
            end
        end
    end

    -- ✅ DETEKSI: Barang berat yang ada sebelumnya tapi HILANG = DIJUAL
    local daftarTerjual = {}
    for nama, jmlLama in pairs(daftarBeratSebelum) do
        if not daftarBeratSekarang[nama] then
            daftarTerjual[nama] = jmlLama -- Semua jumlah hilang = terjual
        elseif daftarBeratSekarang[nama] < jmlLama then
            daftarTerjual[nama] = jmlLama - daftarBeratSekarang[nama] -- Sebagian terjual
        end
    end

    -- ✅ DETEKSI: Barang berat BARU atau bertambah = HASIL PANEN BARU
    local daftarBaru = {}
    for nama, jmlBaru in pairs(daftarBeratSekarang) do
        local lama = daftarBeratSebelum[nama] or 0
        if jmlBaru > lama then
            daftarBaru[nama] = jmlBaru - lama
        end
    end

    -- Perbarui catatan untuk cek berikutnya
    daftarBeratSebelum = daftarBeratSekarang

    -- ✅ SUSUN DATA LENGKAP
    local data = {
        waktu = os.date("%H:%M:%S"),
        namaPemain = plr.Name,
        uang = uang,
        uangFormat = formatAngka(uang),
        barang = barang,
        panen = hasilPanen,
        terjual = daftarTerjual,   -- ➕ Kirim data penjualan
        dipanenBaru = daftarBaru, -- ➕ Kirim data panen baru
        totalBerat = totalBerat,
        totalBeratFormat = formatAngka(totalBerat),
        totalItem = totalSemua
    }

    -- Tulis jika berubah
    local teksAkhir = tabelKeJson(data)
    if teksAkhir ~= dataSebelum then
        dataSebelum = teksAkhir
        writefile(fullPath, teksAkhir)
        game.StarterGui:SetCore("SendNotification",{
            Title="✅ Data Diperbarui", Text="Terkirim", Duration=1
        })
    end
end

-- ============================================================
-- ✅ PEMANTAU PERINTAH RELOG (BERJALAN TERUS)
-- ============================================================

task.spawn(function()
    while true do
        task.wait(1) -- Cek perintah relog setiap detik

        -- Cek apakah ada perintah
        if isfile(fileRelog) then
            local perintah = readfile(fileRelog) or ""
            if perintah:lower() == "true" then
                print("[⚠️] PERINTAH RELOG DITERIMA")

                -- ✅ KONFIRMASI: tulis ke berkas terima
                writefile(fileRelogAccept, "true")

                -- ✅ LAKUKAN RELOG / GANTI SERVER
                pcall(function()
                    game:GetService("TeleportService"):TeleportToPlaceInstance(
                        game.PlaceId,
                        game.JobId,
                        game.Players.LocalPlayer
                    )
                end)

                -- ✅ Bersihkan perintah agar tidak diulang
                writefile(fileRelog, "")
                writefile(fileRelogAccept, "")
            end
        end
    end
end)

-- ============================================================
-- JALANKAN PEMANTAU UTAMA
-- ============================================================

print("[✅] Pemantau AKTIF - Cek setiap 2 detik | Relog aktif")
ambilDanTulis()
task.spawn(function()
    while true do
        task.wait(2)
        ambilDanTulis()
    end
end)
