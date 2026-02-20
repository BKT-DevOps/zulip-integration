#!/bin/bash
set -e

SENT_COUNT=0
CATEGORIES="AWS Linux Docker"

# Read today's quiz info from today.json
if [ ! -f "today.json" ]; then
    echo "::error::today.json not found. Was send-daily-quiz run today?"
    exit 1
fi

TODAY_DATE=$(date -u +"%Y-%m-%d")
FILE_DATE=$(jq -r '.date' today.json)

if [ "$FILE_DATE" != "$TODAY_DATE" ]; then
    echo "::warning::today.json date ($FILE_DATE) does not match today ($TODAY_DATE). Answers may be stale."
fi

for CATEGORY in $CATEGORIES; do
    echo "=== Processing $CATEGORY ==="

    # Get today's image name from today.json
    IMAGE_NAME=$(jq -r ".quizzes.${CATEGORY} // empty" today.json)

    if [ -z "$IMAGE_NAME" ]; then
        echo "No image recorded for $CATEGORY in today.json, skipping"
        continue
    fi

    BASE_NAME="${IMAGE_NAME%.*}"

    # Look for answer file
    ANSWER_CONTENT=""
    for ext in txt md; do
        ANSWER_FILE="03-sent/$CATEGORY/${BASE_NAME}.${ext}"
        if [ -f "$ANSWER_FILE" ]; then
            ANSWER_CONTENT=$(cat "$ANSWER_FILE")
            echo "Found answer file: $ANSWER_FILE"
            break
        fi
    done

    if [ -z "$ANSWER_CONTENT" ]; then
        echo "No answer file found for $CATEGORY ($BASE_NAME), skipping"
        continue
    fi

    # Send answer to Zulip
    CONTENT="**${CATEGORY} Quiz Answer**

${ANSWER_CONTENT}"

    echo "Sending $CATEGORY answer..."

    RESPONSE=$(curl -s -X POST "${ZULIP_SITE}/api/v1/messages" \
        -u "${ZULIP_BOT_EMAIL}:${ZULIP_API_KEY}" \
        -d "type=stream" \
        -d "to=553174" \
        -d "topic=Daily Quiz - ${CATEGORY}" \
        --data-urlencode "content=${CONTENT}")

    RESULT=$(echo "$RESPONSE" | jq -r '.result // empty')

    if [ "$RESULT" = "success" ]; then
        echo "$CATEGORY answer sent successfully"
        SENT_COUNT=$((SENT_COUNT + 1))
    else
        echo "::error::Failed to send $CATEGORY answer: $RESPONSE"
    fi

    sleep 1
done

echo ""
echo "=== Summary ==="
echo "Answers sent: $SENT_COUNT"
