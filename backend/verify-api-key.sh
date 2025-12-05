#!/bin/bash

# Direct API Key Verification Script
# This tests your Gemini API key directly with Google's API, bypassing the backend

echo ""
echo "🔑 Gemini API Key Verification"
echo "==============================="
echo ""

# Load from .env file
if [ -f ".env" ]; then
  source .env 2>/dev/null || export $(grep -v '^#' .env | xargs)
fi

# Check if API key is set
if [ -z "$GEMINI_API_KEY" ]; then
  echo "❌ GEMINI_API_KEY is not set!"
  echo ""
  echo "Please set it in .env file:"
  echo "  GEMINI_API_KEY=your_actual_key_here"
  exit 1
fi

echo "API Key found: ${GEMINI_API_KEY:0:10}...${GEMINI_API_KEY: -5}"
echo "Length: ${#GEMINI_API_KEY} characters"
echo ""

# Check if it looks valid
if [[ ! "$GEMINI_API_KEY" =~ ^AIza ]]; then
  echo "⚠️  WARNING: API key should start with 'AIza'"
  echo "   Your key starts with: ${GEMINI_API_KEY:0:4}"
  echo ""
fi

if [[ "$GEMINI_API_KEY" == *"PLACEHOLDER"* ]] || [[ "$GEMINI_API_KEY" == *"your_"* ]]; then
  echo "❌ ERROR: You're using a placeholder API key!"
  echo "   Please replace with a real API key from:"
  echo "   https://aistudio.google.com/app/apikey"
  exit 1
fi

echo "Testing API key with Google Gemini API..."
echo ""

# Make a simple API call to list models (doesn't require any input)
RESPONSE=$(curl -s -w "\n%{http_code}" \
  "https://generativelanguage.googleapis.com/v1beta/models?key=$GEMINI_API_KEY")

# Extract status code (last line)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
# Extract body (all but last line)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "HTTP Status: $HTTP_CODE"
echo ""

if [ "$HTTP_CODE" = "200" ]; then
  echo "✅ SUCCESS! API key is valid and working!"
  echo ""
  echo "Available models:"
  echo "$BODY" | grep -o '"name": "[^"]*"' | head -5
  echo ""
  echo "Your API key is correctly configured!"
  echo ""
  echo "Next steps:"
  echo "  1. Restart the backend server"
  echo "  2. Test with test.html"
  echo ""
elif [ "$HTTP_CODE" = "400" ]; then
  echo "❌ INVALID API KEY"
  echo ""
  echo "Error: $BODY"
  echo ""
  echo "The API key format is invalid. Please check:"
  echo "  - No extra spaces or quotes"
  echo "  - Complete key (should be ~39 characters)"
  echo "  - Get a new key from: https://aistudio.google.com/app/apikey"
elif [ "$HTTP_CODE" = "403" ]; then
  echo "❌ PERMISSION DENIED"
  echo ""
  echo "Error: $BODY"
  echo ""
  echo "Possible causes:"
  echo "  1. API key is invalid or revoked"
  echo "  2. API key doesn't have access to Gemini API"
  echo "  3. API key is from a different Google Cloud project"
  echo ""
  echo "Solutions:"
  echo "  1. Go to: https://aistudio.google.com/app/apikey"
  echo "  2. Create a NEW API key"
  echo "  3. Copy it to backend/.env"
  echo "  4. Restart the server"
else
  echo "❌ UNEXPECTED ERROR (HTTP $HTTP_CODE)"
  echo ""
  echo "Response: $BODY"
fi

