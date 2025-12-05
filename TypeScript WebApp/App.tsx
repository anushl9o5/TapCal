import React, { useState, useEffect, useRef } from 'react';
import { AndroidFrame } from './components/AndroidFrame';
import { TouchHandler } from './components/TouchHandler';
import { CalendarOverlay } from './components/CalendarOverlay';
import { generateMockScreen } from './utils/canvasUtils';
import { analyzeScreenRegion } from './services/geminiService';
import { AppMode, CalendarEvent, TouchPoint } from './types';
import { MessageCircle, Mail, Globe, Upload } from 'lucide-react';

const App: React.FC = () => {
  const [currentMode, setCurrentMode] = useState<AppMode>(AppMode.MESSAGING);
  const [screenImage, setScreenImage] = useState<string>('');
  
  // Overlay State
  const [isOverlayOpen, setIsOverlayOpen] = useState(false);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [detectedEvent, setDetectedEvent] = useState<CalendarEvent | null>(null);

  // Generate the screen image whenever mode changes
  useEffect(() => {
    if (currentMode !== AppMode.UPLOAD) {
      const img = generateMockScreen(currentMode, 360, 740);
      setScreenImage(img);
    } else {
      // Default placeholder for upload mode
      setScreenImage('https://picsum.photos/360/740');
    }
  }, [currentMode]);

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (ev) => {
        if (ev.target?.result) setScreenImage(ev.target.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  const handleTripleTap = async (croppedImageBase64: string, point: TouchPoint) => {
    setIsOverlayOpen(true);
    setIsAnalyzing(true);
    setDetectedEvent(null);

    // Call Gemini API
    const event = await analyzeScreenRegion(croppedImageBase64);
    
    setDetectedEvent(event);
    setIsAnalyzing(false);
  };

  const handleSave = () => {
    alert("Event saved to Google Calendar! (Simulation)");
    setIsOverlayOpen(false);
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-8 bg-gradient-to-br from-indigo-100 to-purple-100">
      
      <div className="flex gap-12 items-start">
        
        {/* Controls / Instructions */}
        <div className="hidden lg:flex flex-col space-y-6 max-w-xs pt-10">
          <div>
            <h1 className="text-3xl font-bold text-gray-900 mb-2">TapCal Prototype</h1>
            <p className="text-gray-600">
              Experience the future of Android productivity. Triple-tap anywhere on the simulated screen to detect events using Gemini AI.
            </p>
          </div>

          <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
            <h2 className="font-semibold text-gray-800 mb-4">Select App Context</h2>
            <div className="grid grid-cols-2 gap-3">
              <button 
                onClick={() => setCurrentMode(AppMode.MESSAGING)}
                className={`p-3 rounded-xl flex flex-col items-center gap-2 transition-colors ${currentMode === AppMode.MESSAGING ? 'bg-blue-100 text-blue-700' : 'bg-gray-50 text-gray-600 hover:bg-gray-100'}`}
              >
                <MessageCircle className="w-6 h-6" />
                <span className="text-xs font-medium">Chat</span>
              </button>
              
              <button 
                onClick={() => setCurrentMode(AppMode.EMAIL)}
                className={`p-3 rounded-xl flex flex-col items-center gap-2 transition-colors ${currentMode === AppMode.EMAIL ? 'bg-blue-100 text-blue-700' : 'bg-gray-50 text-gray-600 hover:bg-gray-100'}`}
              >
                <Mail className="w-6 h-6" />
                <span className="text-xs font-medium">Email</span>
              </button>

              <button 
                onClick={() => setCurrentMode(AppMode.BROWSER)}
                className={`p-3 rounded-xl flex flex-col items-center gap-2 transition-colors ${currentMode === AppMode.BROWSER ? 'bg-blue-100 text-blue-700' : 'bg-gray-50 text-gray-600 hover:bg-gray-100'}`}
              >
                <Globe className="w-6 h-6" />
                <span className="text-xs font-medium">Browser</span>
              </button>

              <button 
                onClick={() => setCurrentMode(AppMode.UPLOAD)}
                className={`p-3 rounded-xl flex flex-col items-center gap-2 transition-colors ${currentMode === AppMode.UPLOAD ? 'bg-blue-100 text-blue-700' : 'bg-gray-50 text-gray-600 hover:bg-gray-100'}`}
              >
                <Upload className="w-6 h-6" />
                <span className="text-xs font-medium">Custom</span>
              </button>
            </div>

            {currentMode === AppMode.UPLOAD && (
              <div className="mt-4">
                <input 
                  type="file" 
                  accept="image/*"
                  onChange={handleFileUpload}
                  className="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-xs file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
                />
              </div>
            )}
          </div>

          <div className="bg-blue-50 p-4 rounded-xl border border-blue-100 text-sm text-blue-800">
             <strong>How to use:</strong>
             <ul className="list-disc ml-4 mt-2 space-y-1">
               <li>Select "Chat" or "Email".</li>
               <li>Find a date/time in the text.</li>
               <li><strong>Triple-click</strong> directly on it.</li>
               <li>Watch Gemini analyze the crop.</li>
             </ul>
          </div>
        </div>

        {/* The Phone */}
        <AndroidFrame>
          <div className="relative w-full h-full">
            <TouchHandler 
              imageSrc={screenImage}
              onTripleTap={handleTripleTap}
            />
            
            <CalendarOverlay 
              isOpen={isOverlayOpen}
              isLoading={isAnalyzing}
              event={detectedEvent}
              onClose={() => setIsOverlayOpen(false)}
              onSave={handleSave}
            />
          </div>
        </AndroidFrame>

        {/* Mobile controls (visible only on small screens) */}
        <div className="lg:hidden fixed bottom-0 left-0 right-0 bg-white p-4 shadow-lg flex justify-around z-50">
             <button onClick={() => setCurrentMode(AppMode.MESSAGING)}><MessageCircle /></button>
             <button onClick={() => setCurrentMode(AppMode.EMAIL)}><Mail /></button>
             <button onClick={() => setCurrentMode(AppMode.BROWSER)}><Globe /></button>
        </div>

      </div>
    </div>
  );
};

export default App;
