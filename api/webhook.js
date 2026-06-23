// Simpan data terakhir di memori
let dataTerakhir = {
  waktu: "Belum ada data",
  pengirim: "-",
  konten: ""
};

module.exports = async (req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") return res.status(200).end();

  // ✅ Saat TERIMA dari Termux
  if (req.method === "POST") {
    try {
      const masuk = req.body || {};
      dataTerakhir = {
        waktu: masuk.waktu || new Date().toLocaleString("id-ID", {timeZone: "Asia/Jakarta"}),
        pengirim: masuk.pengirim || "Tidak diketahui",
        konten: masuk.konten || ""
      };
      return res.status(200).json({pesan:"Diterima", ...dataTerakhir});
    } catch (e) {
      return res.status(400).json({pesan:"Gagal baca kiriman"});
    }
  }

  // ✅ Saat DIBACA oleh halaman web
  if (req.method === "GET") {
    return res.status(200).json(dataTerakhir);
  }

  res.status(405).json({pesan:"Metode tidak diizinkan"});
};
