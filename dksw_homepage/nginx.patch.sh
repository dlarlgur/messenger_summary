#!/usr/bin/env bash
# DK Software homepage — nginx config patch
# Adds homepage upstream + rewrites `location /` on dksw4.com HTTPS block
# to proxy to aiapp_dksw_homepage:3100
#
# Run this on the SERVER (dksw@223.130.151.39).
set -euo pipefail

CONF="/home/dksw/aiapp/config/nginx/aiapp.conf"
# Fallback candidates in case the path differs
for candidate in \
  "/home/dksw/aiapp/config/nginx/aiapp.conf" \
  "/home/dksw/aiapp/nginx/aiapp.conf" \
  "/home/dksw/aiapp/nginx/conf.d/aiapp.conf"
do
  if [ -f "$candidate" ]; then CONF="$candidate"; break; fi
done

if [ ! -f "$CONF" ]; then
  echo "❌ Could not find aiapp.conf on host. Editing inside container instead."
  docker exec aiapp_nginx cp /etc/nginx/conf.d/aiapp.conf /etc/nginx/conf.d/aiapp.conf.bak.$(date +%s)
  docker exec aiapp_nginx sh -c "
    grep -q 'upstream dksw_homepage_backend' /etc/nginx/conf.d/aiapp.conf || \
    sed -i '1i upstream dksw_homepage_backend { server aiapp_dksw_homepage:3100; }\n' /etc/nginx/conf.d/aiapp.conf
  "
  # Replace the 'AI APP server running' root block
  docker exec aiapp_nginx sh -c '
    python3 - <<PY
import re
p="/etc/nginx/conf.d/aiapp.conf"
s=open(p).read()
new = """    # Root -> DK Software homepage
    location / {
        proxy_pass http://dksw_homepage_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 30s;
    }"""
s2 = re.sub(r"# Root\s*\n\s*location / \{\s*return 200 \"AI APP server running\\n\";\s*\}", new, s)
if s == s2:
    s2 = re.sub(r"location / \{\s*return 200 \"AI APP server running\\n\";\s*\}", new, s)
open(p,"w").write(s2)
print("patched" if s != s2 else "no-op")
PY
  '
  docker exec aiapp_nginx nginx -t
  docker exec aiapp_nginx nginx -s reload
  echo "✓ nginx reloaded (in-container edit)"
  exit 0
fi

echo "▶ Patching $CONF (backup -> .bak.$(date +%s))"
cp "$CONF" "$CONF.bak.$(date +%s)"

# 1) add upstream (idempotent)
if ! grep -q 'upstream dksw_homepage_backend' "$CONF"; then
  sed -i '1i upstream dksw_homepage_backend { server aiapp_dksw_homepage:3100; }\n' "$CONF"
fi

# 2) replace root location
python3 - <<PY
import re
p="$CONF"
s=open(p).read()
new = """    # Root -> DK Software homepage
    location / {
        proxy_pass http://dksw_homepage_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 30s;
    }"""
s2 = re.sub(r"# Root\s*\n\s*location / \{\s*return 200 \"AI APP server running\\n\";\s*\}", new, s)
if s == s2:
    s2 = re.sub(r"location / \{\s*return 200 \"AI APP server running\\n\";\s*\}", new, s)
open(p,"w").write(s2)
print("patched" if s != s2 else "no-op (already replaced)")
PY

echo "▶ Reloading nginx..."
docker exec aiapp_nginx nginx -t
docker exec aiapp_nginx nginx -s reload
echo "✓ Done."
