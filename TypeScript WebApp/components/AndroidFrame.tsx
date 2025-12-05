import React, { ReactNode } from 'react';
import { Battery, Wifi, Signal } from 'lucide-react';

interface AndroidFrameProps {
  children: ReactNode;
}

export const AndroidFrame: React.FC<AndroidFrameProps> = ({ children }) => {
  return (
    <div className="relative mx-auto w-[360px] h-[740px] bg-gray-900 rounded-[3rem] shadow-[0_0_0_12px_#374151,0_20px_50px_rgba(0,0,0,0.5)] overflow-hidden border-8 border-gray-800">
      
      {/* Front Camera Notch Area */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-32 h-6 bg-black rounded-b-xl z-50 flex justify-center items-center">
        <div className="w-12 h-1 bg-gray-800 rounded-full"></div>
      </div>

      {/* Screen Content */}
      <div className="w-full h-full bg-white overflow-hidden relative font-sans">
         {children}
      </div>

      {/* Home Indicator */}
      <div className="absolute bottom-1 left-1/2 -translate-x-1/2 w-32 h-1 bg-gray-400 rounded-full z-50 mb-2"></div>
    </div>
  );
};
