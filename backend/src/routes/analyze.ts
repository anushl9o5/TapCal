import { Router, Request, Response } from "express";
import { analyzeScreenRegion } from "../services/gemini.js";
import { AnalyzeRequest, AnalyzeResponse } from "../types/index.js";

const router = Router();

/**
 * POST /api/analyze
 * Analyzes a cropped screen image and extracts calendar event details
 */
router.post("/analyze", async (req: Request, res: Response) => {
  const startTime = Date.now();
  
  try {
    const { image, context }: AnalyzeRequest = req.body;

    // Validation
    if (!image) {
      const response: AnalyzeResponse = {
        success: false,
        error: "Missing 'image' field in request body",
      };
      return res.status(400).json(response);
    }

    // Basic base64 validation
    if (typeof image !== "string" || image.length < 100) {
      const response: AnalyzeResponse = {
        success: false,
        error: "Invalid image data. Expected base64 encoded string.",
      };
      return res.status(400).json(response);
    }

    console.log(`[API] Analyzing image (context: ${context || 'unknown'})...`);

    // Call Gemini service
    const event = await analyzeScreenRegion(image);

    const duration = Date.now() - startTime;
    console.log(`[API] Analysis completed in ${duration}ms`);

    if (!event) {
      const response: AnalyzeResponse = {
        success: false,
        error: "No calendar event detected in the image",
      };
      return res.status(200).json(response);
    }

    const response: AnalyzeResponse = {
      success: true,
      event,
    };

    res.status(200).json(response);

  } catch (error) {
    console.error("[API] Error:", error);
    
    const response: AnalyzeResponse = {
      success: false,
      error: error instanceof Error ? error.message : "Internal server error",
    };
    
    res.status(500).json(response);
  }
});

/**
 * GET /api/health
 * Health check endpoint
 */
router.get("/health", (req: Request, res: Response) => {
  res.status(200).json({
    status: "healthy",
    timestamp: new Date().toISOString(),
    service: "TapCal Backend API",
  });
});

/**
 * GET /api/debug
 * Debug endpoint to check API key configuration
 */
router.get("/debug", (req: Request, res: Response) => {
  const apiKey = process.env.GEMINI_API_KEY;
  
  res.status(200).json({
    timestamp: new Date().toISOString(),
    environment: {
      GEMINI_API_KEY: apiKey ? {
        set: true,
        length: apiKey.length,
        preview: `${apiKey.substring(0, 8)}...${apiKey.substring(apiKey.length - 4)}`,
        startsWithAIza: apiKey.startsWith('AIza'),
        isPlaceholder: apiKey.includes('PLACEHOLDER') || apiKey.includes('your_') || apiKey.length < 20
      } : {
        set: false,
        error: "GEMINI_API_KEY not found in environment"
      },
      NODE_ENV: process.env.NODE_ENV || 'development',
      PORT: process.env.PORT || 3000
    }
  });
});

export default router;

