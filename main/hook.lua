-- ============================================================
-- MONITOR DATA REDFINGER: + CUACA + RESTOCK + PET + PEMAIN + CHAT
-- ============================================================

local folderPath = "DataFarm"
local fileName = "datagag.json"
local fullPath = folderPath .. "/" .. fileName
local fileRelog = folderPath .. "/relog.txt"
local fileRelogAccept = folderPath .. "/relogaccept.txt"
local fileChatLog = folderPath .. "/chat_logs.txt"   -- ✅ Simpan riwayat chat
local fileSendCmd = folderPath .. "/kirim_chat.txt"  -- ✅ Perintah kirim dari web

if not isfolder(folderPath) then makefolder(folderPath) end
if not isfile(fileChatLog) then writefile(fileChatLog, "") end
if not isfile(fileSendCmd) then writefile(fileSendCmd, "") end

-- Referensi standar dari kode asli
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local RS = game:GetService("ReplicatedStorage")
local Farm = {}
local C = {
    text = Color3.fromRGB(220, 220, 220),
    textDim = Color3.fromRGB(140, 140, 140)
}

-- ============================================================
-- ✅ SISTEM CHAT: DETEKSI & KIRIM PESAN
-- ============================================================
local rbxGeneralChannel = nil
local chatHistory = {}
local MAX_CHAT = 50

-- Muat riwayat lama dari berkas
pcall(function()
    local isi = readfile(fileChatLog) or ""
    for baris in isi:gmatch("[^\r\n]+") do
        local waktu, nama, pesan = baris:match("^%[(.-)%] %-(.-)%: (.*)$")
        if waktu and nama and pesan then
            table.insert(chatHistory, {waktu=waktu, nama=nama, pesan=pesan})
        end
    end
end)

-- Fungsi saluran chat
local function getChatChannel()
    if rbxGeneralChannel and rbxGeneralChannel.Parent then return rbxGeneralChannel end
    if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then return nil end
    local tc = TextChatService:FindFirstChild("TextChannels") or TextChatService:WaitForChild("TextChannels",5)
    if not tc then return nil end
    local ch = tc:FindFirstChild("RBXGeneral") or tc:WaitForChild("RBXGeneral",5)
    if ch then rbxGeneralChannel = ch end
    return rbxGeneralChannel
end

-- Tambah pesan baru & simpan ke berkas
local function tambahChat(nama, pesan)
    local waktu = os.date("%H:%M:%S")
    table.insert(chatHistory, {waktu=waktu, nama=nama, pesan=pesan})
    if #chatHistory > MAX_CHAT then table.remove(chatHistory,1) end

    -- Simpan ulang ke berkas
    local isiBaru = ""
    for _,itm in ipairs(chatHistory) do
        isiBaru = isiBaru..string.format("[%s] -%s: %s\n", itm.waktu, itm.nama, itm.pesan)
    end
    writefile(fileChatLog, isiBaru)
end

-- Mulai pantau chat masuk
local function mulaiPantauChat()
    local saluran = getChatChannel()
    if saluran then
        saluran.OnMessageAdded:Connect(function(pr)
            if pr.FromUserId then
                local plr = Players:GetPlayerByUserId(pr.FromUserId)
                if plr then tambahChat(plr.Name, pr.Text or "") end
            end
        end)
    end
    -- Cadangan via event pemain
    Players.PlayerAdded:Connect(function(p)
        p.Chatted:Connect(function(m) tambahChat(p.Name, m) end)
    end)
    for _,p in ipairs(Players:GetPlayers()) do
        p.Chatted:Connect(function(m) tambahChat(p.Name, m) end)
    end
end

-- Kirim pesan dari perintah
local function kirimPesanTeks(teks)
    if not teks or teks=="" then return end
    local saluran = getChatChannel()
    if not saluran then return end
    pcall(function() saluran:SendAsync(teks) end)
    tambahChat(Players.LocalPlayer.Name, teks)
end

-- ✅ Pantau perintah kirim dari Web
task.spawn(function()
    while true do
        task.wait(0.5)
        if isfile(fileSendCmd) then
            local isi = readfile(fileSendCmd) or ""
            isi = isi:gsub("^%s+",""):gsub("%s+$","")
            if isi ~= "" then
                kirimPesanTeks(isi)
                writefile(fileSendCmd, "") -- Bersihkan setelah dikirim
            end
        end
    end
end)

