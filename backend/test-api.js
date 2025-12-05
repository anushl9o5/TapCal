#!/usr/bin/env node

/**
 * TapCal Backend API Test Script
 * 
 * Usage:
 *   node test-api.js                           # Health check only
 *   node test-api.js path/to/image.png         # Analyze an image
 *   node test-api.js http://example.com        # Use different backend URL
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Configuration
const DEFAULT_BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';
const args = process.argv.slice(2);

// Parse arguments
let backendUrl = DEFAULT_BACKEND_URL;
let imagePath = null;

for (const arg of args) {
  if (arg.startsWith('http://') || arg.startsWith('https://')) {
    backendUrl = arg;
  } else if (fs.existsSync(arg)) {
    imagePath = arg;
  }
}

console.log('🧪 TapCal Backend API Test\n');
console.log(`Backend URL: ${backendUrl}`);
console.log('='.repeat(50));

// Test 1: Health Check
async function testHealth() {
  console.log('\n📋 Test 1: Health Check');
  console.log(`GET ${backendUrl}/api/health`);
  
  try {
    const response = await fetch(`${backendUrl}/api/health`);
    const data = await response.json();
    
    if (response.ok) {
      console.log('✅ PASS');
      console.log(JSON.stringify(data, null, 2));
    } else {
      console.log('❌ FAIL');
      console.log(JSON.stringify(data, null, 2));
    }
  } catch (error) {
    console.log('❌ FAIL - Connection error');
    console.log(`Error: ${error.message}`);
    console.log('\n💡 Make sure the backend is running:');
    console.log('   cd backend && npm run dev');
    process.exit(1);
  }
}

// Test 2: Analyze Image
async function testAnalyze(imagePath) {
  console.log('\n🖼️  Test 2: Image Analysis');
  console.log(`POST ${backendUrl}/api/analyze`);
  console.log(`Image: ${imagePath}`);
  
  try {
    // Read and encode image
    const imageBuffer = fs.readFileSync(imagePath);
    const base64Image = imageBuffer.toString('base64');
    const imageSize = (base64Image.length / 1024).toFixed(2);
    
    console.log(`Image size: ${imageSize} KB (base64)`);
    console.log('Sending to backend...');
    
    const startTime = Date.now();
    const response = await fetch(`${backendUrl}/api/analyze`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        image: base64Image,
        context: 'upload'
      }),
    });
    
    const duration = Date.now() - startTime;
    const data = await response.json();
    
    console.log(`Response time: ${duration}ms`);
    
    if (response.ok && data.success) {
      console.log('✅ PASS - Event detected');
      console.log('\n📅 Extracted Event:');
      console.log(JSON.stringify(data.event, null, 2));
    } else if (response.ok && !data.success) {
      console.log('⚠️  No event detected');
      console.log(`Reason: ${data.error}`);
    } else {
      console.log('❌ FAIL');
      console.log(JSON.stringify(data, null, 2));
    }
  } catch (error) {
    console.log('❌ FAIL');
    console.log(`Error: ${error.message}`);
  }
}

// Run tests
async function runTests() {
  await testHealth();
  
  if (imagePath) {
    await testAnalyze(imagePath);
  } else {
    console.log('\n💡 To test image analysis, run:');
    console.log(`   node test-api.js path/to/image.png`);
  }
  
  console.log('\n' + '='.repeat(50));
  console.log('✅ Tests complete\n');
}

runTests();

