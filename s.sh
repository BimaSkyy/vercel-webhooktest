#!/data/data/com.termux/files/usr/bin/sh
# ✅ SUDAH DI LOKASI BENAR: /storage/emulated/0/Delta/Workspace/DataFarm/

# 📂 Semua berkas ada di sini
FILE="./datagag.json"
RELOG_FILE="./relog.txt"
RELOG_ACCEPT="./relogaccept.txt"
CHAT_CMD="./kirim_chat.txt"

# Pasang alat kalau belum ada
if ! command -v python3 &> /dev/null; then
    pkg update && pkg install python -y
fi
if ! command -v cloudflared &> /dev/null; then
    pkg install cloudflared -y
fi

# Siapkan berkas kosong kalau belum ada
[ ! -f "$RELOG_FILE" ] && echo "" > "$RELOG_FILE"
[ ! -f "$RELOG_ACCEPT" ] && echo "" > "$RELOG_ACCEPT"
[ ! -f "$CHAT_CMD" ] && echo "" > "$CHAT_CMD"

echo "=========================================="
echo "🚀 SERVER DI LOKASI: $(pwd)"
echo "=========================================="

# 🛠️ Buat server Python
cat > server_api.py << 'END_PY'
from http.server import HTTPServer, BaseHTTPRequestHandler
import json, os

class Peladen(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # Matikan log bawaan biar terminal bersih

    def _balas(self, isi, tipe="application/json", kode=200):
        self.send_response(kode)
        self.send_header("Content-Type", tipe)
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
        self._balas({})

    def do_GET(self):
        jalur = self.path.lstrip("/")

        if self.path == "/":
            try:
                with open("index.html", "rb") as f:
                    self._balas(f.read(), "text/html")
            except:
                self._balas({"pesan": "index.html tidak ada"}, 404)

        # ✅ FIX: Bungkus semua field di bawah "data" agar cocok dengan index.html
        elif self.path == "/api/webhook":
            try:
                with open("datagag.json", "r", encoding="utf-8") as f:
                    raw = json.load(f)
                # Baca chat dari file terpisah
                chat = ""
                try:
                    chat = open("kirim_chat.txt", "r").read().strip()
                except:
                    pass
                keluar = {
                    "waktu": raw.get("waktu", ""),
                    "data": {
                        "uangTeks":    raw.get("uangTeks", "0"),
                        "beratTeks":   raw.get("beratTeks", "0"),
                        "jumlahTeks":  raw.get("jumlahTeks", "0"),
                        "totalItem":   raw.get("totalItem", 0),
                        "weatherText": raw.get("weatherText", ""),
                        "petText":     raw.get("petText", ""),
                        "playerText":  raw.get("playerText", ""),
                        "chatText":    chat,
                        "barang":      raw.get("barang", {}),
                        "baruPanen":   raw.get("dipanenBaru", {}),
                        "terjual":     raw.get("terjual", {})
                    }
                }
                self._balas(keluar)
            except Exception as e:
                self._balas({"pesan": "belum ada data", "err": str(e)})

        elif self.path == "/api/relog":
            n = ""
            try: n = open("relog.txt", "r").read().strip()
            except: pass
            self._balas({"perintah": "true" if n == "true" else "false"})

        elif self.path == "/api/kirimchat":
            n = ""
            try: n = open("kirim_chat.txt", "r").read().strip()
            except: pass
            self._balas({"pesan": n})

        elif os.path.exists(jalur):
            jenis = "text/plain"
            if jalur.endswith(".css"): jenis = "text/css"
            elif jalur.endswith(".js"): jenis = "text/javascript"
            elif jalur.endswith(".json"): jenis = "application/json"
            try:
                with open(jalur, "rb") as f:
                    self._balas(f.read(), jenis)
            except:
                self._balas({"pesan": "tidak ada"}, 404)
        else:
            self._balas({"pesan": "tidak ditemukan"}, 404)

    def do_POST(self):
        panjang = int(self.headers.get("Content-Length", "0"))
        data = json.loads(self.rfile.read(panjang).decode("utf-8", "ignore") or "{}")

        if self.path == "/api/webhook":
            try:
                with open("datagag.json", "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2)
                self._balas({"ok": True})
            except Exception as e:
                self._balas({"ok": False, "err": str(e)}, 500)

        elif self.path == "/api/relog":
            with open("relog.txt", "w") as f:
                f.write("true" if data.get("perintah") == "true" else "")
            self._balas({"ok": True})

        elif self.path == "/api/kirimchat":
            with open("kirim_chat.txt", "w") as f:
                f.write(data.get("pesan", "").strip())
            self._balas({"ok": True})

        else:
            self._balas({"pesan": "tidak ada"}, 404)

if __name__ == "__main__":
    print("✅ Peladen siap di port 8080")
    HTTPServer(("0.0.0.0", 8080), Peladen).serve_forever()
END_PY

# Jalankan server
python3 server_api.py &
PID_SRV=$!

# Jalankan terowongan Cloudflare
echo "🌐 Menghubungkan akses luar..."
cloudflared tunnel --url http://localhost:8080 &
PID_TUN=$!

# 🔄 Pengawas Relog
echo "🔍 Pantau perintah Relog berjalan..."
while true; do
    if [ -s "$RELOG_FILE" ] && [ "$(tr -d '[:space:]' < "$RELOG_FILE")" = "true" ]; then
        echo "[🔄] Perintah Relog diterima"
        while true; do
            sleep 0.5
            if [ -f "$RELOG_ACCEPT" ] && [ "$(tr -d '[:space:]' < "$RELOG_ACCEPT")" = "true" ]; then
                echo "[✅] Relog selesai — bersihkan status"
                echo "" > "$RELOG_FILE"
                echo "" > "$RELOG_ACCEPT"
                break
            fi
        done
    fi
    sleep 2
done

# Hentikan semua kalau ditutup
trap "echo '🛑 Berhenti...'; kill $PID_SRV $PID_TUN 2>/dev/null; exit" INT TERM EXIT
