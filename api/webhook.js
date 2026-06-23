// Simpan data terakhir di memori (cocok untuk uji coba; akan kosong saat layanan dimulai ulang)
let dataTerakhir = {
  waktu: "Belum ada data masuk",
  isi: "-"
};

module.exports = async (req, res) => {
  // Izinkan akses dari mana saja
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") return res.status(200).end();

  // ✅ Saat ada kiriman data (POST) → simpan sebagai data terbaru
  if (req.method === "POST") {
    try {
      const masuk = req.body || {};
      dataTerakhir = {
        waktu: new Date().toLocaleString("id-ID", {timeZone: "Asia/Jakarta"}),
        isi: masuk
      };
      return res.status(200).json({pesan: "Data diterima", data: dataTerakhir});
    } catch (e) {
      return res.status(400).json({pesan: "Gagal membaca data"});
    }
  }

  // ✅ Saat halaman minta baca data (GET) → kirim yang terbaru
  if (req.method === "GET") {
    return res.status(200).json(dataTerakhir);
  }

  res.status(405).json({pesan: "Metode tidak diizinkan"});
};