-- ============================================================
-- ✅ FUNGSI: AMBIL DAFTAR PEMAIN + UANG
-- ============================================================
local function getDaftarPemain()
    local daftar = {}
    for _,p in ipairs(Players:GetPlayers()) do
        local uang = 0
        pcall(function()
            local ls = p:FindFirstChild("leaderstats")
            if ls then
                local val = ls:FindFirstChild("Sheckles") or ls:FindFirstChild("Money")
                if val then uang = val.Value end
            end
        end)
        table.insert(daftar, {
            nama = p.Name,
            uang = uang,
            uangTeks = formatAngka(uang)
        })
    end
    -- Urutkan dari yang paling banyak uang
    table.sort(daftar, function(a,b) return a.uang > b.uang end)
    return daftar
end

-- Ubah riwayat chat jadi teks siap tampil
local function getTeksChat()
    local baris = {}
    for _,itm in ipairs(chatHistory) do
        baris[#baris+1] = string.format("[%s] %s: %s", itm.waktu, itm.nama, itm.pesan)
    end
    return #baris>0 and table.concat(baris,"\n") or "— Belum ada pesan —"
end

-- ============================================================
-- FUNGSI ASLI: CUACA & RESTOCK
-- ============================================================
local function getWeatherInfo()
    local info = {weather="Unknown",phase="Unknown",phaseEnd=nil}
    pcall(function()
        local w = workspace:GetAttribute("ActiveWeather")
        if w then info.weather=tostring(w) end
        local ph = workspace:GetAttribute("ActivePhase")
        if ph then info.phase=tostring(ph) end
        local pd = workspace:GetAttribute("PhaseDuration")
        if pd then info.phaseEnd=tonumber(pd)-os.time() end
    end)
    return info
end

local function getRestockInfo()
    local info={seed=nil,gear=nil,crate=nil}
    pcall(function()
        local sv=RS:FindFirstChild("StockValues")
        if not sv then return end
        local ss=sv:FindFirstChild("SeedShop")
        if ss then info.seed=tonumber(ss:FindFirstChild("UnixNextRestock").Value)-os.time() end
        local gs=sv:FindFirstChild("GearShop")
        if gs then info.gear=tonumber(gs:FindFirstChild("UnixNextRestock").Value)-os.time() end
        local cs=sv:FindFirstChild("CrateShop")
        if cs then info.crate=tonumber(cs:FindFirstChild("UnixNextRestock").Value)-os.time() end
    end)
    return info
end

local function formatTimeLeft(s)
    if not s or s<0 then s=0 end
    local m=math.floor(s/60) local s2=s%60
    if m>60 then return string.format("%dh %dm",m/60,m%60)
    elseif m>0 then return string.format("%dm %02ds",m,s2)
    else return string.format("%ds",s2) end
end

-- ============================================================
-- ✅ FUNGSI BARU: DETEKSI PET LIAR DI PETA
-- ============================================================
local function getWildPets()
    local daftar={}
    local lok=workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("WildPetSpawns")
    if not lok then return daftar end
    for _,anak in ipairs(lok:GetChildren()) do
        local n=anak:GetAttribute("PetName")
        if n and not daftar[n] then daftar[n]=true end
    end
    local hasil={}
    for nama in pairs(daftar) do hasil[#hasil+1]="• "..nama end
    return hasil
end

-- ============================================================
-- FUNGSI PENDUKUNG UTAMA
-- ============================================================
local function formatAngka(angka)
    if not angka or angka==0 then return "0" end
    local a=math.abs(angka)
    local suf=""
    if a>=1e12 then suf="T"; angka=angka/1e12
    elseif a>=1e9 then suf="B"; angka=angka/1e9
    elseif a>=1e6 then suf="M"; angka=angka/1e6
    elseif a>=1e3 then suf="K"; angka=angka/1e3 end
    return string.format("%.2f%s",angka,suf)
end

local function tabelKeJson(tbl)
    if type(tbl)~="table" then return "{}" end
    local b={}
    for k,v in pairs(tbl) do
        if type(v)=="string" then
            b[#b+1]=string.format('"%s":"%s"',k,v:gsub('"','\\\\"'))
        elseif type(v)=="number" then
            b[#b+1]=string.format('"%s":%s',k,v)
        elseif type(v)=="table" then
            b[#b+1]=string.format('"%s":%s',k,tabelKeJson(v))
        end
    end
    return "{"..table.concat(b,",").."}"
end

-- ============================================================
-- AMBIL DATA LENGKAP & TULIS KE BERKAS
-- ============================================================
local dataSebelum = ""
local daftarBeratSebelum = {}

local function ambilDanTulis()
    local plr = Players.LocalPlayer if not plr then return end

    local uang=0; local barang={}; local panen={}; local beratSekarang={}
    local totalBerat=0; local totalItem=0

    -- Uang sendiri
    pcall(function()
        local ls=plr:FindFirstChild("leaderstats")
        if ls then local v=ls:FindFirstChild("Sheckles") or ls:FindFirstChild("Money") if v then uang=v.Value end end
    end)

    -- Barang di tas
    for _,tempat in ipairs{plr:FindFirstChildOfClass("Backpack")} do
        if tempat then
            for _,item in tempat:GetChildren() do
                if item:IsA("Tool") then
                    local n=item.Name
                    local j=item:GetAttribute("Count") or 1
                    local b=item:GetAttribute("Weight") or 0
                    local m=item:GetAttribute("Mutation") or ""
                    if j<=0 then continue end

                    if b>0 then
                        local np=m~="" and m~="None" and string.format("%s [%s]",n,m) or n
                        beratSekarang[np]=j
                        if not panen[np] then panen[np]={jumlah=0,berat=0} end
                        panen[np].jumlah+=j; panen[np].berat+=b*j
                        totalBerat+=b*j
                    else
                        barang[n]=(barang[n] or 0)+j
                    end
                    totalItem+=j
                end
            end
        end
    end

    -- Perubahan jual/panen
    local terjual={}; local baruPanen={}
    for k,v in pairs(daftarBeratSebelum) do if not beratSekarang[k] then terjual[k]=v end end
    for k,v in pairs(beratSekarang) do local l=daftarBeratSebelum[k] or 0 if v>l then baruPanen[k]=v-l end end
    daftarBeratSebelum=beratSekarang

    -- ✅ Cuaca & Restock
    local cuaca=getWeatherInfo(); local stok=getRestockInfo()
    local teksCuaca={}
    teksCuaca[#teksCuaca+1]="🌤 Cuaca: "..cuaca.weather
    if cuaca.phase~="Unknown" then
        local f="🔄 Fase: "..cuaca.phase
        if cuaca.phaseEnd then f=f.." (ganti "..formatTimeLeft(cuaca.phaseEnd)..")" end
        teksCuaca[#teksCuaca+1]=f
    end
    teksCuaca[#teksCuaca+1]=""
    teksCuaca[#teksCuaca+1]="🔄 Restock:"
    teksCuaca[#teksCuaca+1]="  🌱 Seed: "..formatTimeLeft(stok.seed)
    teksCuaca[#teksCuaca+1]="  ⚙️ Gear: "..formatTimeLeft(stok.gear)
    teksCuaca[#teksCuaca+1]="  📦 Crate: "..formatTimeLeft(stok.crate)

    -- ✅ Pet
    local daftarPet=getWildPets()
    local teksPet=#daftarPet>0 and table.concat(daftarPet,"\n") or "— Tidak ada pet —"

    -- ✅ Pemain Server
    local daftarPemain=getDaftarPemain()
    local teksPemain={}
    for _,p in ipairs(daftarPemain) do
        teksPemain[#teksPemain+1]=string.format("• %s → %s", p.nama, p.uangTeks)
    end
    local teksPemainTampil=#teksPemain>0 and table.concat(teksPemain,"\n") or "— Sedang memuat —"

    -- ✅ Chat
    local teksChat=getTeksChat()

    -- ✅ Semua Data Gabungan
    local data={
        waktu=os.date("%H:%M:%S"), namaPemain=plr.Name,
        uang=uang, uangTeks=formatAngka(uang),
        barang=barang, panen=panen, terjual=terjual, baruPanen=baruPanen,
        totalBerat=totalBerat, beratTeks=formatAngka(totalBerat), totalItem=totalItem,

        weatherText=table.concat(teksCuaca,"\n"),
        petText=teksPet,
        playerText=teksPemainTampil,
        chatText=teksChat
    }

    local teksAkhir=tabelKeJson(data)
    if teksAkhir~=dataSebelum then
        dataSebelum=teksAkhir
        writefile(fullPath, teksAkhir)
    end
end

-- ============================================================
-- PEMANTAU RELOG
-- ============================================================
task.spawn(function()
    while true do
        task.wait(0.5)
        if isfile(fileRelog) then
            local isi=(readfile(fileRelog)or""):gsub("%s+",""):lower()
            if isi=="true" then
                print("[⚠️] Jalankan Relog")
                writefile(fileRelogAccept,"true")
                writefile(fileRelog,"")
                task.wait(0.2)
                pcall(function()
                    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,game.JobId,Players.LocalPlayer)
                end)
            end
        end
    end
end)

-- ============================================================
-- MULAI SEMUA
-- ============================================================
mulaiPantauChat() -- Jalankan pendengar chat
print("[✅] SISTEM LENGKAP: Cuaca+Restock+Pet+Pemain+Chat+Kirim Pesan")
ambilDanTulis()
task.spawn(function() while true do task.wait(2) ambilDanTulis() end end)
