import React, { useState, useRef, useEffect } from 'react';
import { ROI_SIZE, DOUBLE_TAP_DELAY } from '../constants';
import { TouchPoint } from '../types';

interface TouchHandlerProps {
  imageSrc: string;
  onTripleTap: (croppedImage: string, point: TouchPoint) => void;
}

export const TouchHandler: React.FC<TouchHandlerProps> = ({ imageSrc, onTripleTap }) => {
  const [clicks, setClicks] = useState(0);
  const [ripples, setRipples] = useState<{ x: number, y: number, id: number }[]>([]);
  const timerRef = useRef<number | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const imageRef = useRef<HTMLImageElement>(null);

  // Reset clicks if user is too slow
  useEffect(() => {
    if (clicks > 0) {
      timerRef.current = window.setTimeout(() => {
        setClicks(0);
      }, DOUBLE_TAP_DELAY);
    }
    return () => {
      if (timerRef.current) clearTimeout(timerRef.current);
    };
  }, [clicks]);

  const addRipple = (x: number, y: number) => {
    const id = Date.now();
    setRipples(prev => [...prev, { x, y, id }]);
    setTimeout(() => {
      setRipples(prev => prev.filter(r => r.id !== id));
    }, 600);
  };

  const handleClick = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!containerRef.current || !imageRef.current) return;

    const rect = containerRef.current.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    addRipple(x, y);

    const newClickCount = clicks + 1;
    setClicks(newClickCount);

    if (newClickCount === 3) {
      // TRIPLE TAP DETECTED
      if (timerRef.current) clearTimeout(timerRef.current);
      setClicks(0);

      // Perform crop
      cropImage(x, y);
    }
  };

  const cropImage = (x: number, y: number) => {
    const img = imageRef.current;
    if (!img) return;

    // Calculate natural image scale (in case CSS scales it)
    const scaleX = img.naturalWidth / img.clientWidth;
    const scaleY = img.naturalHeight / img.clientHeight;

    const canvas = document.createElement('canvas');
    canvas.width = ROI_SIZE;
    canvas.height = ROI_SIZE;
    const ctx = canvas.getContext('2d');

    if (!ctx) return;

    // Center the crop around the click
    const sourceX = (x * scaleX) - (ROI_SIZE / 2);
    const sourceY = (y * scaleY) - (ROI_SIZE / 2);

    ctx.drawImage(
      img,
      sourceX, sourceY, ROI_SIZE, ROI_SIZE, // Source Rect
      0, 0, ROI_SIZE, ROI_SIZE // Destination Rect
    );

    const base64Crop = canvas.toDataURL('image/png');
    onTripleTap(base64Crop, { x, y });
  };

  return (
    <div 
      ref={containerRef}
      className="relative w-full h-full overflow-hidden cursor-pointer select-none"
      onClick={handleClick}
    >
      <img 
        ref={imageRef}
        src={imageSrc} 
        alt="Screen Content" 
        className="w-full h-full object-cover pointer-events-none"
      />
      
      {/* Visual Ripple Effect */}
      {ripples.map((r) => (
        <span
          key={r.id}
          className="absolute bg-blue-500/30 rounded-full animate-ping pointer-events-none"
          style={{
            left: r.x - 20,
            top: r.y - 20,
            width: 40,
            height: 40,
          }}
        />
      ))}
    </div>
  );
};