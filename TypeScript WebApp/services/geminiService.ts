import { GoogleGenAI, Type } from "@google/genai";
import { CalendarEvent } from "../types";

const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });

export const analyzeScreenRegion = async (base64Image: string): Promise<CalendarEvent | null> => {
  try {
    // Remove header if present (data:image/png;base64,...)
    const cleanBase64 = base64Image.split(',')[1] || base64Image;

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
            - If a date is mentioned (e.g., "tomorrow", "next friday"), convert it to YYYY-MM-DD based on today being 2024-05-20.
            - If no title is clear, infer one from context (e.g. "Meeting with Sarah").
            - If no time is found, default to "09:00".
            - If nothing looks like an event, return null for values.`
          }
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
          required: ["title", "date", "time"]
        },
        systemInstruction: "You are a helpful Android OS assistant extracting calendar details from screen content.",
      },
    });

    const text = response.text;
    if (!text) return null;
    
    return JSON.parse(text) as CalendarEvent;

  } catch (error) {
    console.error("Gemini Analysis Failed:", error);
    return null;
  }
};