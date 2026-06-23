let perintahRelog = { perintah: "false", status: "siap" };

module.exports = async (req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") return res.status(200).end();

  if (req.method === "POST") {
    try {
      const b = req.body || {};
      // Hanya terima perintah nyata, tapi jangan kunci selamanya
      if (b.perintah === "true") {
        perintahRelog = { perintah:"true", status:"menunggu" };
      } else {
        perintahRelog = { perintah:"false", status: b.status || "siap" };
      }
      return res.status(200).json({ok:true, ...perintahRelog});
    } catch(e) { return res.status(400).json({ok:false}) }
  }

  return res.status(200).json(perintahRelog);
};
