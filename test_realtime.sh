#!/bin/bash

# ========================================
# Dual Emulator Test Script
# Tests Supabase Realtime Inventory Sync
# ========================================

echo "🚀 Starting Dual Emulator Test for Realtime Inventory"
echo "=================================================="

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}Step 1: Checking available devices...${NC}"
flutter devices

echo ""
echo -e "${YELLOW}Please select TWO devices from the list above${NC}"
echo ""

# Get list of available devices
DEVICES=$(flutter devices | grep "•" | awk '{print $1, $2}' | grep -v "web-server" | head -2)

# Check if we have at least 2 devices
DEVICE_COUNT=$(echo "$DEVICES" | wc -l | tr -d ' ')

if [ "$DEVICE_COUNT" -lt 2 ]; then
    echo -e "${YELLOW}⚠️  Less than 2 devices available!${NC}"
    echo ""
    echo "Starting emulators for you..."
    
    # Start iOS simulator
    echo "Starting iOS Simulator..."
    open -a Simulator &
    sleep 5
    
    # Start Android emulator (if available)
    if [ -f "$HOME/Library/Android/sdk/emulator/emulator" ]; then
        echo "Starting Android Emulator..."
        # Get first available AVD
        AVD=$(~/Library/Android/sdk/emulator/emulator -list-avds | head -1)
        if [ -n "$AVD" ]; then
            ~/Library/Android/sdk/emulator/emulator -avd "$AVD" &
            sleep 10
        fi
    fi
    
    echo "Waiting for devices to boot..."
    sleep 5
    
    # Refresh device list
    DEVICES=$(flutter devices | grep "•" | awk '{print $1, $2}' | grep -v "web-server" | head -2)
fi

# Extract device IDs
DEVICE1=$(echo "$DEVICES" | head -1 | awk '{print $1}')
DEVICE2=$(echo "$DEVICES" | tail -1 | awk '{print $1}')

echo ""
echo -e "${GREEN}✅ Found devices:${NC}"
echo "   Device 1: $DEVICE1"
echo "   Device 2: $DEVICE2"
echo ""

# Ask user which device should be Owner
echo -e "${YELLOW}Which device should be the OWNER?${NC}"
echo "1) Device 1: $DEVICE1"
echo "2) Device 2: $DEVICE2"
read -p "Enter choice (1 or 2): " OWNER_CHOICE

if [ "$OWNER_CHOICE" = "1" ]; then
    OWNER_DEVICE=$DEVICE1
    STAFF_DEVICE=$DEVICE2
else
    OWNER_DEVICE=$DEVICE2
    STAFF_DEVICE=$DEVICE1
fi

echo ""
echo -e "${GREEN}Test Setup:${NC}"
echo "   👑 Owner Device: $OWNER_DEVICE"
echo "   👤 Staff Device: $STAFF_DEVICE"
echo ""

# Start running on both devices
echo -e "${BLUE}Step 2: Launching app on both devices...${NC}"
echo ""

# Create log directory
mkdir -p logs

# Device 1
echo "Starting on Device 1 ($OWNER_DEVICE)..."
osascript -e 'tell app "Terminal" to do script "cd \"'$(pwd)'\" && flutter run -d '$DEVICE1' 2>&1 | tee logs/device1.log"'

sleep 3

# Device 2
echo "Starting on Device 2 ($STAFF_DEVICE)..."
osascript -e 'tell app "Terminal" to do script "cd \"'$(pwd)'\" && flutter run -d '$DEVICE2' 2>&1 | tee logs/device2.log"'

echo ""
echo -e "${GREEN}✅ Apps are launching!${NC}"
echo ""
echo "=================================================="
echo "📱 TESTING INSTRUCTIONS"
echo "=================================================="
echo ""
echo -e "${YELLOW}On $OWNER_DEVICE (Owner):${NC}"
echo "   1. Login with Google (Owner account)"
echo "   2. Go to Inventory page"
echo "   3. Click '+ Add Product'"
echo "   4. Fill in:"
echo "      - Name: Test Laptop"
echo "      - SKU: LAP001"
echo "      - Price: 999.99"
echo "      - Initial Qty: 10"
echo "   5. Click 'Add Product'"
echo ""
echo -e "${YELLOW}On $STAFF_DEVICE (Staff):${NC}"
echo "   1. Login with Staff PIN"
echo "   2. Go to Inventory page"
echo "   3. 👀 WATCH FOR NEW PRODUCT TO APPEAR"
echo ""
echo -e "${GREEN}✅ Expected: Product appears within 1-2 seconds!${NC}"
echo ""
echo "=================================================="
echo "🧪 Additional Tests (see DUAL_EMULATOR_TEST.md)"
echo "=================================================="
echo "- Owner adjusts stock → Staff sees update"
echo "- Staff processes sale → Owner sees decrease"
echo "- Owner edits product → Staff sees changes"
echo "- Owner deletes product → Staff sees removal"
echo ""
echo "Logs are being saved to:"
echo "   - logs/device1.log"
echo "   - logs/device2.log"
echo ""
echo "Press Ctrl+C in each terminal to stop"
echo ""

