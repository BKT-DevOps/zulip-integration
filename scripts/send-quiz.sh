#!/bin/bash
set -e

# Send quiz for a specific category
send_quiz() {
    local CATEGORY="$1"
    local IMAGE_NAME="$2"

    if [ -z "$IMAGE_NAME" ]; then
        echo "No image for $CATEGORY, skipping"
        return
    fi

    IMAGE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/03-sent/${CATEGORY}/${IMAGE_NAME}"
    CONTENT="**${CATEGORY} Daily Quiz**

![${IMAGE_NAME}](${IMAGE_URL})"

    echo "Sending $CATEGORY quiz: $IMAGE_NAME"

    RESPONSE=$(curl -s -X POST "${ZULIP_SITE}/api/v1/messages" \
        -u "${ZULIP_BOT_EMAIL}:${ZULIP_API_KEY}" \
        -d "type=stream" \
        -d "to=553174" \
        -d "topic=Daily Quiz - ${CATEGORY}" \
        --data-urlencode "content=${CONTENT}")

    MSG_ID=$(echo "$RESPONSE" | jq -r '.id // empty')
    RESULT=$(echo "$RESPONSE" | jq -r '.result // empty')

    if [ "$RESULT" = "success" ] && [ -n "$MSG_ID" ]; then
        echo "$CATEGORY quiz sent. Message ID: $MSG_ID"
        echo "$MSG_ID" >> /tmp/message_ids.txt
        echo "1" >> /tmp/sent_count.txt

        # Send a /poll message for A/B/C/D voting
        POLL_CONTENT="/poll 🧠 Quiz Zamanı!
A
B
C
D"
        POLL_RESPONSE=$(curl -s -X POST "${ZULIP_SITE}/api/v1/messages" \
            -u "${ZULIP_BOT_EMAIL}:${ZULIP_API_KEY}" \
            -d "type=stream" \
            -d "to=553174" \
            -d "topic=Daily Quiz - ${CATEGORY}" \
            --data-urlencode "content=${POLL_CONTENT}" || true)

        POLL_RESULT=$(echo "$POLL_RESPONSE" | jq -r '.result // empty')
        if [ "$POLL_RESULT" = "success" ]; then
            POLL_MSG_ID=$(echo "$POLL_RESPONSE" | jq -r '.id // empty')
            echo "Poll sent for $CATEGORY. Message ID: $POLL_MSG_ID"
            [ -n "$POLL_MSG_ID" ] && echo "$POLL_MSG_ID" >> /tmp/message_ids.txt
        else
            echo "::warning::Failed to send poll for $CATEGORY: $POLL_RESPONSE"
        fi
    else
        echo "::error::Failed to send $CATEGORY quiz: $RESPONSE"
    fi

    sleep 1
}

# Initialize temp files
rm -f /tmp/message_ids.txt /tmp/sent_count.txt
touch /tmp/message_ids.txt /tmp/sent_count.txt

# Send each category
send_quiz "AWS" "$AWS_IMAGE"
send_quiz "Linux" "$LINUX_IMAGE"
send_quiz "Docker" "$DOCKER_IMAGE"

# Collect results
MESSAGE_IDS=$(cat /tmp/message_ids.txt | tr '\n' ',' | sed 's/,$//')
SENT_COUNT=$(wc -l < /tmp/sent_count.txt | tr -d ' ')

echo "message_ids=$MESSAGE_IDS" >> $GITHUB_OUTPUT
echo "sent_count=$SENT_COUNT" >> $GITHUB_OUTPUT
echo "Summary: Sent $SENT_COUNT quizzes"
