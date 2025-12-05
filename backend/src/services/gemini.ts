import { GoogleGenAI, Type } from "@google/genai";
import { CalendarEvent } from "../types/index.js";
import dotenv from "dotenv";

// Load environment variables BEFORE initializing the client
dotenv.config();

// Initialize Gemini AI client
const apiKey = process.env.GEMINI_API_KEY;
if (!apiKey) {
  console.error('[Gemini] ❌ CRITICAL: No API key found!');
  console.error('[Gemini] Make sure GEMINI_API_KEY is set in backend/.env');
}

console.log(`[Gemini] Initializing with API key: ${apiKey ? `${apiKey.substring(0, 10)}...` : 'MISSING'}`);
const ai = new GoogleGenAI({ apiKey: apiKey || "" });

/**
 * Analyzes a cropped screen region and extracts calendar event details
 * @param base64Image - Base64 encoded image (with or without data URI prefix)
 * @returns CalendarEvent object or null if no event detected
 */
export const analyzeScreenRegion = async (
  base64Image: string
): Promise<CalendarEvent | null> => {
  try {
    // Remove data URI header if present (data:image/png;base64,...)
    const cleanBase64 = base64Image.includes(',')
      ? base64Image.split(',')[1]
      : base64Image;

    console.log('[Gemini] Starting analysis...');
    
    const response = await ai.models.generateContent({
      model: "gemini-2.5-flash",
      contents: {
        parts: [
          {
            inlineData: {
              mimeType: "image/png",
              data: cleanBase64,
            },
          },
          {
            text: `Analyze this image crop from a phone screen. The user triple-tapped here to save an event. 
            Extract event details. 
            - If a date is mentioned (e.g., "tomorrow", "next friday"), convert it to YYYY-MM-DD based on today being ${new Date().toISOString().split('T')[0]}.
            - If no title is clear, infer one from context (e.g. "Meeting with Sarah").
            - If no time is found, default to "09:00".
            - If nothing looks like an event, return null for values.
            - Look for any text that mentions dates, times, appointments, meetings, deadlines, or events.
            - Be generous in detecting potential calendar items.`,
          },
        ],
      },
      config: {
        responseMimeType: "application/json",
        responseSchema: {
          type: Type.OBJECT,
          properties: {
            title: { type: Type.STRING },
            date: { type: Type.STRING },
            time: { type: Type.STRING },
            location: { type: Type.STRING },
            description: { type: Type.STRING },
          },
          required: ["title", "date", "time"],
        },
        systemInstruction:
          "You are a helpful Android OS assistant extracting calendar details from screen content. Be proactive in detecting events.",
      },
    });

    const text = response.text;
    if (!text) {
      console.log('[Gemini] No response text received');
      return null;
    }

    const parsedEvent = JSON.parse(text) as CalendarEvent;
    console.log('[Gemini] Event extracted:', parsedEvent);

    // Validate that we got meaningful data
    if (!parsedEvent.title || parsedEvent.title === "null") {
      console.log('[Gemini] No valid event detected');
      return null;
    }

    return parsedEvent;

  } catch (error) {
    console.error("[Gemini] Analysis failed:", error);
    throw error; // Let the route handler deal with it
  }
};

