import { cors } from "@elysiajs/cors";
import { Elysia } from "elysia";

const PORT = Number(process.env.API_PORT) || 4000;

const app = new Elysia()
  .use(cors())
  .get("/", () => ({
    name: "LogersWallet API",
    version: "0.0.1",
    status: "ok",
  }))
  .get("/health", () => ({
    status: "healthy",
    timestamp: new Date().toISOString(),
  }))
  .listen(PORT);

// biome-ignore lint/suspicious/noConsoleLog: Server startup message
console.log(`🚀 LogersWallet API running at http://localhost:${app.server?.port}`);

export type App = typeof app;
