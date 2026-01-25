#!/bin/bash
set -e

SENT_COUNT=0
CATEGORIES="AWS Linux Docker"

for CATEGORY in $CATEGORIES; do
    echo "=== Processing $CATEGORY ==="

    # Find today's image in 03-sent (moved there this morning)
    IMAGE=$(find "03-sent/$CATEGORY" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) -mtime 0 2>/dev/null | head -n 1)

    if [ -z "$IMAGE" ]; then
        # Fallback: get the most recent image
        IMAGE=$(find "03-sent/$CATEGORY" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) 2>/dev/null | xargs ls -t 2>/dev/null | head -n 1)
    fi

    if [ -z "$IMAGE" ]; then
        echo "No image found for $CATEGORY, skipping"
        continue
    fi

    IMAGE_NAME=$(basename "$IMAGE")
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
