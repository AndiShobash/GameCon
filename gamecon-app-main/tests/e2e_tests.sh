#!/bin/sh

BASE_URL="http://10.0.0.96" 
PASS=true

GAME_TITLE="Max Payne 2"

echo "====================================="
echo "Starting E2E Tests for GameCon"
echo "====================================="

# First, check if the application is healthy
echo "Checking application health..."
HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/health)
if [ "$HEALTH_RESPONSE" != "200" ]; then
  echo "Health check failed - application may not be running"
  echo "Health response: $HEALTH_RESPONSE"
  PASS=false
else
  echo "Application is healthy"
fi

echo "Creating a new game..."
CREATE_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST $BASE_URL/games/new \
  -F "title=$GAME_TITLE" \
  -F "genre=Action" \
  -F "platform=PC" \
  -F "image_url=https://upload.wikimedia.org/wikipedia/en/2/21/Max_Payne_2.jpg")

echo "Create response: $CREATE_RESPONSE"
if [ "$CREATE_RESPONSE" != "302" ]; then
  echo "Create failed - expected 302 redirect"
  PASS=false
else
  echo "Game created successfully"
fi

echo "Fetching all games (should include new one)..."
if curl -s $BASE_URL/ | grep "$GAME_TITLE" >/dev/null; then
  echo "Found $GAME_TITLE on home page"
else
  echo "$GAME_TITLE not found on home page"
  PASS=false
fi

echo "Getting the ID of the newly created game..."
GAME_ID=$(curl -s $BASE_URL/ | grep -oE '/games/[0-9]+' | grep -oE '[0-9]+' | sort -n | tail -1)
echo "New game ID: $GAME_ID"
if [ -z "$GAME_ID" ]; then
  echo "Failed to get game ID"
  PASS=false
fi

if [ -n "$GAME_ID" ]; then
  echo "Fetching game details..."
  DETAIL_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/games/$GAME_ID)
  if [ "$DETAIL_RESPONSE" = "200" ]; then
    echo "Game details fetched successfully"
  else
    echo "Failed to fetch game details - got $DETAIL_RESPONSE"
    PASS=false
  fi

  echo "Editing the game..."
  EDIT_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST $BASE_URL/games/$GAME_ID/edit \
    -F "title=Updated $GAME_TITLE" \
    -F "genre=Action" \
    -F "platform=Switch")

  echo "Edit response: $EDIT_RESPONSE"
  if [ "$EDIT_RESPONSE" != "302" ]; then
    echo "Edit failed - expected 302 redirect"
    PASS=false
  else
    echo "Game edited successfully"
  fi

  echo "Confirming edit..."
  if curl -s $BASE_URL/games/$GAME_ID | grep "Updated $GAME_TITLE" >/dev/null; then
    echo "Update confirmed"
  else
    echo "Update not reflected in game details"
    PASS=false
  fi

  echo "Deleting the game..."
  DELETE_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST $BASE_URL/games/$GAME_ID/delete)

  echo "Delete response: $DELETE_RESPONSE"
  if [ "$DELETE_RESPONSE" != "302" ]; then
    echo "Delete failed - expected 302 redirect"
    PASS=false
  else
    echo "Game deleted successfully"
  fi

  echo "Confirming deletion..."
  FINAL_CHECK=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/games/$GAME_ID)
  if [ "$FINAL_CHECK" = "404" ]; then
    echo "Deletion confirmed - game no longer exists"
  else
    echo "Deletion failed - game still accessible with status $FINAL_CHECK"
    PASS=false
  fi
fi

echo "====================================="
if [ "$PASS" = true ]; then
  echo "All tests passed!"
  exit 0
else
  echo "Some tests failed!"
  exit 1
fi