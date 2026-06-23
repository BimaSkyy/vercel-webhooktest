cat > s.sh <<'FULL_SCRIPT'
#!/data/data/com.termux/files/usr/bin/sh

# 📂 Lokasi berkas di dalam RedFinger
FILE="./datagag.json"
RELOG_FILE="./relog.txt"
RELOG_ACCEPT="./relogaccept.txt"
CHAT_CMD="./kirim_chat.txt"

# 🔗 Alamat terowongan yang sedang dipakai
ALAMAT_CLOUDFLARE="https://adipex-missile-uncle-postcards.trycloudflare.com"

# Pasang alat yang dibutuhkan jika belum ada
if ! command -v python3 &> /dev/null; then
    pkg update && pkg install python -y
fi
if ! command -v cloudflared &> /dev/null; then
    pkg install cloudflared -y
fi

# Siapkan berkas awal jika belum ada
[ ! -f "$RELOG_FILE" ] && echo "" > "$RELOG_FILE"
[ ! -f "$RELOG_ACCEPT" ] && echo "" > "$RELOG_ACCEPT"
[ ! -f "$CHAT_CMD" ] && echo "" > "$CHAT_CMD"

echo "=========================================="
echo "🚀 SERVER PEMANTAU LENGKAP DI REDFINGER"
echo "📍 Lokasi: $(pwd)"
echo "🔗 Alamat Publik: $ALAMAT_CLOUDFLARE"
echo "=========================================="

# 🛠️ Buat program peladen kustom yang MENGERTI /api/... & membaca berkas lokal
cat > server_api.py <<'END_PYTHON'
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import os

class PengendaliPermintaan(BaseHTTPRequestHandler):
    def _kirim_respons(self, isi, tipe_konten="application/json", kode=200):
        self.send_response(kode)
        self.send_header("Content-Type", tipe_konten)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()
        if isinstance(isi, dict):
            self.wfile.write(json.dumps(isi).encode("utf-8"))
        elif isinstance(isi, bytes):
            self.wfile.write(isi)
        else:
            self.wfile.write(str(isi).encode("utf-8"))

    def do_OPTIONS(self):
        self._kirim_respons({})

    def do_GET(self):
        if self.path == "/":
            try:
                with open("index.html", "rb") as f:
                    self._kirim_respons(f.read(), "text/html")
            except Exception as e:
                self._kirim_respons({"pesan": "index.html tidak ditemukan", "error": str(e)}, kode=404)

        elif self.path == "/api/webhook":
            try:
                with open("datagag.json", "r", encoding="utf-8") as f:
                    konten = f.read()
                    data = json.loads(konten)
                    self._kirim_respons(data)
            except Exception as e:
                self._kirim_respons({"sumber":"server", "data":{}, "pesan":"belum ada data"})

        elif self.path == "/api/relog":
            try:
                with open("relog.txt", "r", encoding="utf-8") as f:
                    nilai = f.read().strip()
            except:
                nilai = ""
            self._kirim_respons({"perintah": "true" if nilai == "true" else "false"})

        elif self.path == "/api/kirimchat":
            try:
                with open("kirim_chat.txt", "r", encoding="utf-8") as f:
                    teks = f.read().strip()
            except:
                teks = ""
            self._kirim_respons({"pesan": teks})

        elif os.path.exists(self.path.lstrip("/")):
            lokasi = self.path.lstrip("/")
            jenis = "text/plain"
            if lokasi.endswith(".css"): jenis = "text/css"
            elif lokasi.endswith(".js"): jenis = "text/javascript"
            elif lokasi.endswith(".json"): jenis = "application/json"
            try:
                with open(lokasi, "rb") as f:
                    self._kirim_respons(f.read(), jenis)
            except:
                self._kirim_respons({"pesan": "gagal baca berkas"}, kode=404)

        else:
            self._kirim_respons({"pesan": "alamat tidak ditemukan"}, kode=404)

    def do_POST(self):
        panjang = int(self.headers.get("Content-Length", "0"))
        data_baku = self.rfile.read(panjang).decode("utf-8")
        try:
            data = json.loads(data_baku)
        except:
            data = {}

        if self.path == "/api/webhook":
            try:
                with open("datagag.json", "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2)
                self._kirim_respons({"ok": True})
            except Exception as e:
                self._kirim_respons({"ok": False, "error": str(e)}, kode=500)

        elif self.path == "/api/relog":
            nilai = "true" if data.get("perintah") == "true" else ""
            try:
                with open("relog.txt", "w") as f:
                    f.write(nilai)
                self._kirim_respons({"ok": True})
            except Exception as e:
                self._kirim_respons({"ok": False, "error": str(e)}, kode=500)

        elif self.path == "/api/kirimchat":
            teks_pesan = data.get("pesan", "").strip()
            try:
                with open("kirim_chat.txt", "w") as f:
                    f.write(teks_pesan)
                self._kirim_respons({"ok": True})
            except Exception as e:
                self._kirim_respons({"ok": False, "error": str(e)}, kode=500)

        else:
            self._kirim_respons({"pesan": "tidak ada layanan ini"}, kode=404)

if __name__ == "__main__":
    print("✅ Peladen API siap di port 8080")
    HTTPServer(("0.0.0.0", 8080), PengendaliPermintaan).serve_forever()
END_PYTHON

# Jalankan peladen buatan sendiri
python3 server_api.py &
PID_SERVER=$!

# Jalankan terowongan Cloudflare
echo "🌐 Menghubungkan terowongan Cloudflare..."
cloudflared tunnel --url http://localhost:8080 &
PID_TEROWONGAN=$!

# Pengawas perintah relog
echo "🔍 Memantau perintah relog & berkas..."
while true; do
    if [ -s "$RELOG_FILE" ] && [ "$(cat "$RELOG_FILE" | tr -d '[:space:]')" = "true" ]; then
        echo "[🔄] Perintah Relog diterima"
        while true; do
            sleep 0.5
            if [ -f "$RELOG_ACCEPT" ] && [ "$(cat "$RELOG_ACCEPT" | tr -d '[:space:]')" = "true" ]; then
                echo "[✅] Relog selesai"
                echo "" > "$RELOG_FILE"
                echo "" > "$RELOG_ACCEPT"
                break
            fi
        done
    fi
    sleep 2
done

trap "echo '🛑 Menghentikan semua layanan...'; kill $PID_SERVER $PID_TEROWONGAN 2>/dev/null; exit 0" INT TERM EXIT
FULL_SCRIPT
