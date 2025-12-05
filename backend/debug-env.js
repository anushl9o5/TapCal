#!/usr/bin/env node

/**
 * Debug script to check environment variables
 */

import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

console.log('🔍 Environment Debug Tool\n');
console.log('='.repeat(50));

// Check if .env file exists
const envPath = path.join(__dirname, '.env');
console.log(`\n1. Checking .env file:`);
console.log(`   Path: ${envPath}`);

if (fs.existsSync(envPath)) {
  console.log('   Status: ✅ EXISTS');
  
  // Read .env file
  const envContent = fs.readFileSync(envPath, 'utf8');
  console.log(`   Size: ${envContent.length} bytes`);
  
  // Check for GEMINI_API_KEY line
  const lines = envContent.split('\n');
  const geminiLine = lines.find(line => line.trim().startsWith('GEMINI_API_KEY='));
  
  if (geminiLine) {
    const keyValue = geminiLine.split('=')[1]?.trim();
    if (keyValue && keyValue !== 'your_gemini_api_key_here' && keyValue !== '') {
      console.log(`   GEMINI_API_KEY: Found (${keyValue.length} chars)`);
      console.log(`   Preview: ${keyValue.substring(0, 10)}...${keyValue.substring(keyValue.length - 5)}`);
      console.log(`   Status: ✅ LOOKS GOOD`);
    } else {
      console.log(`   GEMINI_API_KEY: ❌ NOT SET or placeholder`);
      console.log(`   Current value: "${keyValue}"`);
    }
  } else {
    console.log(`   GEMINI_API_KEY: ❌ LINE NOT FOUND in .env file`);
  }
  
  console.log(`\n   .env file contents:`);
  console.log('   ' + '-'.repeat(48));
  lines.forEach(line => {
    if (line.trim().startsWith('GEMINI_API_KEY=')) {
      const keyValue = line.split('=')[1]?.trim();
      if (keyValue && keyValue.length > 10) {
        console.log(`   GEMINI_API_KEY=${keyValue.substring(0, 10)}...${keyValue.substring(keyValue.length - 5)}`);
      } else {
        console.log(`   ${line}`);
      }
    } else {
      console.log(`   ${line}`);
    }
  });
  console.log('   ' + '-'.repeat(48));
  
} else {
  console.log('   Status: ❌ DOES NOT EXIST');
  console.log('\n   You need to create it! Run:');
  console.log(`   echo "GEMINI_API_KEY=your_key_here" > ${envPath}`);
}

// Load dotenv
console.log(`\n2. Loading environment with dotenv:`);
dotenv.config();

// Check process.env
console.log(`\n3. Checking process.env.GEMINI_API_KEY:`);
if (process.env.GEMINI_API_KEY) {
  const key = process.env.GEMINI_API_KEY;
  console.log(`   Status: ✅ LOADED`);
  console.log(`   Length: ${key.length} characters`);
  console.log(`   Preview: ${key.substring(0, 10)}...${key.substring(key.length - 5)}`);
  console.log(`   Starts with 'AIza': ${key.startsWith('AIza') ? '✅ YES' : '❌ NO'}`);
  
  // Validate format
  if (!key.startsWith('AIza')) {
    console.log('\n   ⚠️  WARNING: API key should start with "AIza"');
  }
  if (key.length < 30) {
    console.log('\n   ⚠️  WARNING: API key seems too short (should be 30-40 chars)');
  }
  if (key === 'your_gemini_api_key_here' || key === 'your_actual_key_here') {
    console.log('\n   ❌ ERROR: You are using a placeholder! Replace with your real API key');
  }
  
} else {
  console.log('   Status: ❌ NOT LOADED');
  console.log('\n   Problem: dotenv did not load the GEMINI_API_KEY');
  console.log('   This usually means:');
  console.log('     - .env file is missing');
  console.log('     - .env file has no GEMINI_API_KEY= line');
  console.log('     - .env file has wrong format');
}

// Check TypeScript WebApp for comparison
console.log(`\n4. Checking TypeScript WebApp for reference:`);
const webappEnvPath = path.join(__dirname, '..', 'TypeScript WebApp', '.env.local');
if (fs.existsSync(webappEnvPath)) {
  console.log('   Status: ✅ Found TypeScript WebApp/.env.local');
  const webappContent = fs.readFileSync(webappEnvPath, 'utf8');
  const apiKeyLine = webappContent.split('\n').find(line => line.includes('API_KEY='));
  if (apiKeyLine) {
    const webappKey = apiKeyLine.split('=')[1]?.trim();
    if (webappKey && webappKey.length > 10) {
      console.log(`   Their API_KEY: ${webappKey.substring(0, 10)}...${webappKey.substring(webappKey.length - 5)} (${webappKey.length} chars)`);
      
      if (process.env.GEMINI_API_KEY === webappKey) {
        console.log('   ✅ Keys match!');
      } else {
        console.log('   ⚠️  Keys are different. Copy from webapp to backend?');
      }
    }
  }
} else {
  console.log('   Status: Not found (ok, maybe different location)');
}

console.log('\n' + '='.repeat(50));
console.log('\n📋 Summary:\n');

if (process.env.GEMINI_API_KEY && 
    process.env.GEMINI_API_KEY.startsWith('AIza') && 
    process.env.GEMINI_API_KEY.length > 30 &&
    process.env.GEMINI_API_KEY !== 'your_gemini_api_key_here') {
  console.log('✅ Everything looks good!');
  console.log('   Your API key is properly configured.');
  console.log('\n   If you still get 403 errors, the key might be:');
  console.log('   - Expired or revoked');
  console.log('   - From a different project');
  console.log('   - Not enabled for Gemini API');
  console.log('\n   Try creating a new key at:');
  console.log('   https://aistudio.google.com/app/apikey');
} else {
  console.log('❌ API key is not properly set up.');
  console.log('\n   Quick fix:');
  console.log('   1. Get your API key from: https://aistudio.google.com/app/apikey');
  console.log('   2. Edit backend/.env file');
  console.log('   3. Add line: GEMINI_API_KEY=your_actual_key');
  console.log('   4. Save and restart server');
}

console.log('');

