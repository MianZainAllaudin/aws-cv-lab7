#!/bin/bash
set -euxo pipefail
# 1. Install Nginx and verify AWS CLI
dnf install -y nginx
if ! aws --version >/dev/null 2>&1; then
    dnf install -y awscli-2 || dnf install -y awscli
fi
# 2. Clean out default Nginx welcome configurations that block CV
rm -f /etc/nginx/conf.d/welcome.conf
mv /usr/share/nginx/html /usr/share/nginx/html.bak || true
# 3. Ensure permissions and create the link bridge to folder
install -d -m 755 /var/www/html
chmod 755 /var /var/www
ln -s /var/www/html /usr/share/nginx/html
chcon -Rt httpd_sys_content_t /var/www/html || true
# 4. Start Nginx
systemctl enable --now nginx
# 5. Create the global configuration file
cat >/etc/cv-site.conf <<'EOF'
export BUCKET_NAME="cv-23l-3036"
export AWS_DEFAULT_REGION="ap-southeast-2"
EOF
chmod 600 /etc/cv-site.conf
# 6. Create the synchronization script
cat >/usr/local/bin/cv-sync-cv.sh <<'SYNC_EOF'
#!/bin/bash
set -u
source /etc/cv-site.conf
LOG=/var/log/cv-sync.log

TOKEN=$(curl -fsS -X PUT "http://169.254.169" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600") || {
  echo "$(date -Is) status=failed reason=metadata-token" >> "$LOG"; exit 1;
}

INSTANCE_ID=$(curl -fsS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169) || {
  echo "$(date -Is) status=failed reason=instance-id" >> "$LOG"; exit 1;
}

if aws s3 sync "s3://${BUCKET_NAME}/site/" /var/www/html/ --only-show-errors; then
  if [ -f /var/www/html/index.html ]; then
    sed -i "s|{{HOSTED_ON}}|EC2 ${INSTANCE_ID}|g" /var/www/html/index.html
  fi
  echo "$(date -Is) status=success instance=${INSTANCE_ID}" >> "$LOG"
  exit 0
fi

echo "$(date -Is) status=failed instance=${INSTANCE_ID}" >> "$LOG"
exit 1
SYNC_EOF
chmod 755 /usr/local/bin/cv-sync-cv.sh

# 7. Create Systemd Service Unit
cat >/etc/systemd/system/cv-sync.service <<'SERVICE_EOF'
[Unit]
Description=Synchronize private S3 CV files to Nginx web root
After=network-online.target nginx.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/cv-sync-cv.sh
SERVICE_EOF

# 8. Create Systemd Timer Unit (Runs every 5 minutes)
cat >/etc/systemd/system/cv-sync.timer <<'TIMER_EOF'
[Unit]
Description=Run CV S3 sync every five minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
AccuracySec=30s
Unit=cv-sync.service

[Install]
WantedBy=timers.target
TIMER_EOF

# 9. Reload and activate the automated sync job
systemctl daemon-reload
systemctl enable --now cv-sync.timer

# Execute immediately so content serves on day zero
systemctl start cv-sync.service || true
