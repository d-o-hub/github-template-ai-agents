// Eval fixture: an Express app with the header and CORS problems the eval names.
import express from "express";

const app = express();

app.use((_req, res, next) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Credentials", "true");
  next();
});

app.get("/api/orders", async (_req, res) => {
  res.json({ orders: await db.select("orders") });
});

app.listen(3000);