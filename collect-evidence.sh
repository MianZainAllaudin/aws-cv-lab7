#!/usr/bin/env bash
set -u
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 BUCKET_NAME EC2_ADDRESS LAMBDA_URL" >&2
  exit 1
fi
BUCKET="$1"; EC2_ADDR="$2"; LAMBDA_URL="$3"
REGION="${AWS_DEFAULT_REGION:-$(aws configure get region 2>/dev/null || true)}"
EC2_ROLE="cv-ec2-role-23l-3036"
LAMBDA_ROLE="cv-lambda-role-23l-3036"
FUNCTION="cv-func-23l-3036"
OUT="evidence.txt"
: > "$OUT"
section() { printf '\n== %s ==\n' "$1" >> "$OUT"; }
run() {
  local label="$1"; shift
  section "$label"
  { "$@" 2>&1 || echo "COMMAND FAILED (exit $?)"; } >> "$OUT"
}
section caller
{ aws sts get-caller-identity 2>&1 || echo "COMMAND FAILED"; } >> "$OUT"
run public-access aws s3api get-public-access-block --bucket "$BUCKET"
run versioning aws s3api get-bucket-versioning --bucket "$BUCKET"
run objects aws s3 ls "s3://${BUCKET}/site/" --recursive
run ec2-policy aws iam get-role-policy --role-name "$EC2_ROLE" --policy-name cv-ec2-s3-read
section lambda-policy
{ aws iam list-attached-role-policies --role-name "$LAMBDA_ROLE" 2>&1 || echo "COMMAND FAILED"; } >> "$OUT"
{ aws iam get-role-policy --role-name "$LAMBDA_ROLE" --policy-name cv-lambda-s3-read 2>&1 || echo "COMMAND FAILED"; } >> "$OUT"
SG_ID="$(aws ec2 describe-instances --filters "Name=tag:Name,Values=cv-ec2-23l-3036" --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
run security-group aws ec2 describe-security-groups --group-ids "$SG_ID"
run instance aws ec2 describe-instances --filters "Name=tag:Name,Values=cv-ec2-23l-3036" --query 'Reservations[0].Instances[*].{Id:InstanceId,Type:InstanceType,State:State.Name,PublicIp:PublicIpAddress,MetadataOptions:MetadataOptions,Profile:IamInstanceProfile.Arn,Tags:Tags}' --output json
section endpoints
for address in "http://${EC2_ADDR}/" "${LAMBDA_URL%/}/" "https://${BUCKET}.s3.${REGION}.amazonaws.com/site/index.html"; do
  echo "--- $address" >> "$OUT"
  curl -sS -o /dev/null -w 'http_code=%{http_code} content_type=%{content_type}\n' "$address" >> "$OUT" 2>&1 || echo "curl failed" >> "$OUT"
done
run lambda-logs aws logs tail "/aws/lambda/${FUNCTION}" --since 1h
run log-retention aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/${FUNCTION}" --query 'logGroups[*].{name:logGroupName,retentionInDays:retentionInDays}' --output json
echo "DONE"
