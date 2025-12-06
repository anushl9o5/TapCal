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
 * Analyzes a screen image and extracts ALL calendar events found
 * @param base64Image - Base64 encoded image (with or without data URI prefix)
 * @returns Array of CalendarEvent objects (empty if none detected)
 */
export const analyzeScreenForEvents = async (
  base64Image: string
): Promise<CalendarEvent[]> => {
  try {
    // Remove data URI header if present (data:image/png;base64,...)
    const cleanBase64 = base64Image.includes(',')
      ? base64Image.split(',')[1]
      : base64Image;

    console.log('[Gemini] Starting multi-event analysis...');
    
    const response = await ai.models.generateContent({
      model: "gemini-2.0-flash",
      contents: {
        parts: [
          {
            inlineData: {
              mimeType: "image/jpeg",
              data: cleanBase64,
            },
          },
          {
            text: `Analyze this screenshot and extract ALL calendar events or potential events visible.
            
Today's date is: ${new Date().toISOString().split('T')[0]}

Look for:
- Meetings, appointments, events with dates/times
- Deadlines, due dates
- Social gatherings, parties, dinners
- Movie times, show times, reservations
- Flight times, travel plans
- Any text that mentions a specific date, time, or scheduled activity

For EACH event found:
- title: Clear event name (infer if not explicit, e.g. "Meeting with John")
- date: In YYYY-MM-DD format (convert relative dates like "tomorrow", "next Friday")
- time: In HH:MM format (24h). Default to "12:00" if no time mentioned
- location: Venue/address if mentioned (can be empty)
- description: Brief context from surrounding text (can be empty)

Return ALL events you can find. If there's an event list, return each one.
If no events are detected, return an empty array.`,
          },
        ],
      },
      config: {
        responseMimeType: "application/json",
        responseSchema: {
          type: Type.OBJECT,
          properties: {
            events: {
              type: Type.ARRAY,
              items: {
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
            },
          },
          required: ["events"],
        },
        systemInstruction:
          "You are an expert at detecting calendar events from screenshots. Extract ALL events visible, be thorough. Return events in a JSON array. If multiple events are listed, return each separately.",
      },
    });

    const text = response.text;
    if (!text) {
      console.log('[Gemini] No response text received');
      return [];
    }

    const parsed = JSON.parse(text) as { events: CalendarEvent[] };
    console.log(`[Gemini] Found ${parsed.events?.length || 0} events`);
    
    // Filter out invalid events
    const validEvents = (parsed.events || []).filter(event => 
      event.title && 
      event.title !== "null" && 
      event.title.trim() !== "" &&
      event.date &&
      event.date !== "null"
    );

    console.log(`[Gemini] ${validEvents.length} valid events after filtering`);
    validEvents.forEach((e, i) => console.log(`  [${i + 1}] ${e.title} - ${e.date} ${e.time}`));

    return validEvents;

  } catch (error) {
    console.error("[Gemini] Analysis failed:", error);
    throw error;
  }
};

// Legacy single-event function for backwards compatibility
export const analyzeScreenRegion = async (
  base64Image: string
): Promise<CalendarEvent | null> => {
  const events = await analyzeScreenForEvents(base64Image);
  return events.length > 0 ? events[0] : null;
};
