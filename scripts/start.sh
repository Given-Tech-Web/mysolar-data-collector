#!/bin/bash

# Solar Data Collector Start Script

echo "🚀 Starting Solar Data Collector..."

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Check if dist folder exists
if [ ! -d "dist" ]; then
    echo "🔨 Building TypeScript..."
    npm run build
fi

# Test connections first
echo "🔍 Testing connections..."
node scripts/test-connection.js

if [ $? -ne 0 ]; then
    echo "❌ Connection test failed. Please check your configuration."
    exit 1
fi

# Start the service
echo "✅ Starting service..."
npm start