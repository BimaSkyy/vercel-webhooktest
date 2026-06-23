export default async function handler(req, res) {
  if (req.method === "POST") {
    const { pesan } = req.body || {};
    // Simpan sementara
    res.setHeader("Content-Type", "application/json");
    res.status(200).json({ pesan: pesan || "" });
  } else {
    // Baca nilai yang tersimpan
    res.status(200).json({ pesan: "" });
  }
}
