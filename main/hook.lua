-- ============================================================
-- MONITOR DATA REDFINGER: HANYA BERKAS LOKAL (TANPA ALAMAT LUAR)
-- ============================================================

local folderPath = "DataFarm"
local fileName = "datagag.json"
local fullPath = folderPath .. "/" .. fileName
local fileRelog = folderPath .. "/relog.txt"
local fileRelogAccept = folderPath .. "/relogaccept.txt"

if not isfolder(folderPath) then makefolder(folderPath) end

-- Referensi standar dari kode asli
local RS = game:GetService("ReplicatedStorage")
local Farm = {} -- Tempat fungsi cuaca & restock masuk
local C = { -- Warna standar
    text = Color3.fromRGB(220, 220, 220),
    textDim = Color3.fromRGB(140, 140, 140)
}

-- ============================================================
-- FUNGSI ASLI: CUACA & RESTOCK
-- ============================================================

local function getWeatherInfo()
    local info = {
        weather = "Unknown",
        phase = "Unknown",
        phaseEnd = nil,
        weatherColor = C.text,
        phaseColor = C.textDim
    }
    
    pcall(function()
        local w = workspace:GetAttribute("ActiveWeather")
        if w then
            info.weather = tostring(w)
            local wl = tostring(w):lower()
            if wl:find("rain") or wl:find("hujan") then
                info.weatherColor = Color3.fromRGB(100, 150, 255)
            elseif wl:find("moon") or wl:find("bulan") then
                info.weatherColor = Color3.fromRGB(200, 200, 255)
            elseif wl:find("blood") or wl:find("darah") then
                info.weatherColor = Color3.fromRGB(255, 100, 100)
            elseif wl:find("gold") or wl:find("emas") then
                info.weatherColor = Color3.fromRGB(255, 215, 0)
            elseif wl:find("sun") or wl:find("matahari") then
                info.weatherColor = Color3.fromRGB(255, 200, 100)
            elseif wl:find("storm") or wl:find("badai") then
                info.weatherColor = Color3.fromRGB(150, 150, 200)
            end
        end
        
        local ph = workspace:GetAttribute("ActivePhase")
        if ph then
            info.phase = tostring(ph)
            local pl = tostring(ph):lower()
            if pl:find("day") or pl:find("siang") then
                info.phaseColor = Color3.fromRGB(255, 200, 100)
            elseif pl:find("night") or pl:find("malam") then
                info.phaseColor = Color3.fromRGB(100, 100, 200)
            elseif pl:find("dusk") or pl:find("senja") then
                info.phaseColor = Color3.fromRGB(200, 150, 100)
            elseif pl:find("dawn") or pl:find("fajar") then
                info.phaseColor = Color3.fromRGB(255, 180, 100)
            end
        end
        
        local pend = workspace:GetAttribute("PhaseDuration")
        if pend then
            info.phaseEnd = tonumber(pend) - os.time()
        end
    end)
    return info
end

local function getRestockInfo()
    local info = {seed = nil, gear = nil, crate = nil}
    pcall(function()
        local sv = RS:FindFirstChild("StockValues")
        if not sv then return end
        local ss = sv:FindFirstChild("SeedShop")
        if ss and ss:FindFirstChild("UnixNextRestock") then info.seed = tonumber(ss.UnixNextRestock.Value) - os.time() end
        local gs = sv:FindFirstChild("GearShop")
        if gs and gs:FindFirstChild("UnixNextRestock") then info.gear = tonumber(gs.UnixNextRestock.Value) - os.time() end
        local cs = sv:FindFirstChild("CrateShop")
        if cs and cs:FindFirstChild("UnixNextRestock") then info.crate = tonumber(cs.UnixNextRestock.Value) - os.time() end
    end)
    return info
end

local function formatTimeLeft(seconds)
    if not seconds then return "-" end
    if seconds < 0 then seconds = 0 end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    if m > 60 then
        local h = math.floor(m / 60)
        return string.format("%dh %dm", h, m%60)
    elseif m > 0 then
        return string.format("%dm %02ds", m, s)
    else
        return string.format("%ds", s)
    end
end

