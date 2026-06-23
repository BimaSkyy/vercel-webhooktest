-- ============================================================
-- MONITOR DATA KHUSUS REDFINGER: PASTI DETEKSI RELOG
-- ============================================================

local folderPath = "DataFarm"
local fileName = "datagag.json"
local fullPath = folderPath .. "/" .. fileName
local fileRelog = folderPath .. "/relog.txt"
local fileRelogAccept = folderPath .. "/relogaccept.txt"

if not isfolder(folderPath) then makefolder(folderPath) end

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
-- AMBIL DATA & BANDINGKAN
-- ============================================================

local dataSebelum = ""
local daftarBeratSebelum = {}

local function ambilDanTulis()
    local plr = game:GetService("Players").LocalPlayer
    if not plr then return end

    local uang = 0
    local barang = {}
    local hasilPanen = {}
    local daftarBeratSekarang = {}
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

    -- Ambil barang di tas
    local lokasi = {plr:FindFirstChildOfClass("Backpack")}
    for _,tempat in lokasi do
        if tempat then
            for _,item in tempat:GetChildren() do
                if item:IsA("Tool") then
                    local nama = item.Name
                    local jumlah = item:GetAttribute("Count") or 1
                    local berat = item:GetAttribute("Weight") or 0
                    local mutasi = item:GetAttribute("Mutation") or ""

                    if jumlah <= 0 then continue end

                    if berat > 0 then
                        local namaPenuh = mutasi~="" and mutasi~="None" and string.format("%s [%s]",nama,mutasi) or nama
                        daftarBeratSekarang[namaPenuh] = jumlah
                        if not hasilPanen[namaPenuh] then hasilPanen[namaPenuh]={jumlah=0,beratTotal=berat*jumlah} end
                        hasilPanen[namaPenuh].jumlah+=jumlah
                        hasilPanen[namaPenuh].beratTotal+=berat*jumlah
                        totalBerat+=berat*jumlah
                    else
                        barang[nama] = (barang[nama] or 0)+jumlah
                    end
                    totalSemua+=jumlah
                end
            end
        end
    end

    -- Deteksi jual & panen baru
    local terjual = {}
    for n,j in pairs(daftarBeratSebelum) do if not daftarBeratSekarang[n] then terjual[n]=j end end
    local dipanenBaru = {}
    for n,j in pairs(daftarBeratSekarang) do local l=daftarBeratSebelum[n] or 0 if j>l then dipanenBaru[n]=j-l end end
    daftarBeratSebelum = daftarBeratSekarang

    -- Susun data
    local data = {
        waktu=os.date("%H:%M:%S"), namaPemain=plr.Name,
        uang=uang, uangFormat=formatAngka(uang),
        barang=barang, panen=hasilPanen, terjual=terjual, dipanenBaru=dipanenBaru,
        totalBerat=totalBerat, totalBeratFormat=formatAngka(totalBerat), totalItem=totalSemua
    }

    -- Tulis ke berkas → Termux yang akan kirim
    local teksAkhir = tabelKeJson(data)
    if teksAkhir ~= dataSebelum then
        dataSebelum = teksAkhir
        writefile(fullPath, teksAkhir)
        -- Notifikasi
        game.StarterGui:SetCore("SendNotification",{Title="✅ Disimpan",Text="Menunggu kirim",Duration=1})
    end
end

-- ============================================================
-- ✅ PEMANTAU RELOG DIPERKUAT: PASTI BACA & JALANKAN
-- ============================================================

task.spawn(function()
    while true do
        task.wait(0.5) -- ✅ Cek LEBIH KERAP: setiap 0.5 detik
        if isfile(fileRelog) then
            -- ✅ Baca lalu buang SEMUA spasi/baris kosong/karakter tersisa
            local isiMentah = readfile(fileRelog) or ""
            local isiBersih = isiMentah:gsub("%s+", ""):lower() -- hapus spasi, ganti jadi huruf kecil

            if isiBersih == "true" then
                print("[⚠️] ✅ PERINTAH RELOG DITEMUKAN & DIJALANKAN")
                game.StarterGui:SetCore("SendNotification",{Title="🔄 RELOG",Text="Sedang pindah server...",Duration=3})

                -- ✅ Tulis konfirmasi dulu supaya Termux tahu
                writefile(fileRelogAccept, "true")

                -- ✅ Jalankan pindah server
                pcall(function()
                    game:GetService("TeleportService"):TeleportToPlaceInstance(
                        game.PlaceId,
                        game.JobId,
                        game.Players.LocalPlayer
                    )
                end)

                -- ✅ Bersihkan berkas SEKARANG juga
                writefile(fileRelog, "")
                writefile(fileRelogAccept, "")
            end
        end
    end
end)

-- ============================================================
-- MULAI BERJALAN
-- ============================================================

print("[✅] Mode RedFinger: Cek relog tiap 0.5 detik")
ambilDanTulis()
task.spawn(function() while true do task.wait(2) ambilDanTulis() end end)
