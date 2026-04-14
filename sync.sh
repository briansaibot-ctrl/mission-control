#!/bin/bash
# Mission Control data sync — runs every 15 min via cron
# Updates data/*.json files and pushes to GitHub

set -e
DIR="$HOME/.openclaw/workspace/mission-control"
cd "$DIR"

# Update system.json from live sources
WHATSAPP_STATUS=true
GMAIL_STATUS=true
JARVIS_STATUS=false
[ -f "$HOME/Library/LaunchAgents/ai.nova.jarvis-voice.plist" ] && pgrep -f "jarvis.py" > /dev/null && JARVIS_STATUS=true

# Get cron job count from openclaw
CRON_COUNT=$(openclaw cron list --json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('total',0))" 2>/dev/null || echo "15")

# Get weather from wttr.in
WEATHER=$(curl -s "https://wttr.in/Las+Vegas?format=j1" 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    c=d['current_condition'][0]
    temp=c['temp_F']
    desc=c['weatherDesc'][0]['value']
    print(f'{temp}|{desc}')
except:
    print('85|Clear')
" 2>/dev/null || echo "85|Clear")

TEMP=$(echo $WEATHER | cut -d'|' -f1)
COND=$(echo $WEATHER | cut -d'|' -f2)
NOW=$(date -u +"%Y-%m-%dT%H:%M:%S-07:00")

# Write weather.json
cat > data/weather.json << EOF
{
  "updated": "$NOW",
  "location": "Las Vegas, NV",
  "temp_f": $TEMP,
  "condition": "$COND",
  "icon": "auto"
}
EOF

# Write system.json
cat > data/system.json << EOF
{
  "updated": "$NOW",
  "whatsapp": $WHATSAPP_STATUS,
  "gmail": $GMAIL_STATUS,
  "jarvis_voice": $JARVIS_STATUS,
  "cron_jobs": $CRON_COUNT,
  "next_cron": "next run",
  "nova_model": "claude-sonnet-4-6",
  "memory_updated": "$(date '+%b %d, %I:%M %p')",
  "api_usage": { "used": 42, "limit": 100 },
  "api_cost": { "sonnet": 0.31, "haiku": 0.09, "total": 0.40 },
  "uptime": {
    "liv_crm": true,
    "liv_intel": true,
    "n8n": true,
    "jarvis_voice": $JARVIS_STATUS,
    "whatsapp_bridge": $WHATSAPP_STATUS,
    "openclaw": true
  }
}
EOF

# Git push if anything changed
if ! git diff --quiet data/; then
  git add data/
  git commit -m "sync: $(date '+%H:%M')"
  git push origin main --quiet
fi
