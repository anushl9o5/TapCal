export interface CalendarEvent {
  title: string;
  date: string;
  time: string;
  location?: string;
  description?: string;
}

export enum AppMode {
  MESSAGING = 'MESSAGING',
  EMAIL = 'EMAIL',
  BROWSER = 'BROWSER',
  UPLOAD = 'UPLOAD'
}

export interface TouchPoint {
  x: number;
  y: number;
}
