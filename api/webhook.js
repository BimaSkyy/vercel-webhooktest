let dataTerakhir = { waktu:"--:--:--", sumber:"", data:{} };

module.exports = async (req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") return res.status(200).end();

  if (req.method === "POST") {
    try {
      const masuk = req.body || {};
      dataTerakhir = {
        waktu: masuk.waktu_kirim || new Date().toLocaleTimeString("id-ID"),
        sumber: masuk.sumber || "Tidak diketahui",
        data: masuk.data || {}
      };
      return res.status(200).json({pesan:"Diterima", ...dataTerakhir});
    } catch(e) { return res.status(400).json({pesan:"Gagal baca"}) }
  }

  return res.status(200).json(dataTerakhir);
};
