#!/bin/bash

# TapCal Backend - API Key Setup Helper
# This script helps you copy your API key from the TypeScript WebApp to the backend

echo ""
echo "🔑 TapCal Backend - API Key Setup"
echo "=================================="
echo ""

# Check if TypeScript WebApp .env.local exists
WEBAPP_ENV="../TypeScript WebApp/.env.local"
BACKEND_ENV=".env"

if [ -f "$WEBAPP_ENV" ]; then
  echo "✅ Found existing API key in TypeScript WebApp"
  
  # Extract API key
  API_KEY=$(grep "API_KEY=" "$WEBAPP_ENV" | cut -d '=' -f2)
  
  if [ -z "$API_KEY" ]; then
    echo "❌ Could not extract API key from $WEBAPP_ENV"
    echo ""
    echo "Please manually copy your API key:"
    echo "  1. Open: TypeScript WebApp/.env.local"
    echo "  2. Copy the value after API_KEY="
    echo "  3. Add to backend/.env as GEMINI_API_KEY=your_key"
    exit 1
  fi
  
  echo "   API Key: ${API_KEY:0:10}...${API_KEY: -5}"
  echo ""
  
  # Create or update .env file
  if [ -f "$BACKEND_ENV" ]; then
    # Update existing file
    if grep -q "GEMINI_API_KEY=" "$BACKEND_ENV"; then
      # Replace existing key
      sed -i.bak "s/GEMINI_API_KEY=.*/GEMINI_API_KEY=$API_KEY/" "$BACKEND_ENV"
      echo "✅ Updated GEMINI_API_KEY in $BACKEND_ENV"
    else
      # Add key to existing file
      echo "GEMINI_API_KEY=$API_KEY" >> "$BACKEND_ENV"
      echo "✅ Added GEMINI_API_KEY to $BACKEND_ENV"
    fi
  else
    # Create new .env file
    cat > "$BACKEND_ENV" << EOF
# TapCal Backend Environment Variables
GEMINI_API_KEY=$API_KEY
PORT=3000
NODE_ENV=development
EOF
    echo "✅ Created $BACKEND_ENV with API key"
  fi
  
  echo ""
  echo "✅ Setup complete!"
  echo ""
  echo "Next steps:"
  echo "  1. Restart the backend server (Ctrl+C then 'npm run dev')"
  echo "  2. Test with: open test.html"
  echo ""
  
else
  echo "❌ Could not find TypeScript WebApp/.env.local"
  echo ""
  echo "Please create backend/.env manually:"
  echo ""
  echo "  1. Get your API key from: https://aistudio.google.com/app/apikey"
  echo "  2. Create backend/.env with:"
  echo ""
  echo "     GEMINI_API_KEY=your_api_key_here"
  echo "     PORT=3000"
  echo "     NODE_ENV=development"
  echo ""
fi

