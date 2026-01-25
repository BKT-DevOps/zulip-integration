#!/bin/bash
set -e

if [ ! -f "message_ids.json" ]; then
    echo "No message_ids.json found. Nothing to clean up."
    exit 0
fi

# Calculate date 7 days ago (works on both Linux and macOS)
CUTOFF_DATE=$(date -u -d "7 days ago" +"%Y-%m-%d" 2>/dev/null || date -u -v-7d +"%Y-%m-%d")
echo "Cleaning up messages older than: $CUTOFF_DATE"

DELETED_COUNT=0
FAILED_COUNT=0

# Process each entry in the JSON file
ENTRIES=$(jq -c '.[]' message_ids.json)

while IFS= read -r entry; do
    MSG_DATE=$(echo "$entry" | jq -r '.date')

    # Check if this entry is older than cutoff
    if [[ "$MSG_DATE" < "$CUTOFF_DATE" ]]; then
        echo "Processing messages from $MSG_DATE"

        # Get message IDs for this date
        MSG_IDS=$(echo "$entry" | jq -r '.message_ids[]')

        for MSG_ID in $MSG_IDS; do
            if [ -n "$MSG_ID" ] && [ "$MSG_ID" != "null" ]; then
                echo "Deleting message ID: $MSG_ID"

                RESPONSE=$(curl -s -X DELETE "${ZULIP_SITE}/api/v1/messages/${MSG_ID}" \
                    -u "${ZULIP_BOT_EMAIL}:${ZULIP_API_KEY}")

                RESULT=$(echo "$RESPONSE" | jq -r '.result // empty')

                if [ "$RESULT" = "success" ]; then
                    echo "Successfully deleted message $MSG_ID"
                    DELETED_COUNT=$((DELETED_COUNT + 1))
                else
                    echo "::warning::Failed to delete message $MSG_ID: $RESPONSE"
                    FAILED_COUNT=$((FAILED_COUNT + 1))
                fi

                # Rate limiting
                sleep 0.5
            fi
        done
    fi
done <<< "$ENTRIES"

echo ""
echo "=== Cleanup Summary ==="
echo "Messages deleted: $DELETED_COUNT"
echo "Failed deletions: $FAILED_COUNT"

# Remove old entries from message_ids.json
jq --arg cutoff "$CUTOFF_DATE" '[.[] | select(.date >= $cutoff)]' message_ids.json > tmp.json
mv tmp.json message_ids.json

echo "Updated message_ids.json - kept entries from $CUTOFF_DATE onwards"
