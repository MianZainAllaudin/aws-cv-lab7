#!/bin/bash
set -u
source /etc/cv-site.conf
LOG=/var/log/cv-sync.log
TOKEN=$(curl -fsS -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600") || {
  echo "$(date -Is) status=failed reason=metadata-token" >> "$LOG"; exit 1;
}
INSTANCE_ID=$(curl -fsS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id) || {
  echo "$(date -Is) status=failed reason=instance-id" >> "$LOG"; exit 1;
}
if aws s3 sync "s3://${BUCKET_NAME}/site/" /var/www/html/ --only-show-errors; then
  if sed -i "s|{{HOSTED_ON}}|EC2 ${INSTANCE_ID}|g" /var/www/html/index.html; then
    echo "$(date -Is) status=success instance=${INSTANCE_ID}" >> "$LOG"
    exit 0
  fi
fi
echo "$(date -Is) status=failed instance=${INSTANCE_ID}" >> "$LOG"
exit 1
