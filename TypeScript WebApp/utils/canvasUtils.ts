import { AppMode } from "../types";

// Generates a base64 image of a fake app screen so we can actually crop it
export const generateMockScreen = (mode: AppMode, width: number, height: number): string => {
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');

  if (!ctx) return '';

  // Background
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, width, height);

  // Status Bar
  ctx.fillStyle = '#e5e7eb';
  ctx.fillRect(0, 0, width, 30);
  ctx.fillStyle = '#000000';
  ctx.font = '12px Arial';
  ctx.fillText('10:45', 20, 20);
  ctx.fillText('5G', width - 40, 20);

  if (mode === AppMode.MESSAGING) {
    // App Header
    ctx.fillStyle = '#3b82f6';
    ctx.fillRect(0, 30, width, 50);
    ctx.fillStyle = 'white';
    ctx.font = 'bold 18px Arial';
    ctx.fillText('Sarah (Work)', 20, 62);

    // Chat Bubbles
    drawBubble(ctx, 'left', 'Hey, are we still on for the team lunch?', 100, width);
    drawBubble(ctx, 'right', 'Yes! Where should we go?', 160, width);
    drawBubble(ctx, 'left', 'How about Mario\'s Italian? They have great pizza.', 220, width);
    drawBubble(ctx, 'left', 'Let\'s meet this Friday at 1:00 PM.', 280, width);
    drawBubble(ctx, 'right', 'Perfect. See you there!', 340, width);
  
  } else if (mode === AppMode.EMAIL) {
    // App Header
    ctx.fillStyle = '#ef4444';
    ctx.fillRect(0, 30, width, 50);
    ctx.fillStyle = 'white';
    ctx.font = 'bold 18px Arial';
    ctx.fillText('Inbox (3)', 20, 62);

    // Email List
    drawEmailItem(ctx, 'Amazon', 'Your order has shipped', '10:30 AM', 90, width);
    drawEmailItem(ctx, 'Dr. Smith', 'Appointment Confirmation', 'Yesterday', 160, width);
    
    // Open Email View
    ctx.fillStyle = '#f3f4f6';
    ctx.fillRect(0, 230, width, height - 230);
    ctx.fillStyle = '#1f2937';
    ctx.font = 'bold 16px Arial';
    ctx.fillText('Subject: Dental Checkup', 20, 260);
    ctx.font = '14px Arial';
    ctx.fillStyle = '#4b5563';
    ctx.fillText('From: Dr. Smith <clinic@health.com>', 20, 280);
    
    ctx.fillStyle = '#000000';
    ctx.font = '14px Arial';
    ctx.fillText('Hi there,', 20, 320);
    ctx.fillText('Just a reminder for your checkup.', 20, 340);
    ctx.fillText('Date: May 24th, 2024', 20, 370);
    ctx.fillText('Time: 10:00 AM', 20, 390);
    ctx.fillText('Location: City Dental Clinic', 20, 410);

  } else if (mode === AppMode.BROWSER) {
     // App Header
     ctx.fillStyle = '#374151';
     ctx.fillRect(0, 30, width, 50);
     ctx.fillStyle = '#9ca3af';
     ctx.fillRect(20, 40, width - 80, 30); // Search bar
     ctx.fillStyle = 'white';
     ctx.font = '12px Arial';
     ctx.fillText('ticketmaster.com/event/...', 30, 60);

     // Web Content
     ctx.fillStyle = '#1e3a8a';
     ctx.fillRect(20, 100, width - 40, 150);
     ctx.fillStyle = 'white';
     ctx.font = 'bold 20px Arial';
     ctx.fillText('The Rock Band Live', 40, 140);
     ctx.font = '16px Arial';
     ctx.fillText('World Tour 2024', 40, 170);
     
     ctx.fillStyle = '#fbbf24';
     ctx.fillRect(40, 200, 120, 30);
     ctx.fillStyle = 'black';
     ctx.font = 'bold 12px Arial';
     ctx.fillText('CONFIRMED', 60, 220);

     ctx.fillStyle = 'black';
     ctx.font = '14px Arial';
     ctx.fillText('Saturday, June 15 @ 8:00 PM', 20, 280);
     ctx.fillText('Madison Square Garden', 20, 300);
  }

  return canvas.toDataURL('image/png');
};

const drawBubble = (ctx: CanvasRenderingContext2D, align: 'left'|'right', text: string, y: number, screenWidth: number) => {
  const x = align === 'left' ? 20 : screenWidth - 220;
  const color = align === 'left' ? '#e5e7eb' : '#3b82f6';
  const textColor = align === 'left' ? '#000000' : '#ffffff';
  
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.roundRect(x, y, 200, 50, 15);
  ctx.fill();

  ctx.fillStyle = textColor;
  ctx.font = '13px Arial';
  
  // Very basic text wrapping for canvas (simplified for prototype)
  const words = text.split(' ');
  let line = '';
  let lineY = y + 20;
  
  // Simple truncation/rendering for the prototype
  if (text.length > 30) {
      ctx.fillText(text.substring(0, 30), x + 10, lineY);
      ctx.fillText(text.substring(30), x + 10, lineY + 18);
  } else {
      ctx.fillText(text, x + 10, y + 30);
  }
};

const drawEmailItem = (ctx: CanvasRenderingContext2D, sender: string, subject: string, time: string, y: number, width: number) => {
    ctx.fillStyle = 'white';
    ctx.fillRect(0, y, width, 60);
    ctx.strokeStyle = '#e5e7eb';
    ctx.strokeRect(0, y, width, 60);

    ctx.fillStyle = 'black';
    ctx.font = 'bold 14px Arial';
    ctx.fillText(sender, 20, y + 20);
    
    ctx.fillStyle = '#4b5563';
    ctx.font = '13px Arial';
    ctx.fillText(subject, 20, y + 40);

    ctx.fillStyle = '#9ca3af';
    ctx.font = '12px Arial';
    ctx.fillText(time, width - 70, y + 20);
}
