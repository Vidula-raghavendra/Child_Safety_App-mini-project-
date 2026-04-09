import express from "express";
import { createServer as createViteServer } from "vite";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function startServer() {
  const app = express();
  const PORT = 3000;

  app.use(express.json());

  // API Routes
  app.post("/api/send_sos", (req, res) => {
    const { userId, location } = req.body;
    console.log(`SOS Alert from ${userId} at ${JSON.stringify(location)}`);
    res.json({ success: true, alertId: Date.now().toString() });
  });

  app.post("/api/submit_report", (req, res) => {
    const { userId, description } = req.body;
    console.log(`Report from ${userId}: ${description}`);
    res.json({ success: true, reportId: Date.now().toString() });
  });

  app.post("/api/predict_user_type", (req, res) => {
    const { pressure, speed, duration } = req.body;
    // Simple heuristic simulating the ML model
    // Children often have lighter pressure or different swipe patterns
    const isChild = pressure < 0.5 || speed > 1000; 
    res.json({ userType: isChild ? "Child" : "Adult" });
  });

  // Vite middleware for development
  if (process.env.NODE_ENV !== "production") {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: "spa",
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(process.cwd(), "dist");
    app.use(express.static(distPath));
    app.get("*", (req, res) => {
      res.sendFile(path.join(distPath, "index.html"));
    });
  }

  app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

startServer();
