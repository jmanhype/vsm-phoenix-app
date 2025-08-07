#!/bin/bash

# End-to-end test for Telegram-LLM integration
# Tests the complete flow from Telegram message to LLM response

set -e

TELEGRAM_API="https://api.telegram.org/bot7747520054:AAFNts5iJn8mYZezAG9uQF2_slvuztEScZI"
CHAT_ID="643905554"  # Your chat ID from earlier tests

echo "🧪 Starting E2E Telegram-LLM Test"
echo "================================"

# 1. Check bot status
echo "1️⃣ Checking bot status..."
BOT_INFO=$(curl -s "${TELEGRAM_API}/getMe")
if [[ $(echo "$BOT_INFO" | jq -r '.ok') == "true" ]]; then
    BOT_USERNAME=$(echo "$BOT_INFO" | jq -r '.result.username')
    echo "✅ Bot connected: @${BOT_USERNAME}"
else
    echo "❌ Bot connection failed"
    exit 1
fi

# 2. Send test message
echo ""
echo "2️⃣ Sending test message..."
MESSAGE="Testing VSM system at $(date)"
SEND_RESULT=$(curl -s -X POST "${TELEGRAM_API}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"${CHAT_ID}\",\"text\":\"${MESSAGE}\"}")

if [[ $(echo "$SEND_RESULT" | jq -r '.ok') == "true" ]]; then
    MESSAGE_ID=$(echo "$SEND_RESULT" | jq -r '.result.message_id')
    echo "✅ Message sent (ID: ${MESSAGE_ID})"
else
    echo "❌ Failed to send message"
    echo "$SEND_RESULT" | jq
    exit 1
fi

# 3. Monitor logs for processing
echo ""
echo "3️⃣ Monitoring logs for message processing..."
echo "Waiting for LLM processing..."

# Start monitoring logs in background
tail -f logs/vsm_phoenix.log | grep -E "(Processing message from|Published LLM request|LLM Worker received|Received LLM response|Sent message to chat)" &
TAIL_PID=$!

# Wait a bit
sleep 10

# Kill the tail process
kill $TAIL_PID 2>/dev/null || true

# 4. Check if bot responded
echo ""
echo "4️⃣ Checking for bot response..."
UPDATES=$(curl -s "${TELEGRAM_API}/getUpdates?offset=-10")
BOT_MESSAGES=$(echo "$UPDATES" | jq -r '.result[] | select(.message.from.is_bot == true) | .message.text' | tail -5)

if [[ -n "$BOT_MESSAGES" ]]; then
    echo "✅ Bot responses found:"
    echo "$BOT_MESSAGES"
else
    echo "⚠️  No bot responses found in recent updates"
fi

# 5. Check system status
echo ""
echo "5️⃣ Checking VSM system status..."
AGENTS=$(curl -s http://localhost:4000/api/vsm/agents)
LLM_WORKERS=$(echo "$AGENTS" | jq -r '.agents[] | select(.type == "llm_worker") | .id')
TELEGRAM_AGENTS=$(echo "$AGENTS" | jq -r '.agents[] | select(.type == "telegram") | .id')

echo "📊 Active agents:"
echo "- Telegram: ${TELEGRAM_AGENTS:-None}"
echo "- LLM Workers: ${LLM_WORKERS:-None}"

# 6. Summary
echo ""
echo "📋 Test Summary"
echo "=============="
echo "✅ Bot connected and accessible"
echo "✅ Message sent successfully"
if [[ -n "$LLM_WORKERS" ]]; then
    echo "✅ LLM workers running"
else
    echo "❌ No LLM workers found"
fi

echo ""
echo "💡 Check your Telegram chat for responses!"
echo "📱 Chat link: https://t.me/VaoAssitantBot"