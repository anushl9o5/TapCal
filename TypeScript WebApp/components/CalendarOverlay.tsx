import React from 'react';
import { CalendarEvent } from '../types';
import { Calendar, MapPin, Clock, X, Check, Loader2, Sparkles } from 'lucide-react';

interface CalendarOverlayProps {
  isOpen: boolean;
  isLoading: boolean;
  event: CalendarEvent | null;
  onClose: () => void;
  onSave: () => void;
}

export const CalendarOverlay: React.FC<CalendarOverlayProps> = ({ 
  isOpen, 
  isLoading, 
  event, 
  onClose, 
  onSave 
}) => {
  if (!isOpen) return null;

  return (
    <div className="absolute inset-0 bg-black/40 z-20 flex items-end justify-center backdrop-blur-[1px] transition-all duration-300">
      <div className="w-full bg-white rounded-t-3xl shadow-2xl p-6 transform transition-transform duration-300 animate-in slide-in-from-bottom">
        
        {/* Loading State */}
        {isLoading && (
          <div className="flex flex-col items-center justify-center py-12 space-y-4">
            <div className="relative">
              <div className="absolute inset-0 bg-blue-100 rounded-full animate-ping opacity-75"></div>
              <div className="relative bg-blue-50 p-4 rounded-full">
                <Sparkles className="w-8 h-8 text-blue-600 animate-pulse" />
              </div>
            </div>
            <p className="text-gray-600 font-medium">Analyzing screen content...</p>
          </div>
        )}

        {/* Result State */}
        {!isLoading && event && (
          <div className="space-y-6">
            <div className="flex justify-between items-center border-b border-gray-100 pb-4">
              <div className="flex items-center space-x-2">
                <div className="bg-blue-100 p-2 rounded-lg">
                   <Calendar className="w-5 h-5 text-blue-600" />
                </div>
                <h3 className="text-lg font-bold text-gray-900">New Event</h3>
              </div>
              <button onClick={onClose} className="p-2 hover:bg-gray-100 rounded-full">
                <X className="w-5 h-5 text-gray-500" />
              </button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Title</label>
                <input 
                  type="text" 
                  defaultValue={event.title}
                  className="w-full text-xl font-semibold text-gray-900 border-b border-transparent focus:border-blue-500 focus:outline-none bg-transparent"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                 <div className="space-y-1">
                    <label className="text-xs font-semibold text-gray-400 uppercase tracking-wider flex items-center gap-1">
                      <Calendar className="w-3 h-3" /> Date
                    </label>
                    <div className="bg-gray-50 p-3 rounded-xl text-gray-800 font-medium">
                      {event.date}
                    </div>
                 </div>
                 <div className="space-y-1">
                    <label className="text-xs font-semibold text-gray-400 uppercase tracking-wider flex items-center gap-1">
                      <Clock className="w-3 h-3" /> Time
                    </label>
                    <div className="bg-gray-50 p-3 rounded-xl text-gray-800 font-medium">
                      {event.time}
                    </div>
                 </div>
              </div>

              {event.location && (
                <div className="space-y-1">
                   <label className="text-xs font-semibold text-gray-400 uppercase tracking-wider flex items-center gap-1">
                      <MapPin className="w-3 h-3" /> Location
                   </label>
                   <div className="flex items-center text-gray-700 bg-gray-50 p-3 rounded-xl">
                      <span>{event.location}</span>
                   </div>
                </div>
              )}
            </div>

            <div className="pt-2">
              <button 
                onClick={onSave}
                className="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-4 rounded-xl flex items-center justify-center space-x-2 transition-colors shadow-lg shadow-blue-200"
              >
                <Check className="w-5 h-5" />
                <span>Add to Calendar</span>
              </button>
            </div>
          </div>
        )}

        {/* Empty State / Failure */}
        {!isLoading && !event && (
           <div className="flex flex-col items-center justify-center py-8 space-y-4">
             <div className="bg-red-50 p-3 rounded-full">
                <X className="w-6 h-6 text-red-500" />
             </div>
             <p className="text-gray-600 text-center">Could not detect an event in that area.<br/>Try tapping closer to the text.</p>
             <button onClick={onClose} className="text-blue-600 font-medium hover:underline">Close</button>
           </div>
        )}
      </div>
    </div>
  );
};
