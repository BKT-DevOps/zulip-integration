#!/bin/bash
set -e

SENT_COUNT=0
ANSWER_MSG_IDS=""
CATEGORIES="AWS Linux Docker"

# Read today's quiz info from today.json
if [ ! -f "today.json" ]; then
    echo "::error::today.json not found. Was send-daily-quiz run today?"
    exit 1
fi

if [ ! -f "answers.json" ]; then
    echo "::error::answers.json not found."
    exit 1
fi

TODAY_DATE=$(date -u +"%Y-%m-%d")
FILE_DATE=$(jq -r '.date' today.json)

if [ "$FILE_DATE" != "$TODAY_DATE" ]; then
    echo "::warning::today.json date ($FILE_DATE) does not match today ($TODAY_DATE). Answers may be stale."
    exit 1
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

    # Look for answer in answers.json
    ANSWER_CONTENT=$(jq -r ".${CATEGORY}.\"${BASE_NAME}\" // empty" answers.json)

    if [ -z "$ANSWER_CONTENT" ]; then
        echo "No answer found for $CATEGORY ($BASE_NAME) in answers.json, skipping"
        continue
    fi

    echo "Found answer for $CATEGORY ($BASE_NAME)"

    # Send answer to Zulip
    CONTENT="**${CATEGORY} Quiz Answer**

${ANSWER_CONTENT}"

    echo "Sending $CATEGORY answer..."

    ZULIP_RESPONSE=$(curl -s -X POST "${ZULIP_SITE}/api/v1/messages" \
        -u "${ZULIP_BOT_EMAIL}:${ZULIP_API_KEY}" \
        -d "type=stream" \
        -d "to=553174" \
        -d "topic=Daily Quiz - ${CATEGORY}" \
        --data-urlencode "content=${CONTENT}")

    RESULT=$(echo "$ZULIP_RESPONSE" | jq -r '.result // empty')
    MSG_ID=$(echo "$ZULIP_RESPONSE" | jq -r '.id // empty')

    if [ "$RESULT" = "success" ]; then
        echo "$CATEGORY answer sent successfully. Message ID: $MSG_ID"
        SENT_COUNT=$((SENT_COUNT + 1))
        if [ -n "$MSG_ID" ] && [ "$MSG_ID" != "null" ]; then
            ANSWER_MSG_IDS="${ANSWER_MSG_IDS}${ANSWER_MSG_IDS:+,}${MSG_ID}"
        fi
    else
        echo "::error::Failed to send $CATEGORY answer: $ZULIP_RESPONSE"
    fi

    sleep 1
done

echo ""
echo "=== Summary ==="
echo "Answers sent: $SENT_COUNT"

# Save answer message IDs to message_ids.json for cleanup
if [ -n "$ANSWER_MSG_IDS" ]; then
    DATE=$(date -u +"%Y-%m-%d")

    if [ -f "message_ids.json" ] && [ -s "message_ids.json" ]; then
        jq --arg date "$DATE" --arg ids "$ANSWER_MSG_IDS" \
          '. + [{date: $date, message_ids: ($ids | split(",") | map(select(. != "")))}]' \
          message_ids.json > tmp.json && mv tmp.json message_ids.json
    else
        jq -n --arg date "$DATE" --arg ids "$ANSWER_MSG_IDS" \
          '[{date: $date, message_ids: ($ids | split(",") | map(select(. != "")))}]' \
          > message_ids.json
    fi

    echo "Saved answer message IDs to message_ids.json"
fi
