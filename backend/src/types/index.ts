// Calendar event structure returned by Gemini
export interface CalendarEvent {
  title: string;
  date: string;
  time: string;
  location?: string;
  description?: string;
}

// API Request body
export interface AnalyzeRequest {
  image: string; // Base64 encoded image
  context?: 'messaging' | 'email' | 'browser' | 'upload';
}

// API Response structure
export interface AnalyzeResponse {
  success: boolean;
  event?: CalendarEvent;
  error?: string;
}