-- ============================================================
-- ✅ FUNGSI BARU: DETEKSI PET LIAR DI PETA
-- ============================================================

local function getWildPets()
    local daftar = {}
    local lokasi = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("WildPetSpawns")
    if not lokasi then return daftar end

    -- Baca semua yang ada di sana, ambil nama dari Atribut
    for _, anak in ipairs(lokasi:GetChildren()) do
        if anak:GetAttribute("PetName") then
            local namaPet = tostring(anak:GetAttribute("PetName"))
            -- Tambah tanpa duplikat
            if not daftar[namaPet] then
                daftar[namaPet] = true
            end
        end
    end

    -- Ubah jadi daftar teks
    local hasil = {}
    for nama in pairs(daftar) do
        hasil[#hasil+1] = "• " .. nama
    end
    return hasil
end

-- ============================================================
-- FUNGSI PENDUKUNG UTAMA
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

local function escapeStr(s)
    s = s:gsub('\\', '\\\\') -- \ harus duluan
    s = s:gsub('"', '\\"')
    s = s:gsub('\n', '\\n')
    s = s:gsub('\r', '\\r')
    s = s:gsub('\t', '\\t')
    return s
end

local function tabelKeJson(tbl)
    if type(tbl)~="table" then return "{}" end
    local bagian = {}
    for k,v in pairs(tbl) do
        if type(v)=="string" then
            bagian[#bagian+1] = string.format('"%s":"%s"',k,escapeStr(v))
        elseif type(v)=="number" then
            bagian[#bagian+1] = string.format('"%s":%s',k,v)
        elseif type(v)=="table" then
            bagian[#bagian+1] = string.format('"%s":%s',k,tabelKeJson(v))
        end
    end
    return "{"..table.concat(bagian,",").."}"
end

-- ============================================================
-- AMBIL DATA LENGKAP & TULIS KE BERKAS LOKAL SAJA
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

    -- Uang
    pcall(function()
        local ls = plr:FindFirstChild("leaderstats")
        if ls then
            local val = ls:FindFirstChild("Sheckles") or ls:FindFirstChild("Money")
            if val then uang = val.Value end
        end
    end)

    -- Barang di tas
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

    -- Perubahan jual/panen
    local terjual = {}
    for n,j in pairs(daftarBeratSebelum) do if not daftarBeratSekarang[n] then terjual[n]=j end end
    local dipanenBaru = {}
    for n,j in pairs(daftarBeratSekarang) do local l=daftarBeratSebelum[n] or 0 if j>l then dipanenBaru[n]=j-l end end
    daftarBeratSebelum = daftarBeratSekarang

    -- ✅ Baca CUACA + RESTOCK susun sesuai format
    local cuaca = getWeatherInfo()
    local stok = getRestockInfo()
    local teksCuacaRestock = {}
    teksCuacaRestock[#teksCuacaRestock+1] = "🌤 Cuaca: "..cuaca.weather
    if cuaca.phase and cuaca.phase~="Unknown" then
        local fase = "🔄 Fase: "..cuaca.phase
        if cuaca.phaseEnd then fase = fase.." (ganti "..formatTimeLeft(cuaca.phaseEnd)..")" end
        teksCuacaRestock[#teksCuacaRestock+1] = fase
    end
    teksCuacaRestock[#teksCuacaRestock+1] = ""
    teksCuacaRestock[#teksCuacaRestock+1] = "🔄 Restock:"
    teksCuacaRestock[#teksCuacaRestock+1] = "  🌱 Seed: "..formatTimeLeft(stok.seed)
    teksCuacaRestock[#teksCuacaRestock+1] = "  ⚙️ Gear: "..formatTimeLeft(stok.gear)
    teksCuacaRestock[#teksCuacaRestock+1] = "  📦 Crate: "..formatTimeLeft(stok.crate)

    -- ✅ Baca PET DI PETA
    local daftarPet = getWildPets()
    local teksPet = #daftarPet>0 and table.concat(daftarPet,"\n") or "Tidak ada pet liar yang terdeteksi"

    -- ✅ Daftar Pemain (sederhana)
    local daftarPemain = {}
    for _, p in ipairs(game.Players:GetPlayers()) do
        local u = 0
        pcall(function()
            local ls = p:FindFirstChild("leaderstats")
            if ls then
                local v = ls:FindFirstChild("Sheckles") or ls:FindFirstChild("Money")
                if v then u = v.Value end
            end
        end)
        table.insert(daftarPemain, string.format("%s - %s", p.Name, formatAngka(u)))
    end
    table.sort(daftarPemain, function(a,b) return a>b end)

    -- Susun DATA PENUH HANYA KE BERKAS LOKAL
    local data = {
        waktu=os.date("%H:%M:%S"), namaPemain=plr.Name,
        uang=uang, uangTeks=formatAngka(uang),
        barang=barang, panen=hasilPanen, terjual=terjual, dipanenBaru=dipanenBaru,
        totalBerat=totalBerat, beratTeks=formatAngka(totalBerat), totalItem=totalSemua,
        jumlahTeks=tostring(totalSemua),
        -- ✅ BAGIAN BARU
        weatherText = table.concat(teksCuacaRestock,"\n"),
        petText = teksPet,
        playerText = table.concat(daftarPemain,"\n"),
        chatText = table.concat(riwayatChat, "\n")
    }

    -- ✅ Cukup tulis ke berkas lokal, TIDAK PERLU KIRIM KE ALAMAT LUAR
    local teksAkhir = tabelKeJson(data)
    if teksAkhir ~= dataSebelum then
        dataSebelum = teksAkhir
        writefile(fullPath, teksAkhir)
    end
end

-- ============================================================
-- PEMANTAU RELOG: SESUAIKAN DENGAN SISTEM LOKAL
-- ============================================================

task.spawn(function()
    while true do
        task.wait(0.5)
        if isfile(fileRelog) then
            local isiMentah = readfile(fileRelog) or ""
            local isiBersih = isiMentah:gsub("%s+", ""):lower()
            if isiBersih == "true" then
                -- Tulis konfirmasi supaya server tahu sudah diterima
                writefile(fileRelogAccept, "true")
                -- Bersihkan perintah
                writefile(fileRelog, "")
                task.wait(0.2)
                game.StarterGui:SetCore("SendNotification",{Title="🔄 Sedang Pindah Server",Duration=2})
                -- Lakukan pindah server
                pcall(function()
                    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, game.Players.LocalPlayer)
                end)
            end
        end
    end
end)


-- ============================================================
-- CHAT: KIRIM PESAN DARI WEB → GAME & TANGKAP CHAT GAME
-- ============================================================

local fileKirimChat = folderPath .. "/kirim_chat.txt"
local riwayatChat = {}
local MAKS_CHAT = 15

-- Tangkap chat masuk dari game
pcall(function()
    local TCS = game:GetService("TextChatService")
    TCS.MessageReceived:Connect(function(msg)
        local pengirim = msg.TextSource and msg.TextSource.Name or "?"
        local teks = msg.Text or ""
        -- Filter pesan system
        if teks == "" then return end
        table.insert(riwayatChat, pengirim .. ": " .. teks)
        if #riwayatChat > MAKS_CHAT then
            table.remove(riwayatChat, 1)
        end
    end)
end)

-- Kirim pesan dari web ke game
task.spawn(function()
    while true do
        task.wait(0.1)
        pcall(function()
            if not isfile(fileKirimChat) then return end
            local isi = readfile(fileKirimChat):gsub("%s+$", "")
            if isi == "" then return end
            -- Bersihkan dulu biar tidak dikirim ulang
            writefile(fileKirimChat, "")
            -- Kirim ke chat Roblox
            local TCS = game:GetService("TextChatService")
            local channels = TCS:FindFirstChild("TextChannels")
            local ch = channels and (channels:FindFirstChild("RBXGeneral") or channels:GetChildren()[1])
            if ch then
                ch:SendAsync(isi)
            end
        end)
    end
end)

-- ============================================================
-- MULAI BERJALAN
-- ============================================================
ambilDanTulis()
task.spawn(function() while true do task.wait(1.5) ambilDanTulis() end end)
