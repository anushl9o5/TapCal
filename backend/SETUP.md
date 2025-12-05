# 🔑 Quick Setup - Add Your API Key

## Problem

You're seeing this error:
```
"error": "PERMISSION_DENIED - Method doesn't allow unregistered callers"
```

This means your Gemini API key is missing from the backend.

## Solution (2 minutes)

### Option 1: Copy from Your TypeScript WebApp

You already have a working API key in your TypeScript webapp! Let's copy it:

1. **Open your TypeScript WebApp's .env file:**
   ```bash
   cat "TypeScript WebApp/.env.local"
   ```
   
   You should see something like:
   ```
   API_KEY=AIzaSy...your_key_here...
   ```

2. **Copy that API key value** (the part after `API_KEY=`)

3. **Open the backend .env file:**
   ```bash
   nano backend/.env
   ```
   
   Or open it in your editor: `backend/.env`

4. **Add the key:**
   ```bash
   GEMINI_API_KEY=AIzaSy...paste_your_key_here...
   PORT=3000
   NODE_ENV=development
   ```

5. **Save and close** (in nano: `Ctrl+O`, then `Enter`, then `Ctrl+X`)

6. **Restart the backend server:**
   ```bash
   # Stop the current server (Ctrl+C in the terminal running npm run dev)
   # Then start it again:
   cd backend
   npm run dev
   ```

7. **Test again in test.html** - Should work now! ✅

---

### Option 2: Get a New API Key

If you don't have an API key or want a new one:

1. **Visit:** https://aistudio.google.com/app/apikey

2. **Sign in** with your Google account

3. **Click "Create API Key"**

4. **Copy the key** (starts with `AIza...`)

5. **Add to backend/.env:**
   ```bash
   GEMINI_API_KEY=AIzaSy...your_new_key...
   ```

6. **Restart the backend server**

---

## Verify It's Working

After adding the key and restarting:

1. The server should start and show:
   ```
   ==================================================
   🚀 TapCal Backend API
   ==================================================
   ✅ Server running on: http://localhost:3000
   ✅ Environment: development
   ✅ Gemini API Key: ***configured***
   ==================================================
   ```

2. Open `test.html` in browser

3. Test connection (should show ONLINE ✅)

4. Upload an image with date/time text

5. Click "Analyze Image"

6. Should see extracted event! 🎉

---

## Still Not Working?

### Check 1: Is the .env file in the right place?
```bash
ls -la backend/.env
```
Should show the file exists.

### Check 2: Is the API key actually in the file?
```bash
grep GEMINI_API_KEY backend/.env
```
Should show: `GEMINI_API_KEY=AIza...`

### Check 3: Did you restart the server?
The `.env` file is only loaded when the server starts. Must restart!

### Check 4: Is the API key valid?
- Should start with `AIza`
- Should be 30-40 characters long
- No extra spaces or quotes
- Not expired or revoked

---

## Quick Commands

**View your webapp's API key:**
```bash
cat "TypeScript WebApp/.env.local"
```

**Edit backend .env:**
```bash
nano backend/.env
```

**Restart backend:**
```bash
cd backend
# Press Ctrl+C to stop
npm run dev
```

**Test:**
```bash
open backend/test.html
```

---

## Security Note

⚠️ **Never commit your `.env` file to git!**

The `.gitignore` is already configured to exclude it, but double-check:
```bash
git status
# Should NOT show backend/.env in the list
```

