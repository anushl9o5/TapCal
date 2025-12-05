import express, { Express, Request, Response, NextFunction } from "express";
import cors from "cors";
import dotenv from "dotenv";
import analyzeRouter from "./routes/analyze.js";

// Load environment variables
dotenv.config();

// Check for API key early
if (!process.env.GEMINI_API_KEY) {
  console.error('');
  console.error('❌ ERROR: GEMINI_API_KEY is not set!');
  console.error('');
  console.error('Please add your Gemini API key to the .env file:');
  console.error('  1. Open: backend/.env');
  console.error('  2. Add: GEMINI_API_KEY=your_actual_key_here');
  console.error('  3. Restart the server');
  console.error('');
  console.error('Get your API key here: https://aistudio.google.com/app/apikey');
  console.error('');
  process.exit(1);
}

const app: Express = express();
const PORT = process.env.PORT || 3000;

// ============================================
// MIDDLEWARE
// ============================================

// CORS - Allow requests from Flutter app
app.use(cors({
  origin: '*', // For development - restrict in production
  methods: ['GET', 'POST'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// Body parser
app.use(express.json({ limit: '10mb' })); // Increased limit for base64 images
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Request logging
app.use((req: Request, res: Response, next: NextFunction) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// ============================================
// ROUTES
// ============================================

// Root endpoint
app.get("/", (req: Request, res: Response) => {
  res.json({
    name: "TapCal Backend API",
    version: "1.0.0",
    description: "AI-powered calendar event extraction from screen content",
    endpoints: {
      health: "GET /api/health",
      analyze: "POST /api/analyze",
    },
    documentation: "See README.md for usage instructions",
  });
});

// API routes
app.use("/api", analyzeRouter);

// 404 handler
app.use((req: Request, res: Response) => {
  res.status(404).json({
    error: "Endpoint not found",
    path: req.path,
    availableEndpoints: ["/", "/api/health", "/api/analyze"],
  });
});

// ============================================
// ERROR HANDLING
// ============================================

app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error("[Server Error]", err);
  res.status(500).json({
    error: "Internal server error",
    message: err.message,
  });
});

// ============================================
// START SERVER
// ============================================

app.listen(PORT, () => {
  console.log("=".repeat(50));
  console.log("🚀 TapCal Backend API");
  console.log("=".repeat(50));
  console.log(`✅ Server running on: http://localhost:${PORT}`);
  console.log(`✅ Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`✅ Gemini API Key: ${process.env.GEMINI_API_KEY ? '***configured***' : '❌ MISSING'}`);
  console.log("=".repeat(50));
  console.log("\nEndpoints:");
  console.log(`  GET  /              - API info`);
  console.log(`  GET  /api/health    - Health check`);
  console.log(`  POST /api/analyze   - Analyze screen image`);
  console.log("=".repeat(50));
});

export default app;

