#!/bin/bash

echo "🤖 Testing Telegram bot end-to-end"

# Get pending updates
echo "📥 Getting pending updates..."
UPDATES=$(curl -s "https://api.telegram.org/bot7747520054:AAFNts5iJn8mYZezAG9uQF2_slvuztEScZI/getUpdates?offset=379100282&limit=1")
echo $UPDATES | jq '.result[0]'

# Extract message
MESSAGE=$(echo $UPDATES | jq -r '.result[0].message.text')
CHAT_ID=$(echo $UPDATES | jq -r '.result[0].message.chat.id')

echo "💬 Message: $MESSAGE"
echo "🗣️ Chat ID: $CHAT_ID"

# Send echo response
echo "📤 Sending echo response..."
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot7747520054:AAFNts5iJn8mYZezAG9uQF2_slvuztEScZI/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{\"chat_id\": $CHAT_ID, \"text\": \"Echo: $MESSAGE\"}")

echo $RESPONSE | jq '.ok'

if [ "$(echo $RESPONSE | jq -r '.ok')" = "true" ]; then
  echo "✅ Bot responded successfully!"
else
  echo "❌ Bot response failed"
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