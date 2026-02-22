#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
APP_NAME="${APP_NAME:-kanaa-price-prediction}"
ROLE_NAME="${ROLE_NAME:-${APP_NAME}-lambda-role}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

check_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing command: $1"
    exit 1
  fi
}

check_cmd aws
check_cmd docker

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}:${IMAGE_TAG}"

ensure_role() {
  if aws iam get-role --role-name "${ROLE_NAME}" >/dev/null 2>&1; then
    echo "IAM role exists: ${ROLE_NAME}"
  else
    cat > /tmp/trust-policy-"${APP_NAME}".json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "lambda.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
    aws iam create-role \
      --role-name "${ROLE_NAME}" \
      --assume-role-policy-document "file:///tmp/trust-policy-${APP_NAME}.json"
    aws iam attach-role-policy \
      --role-name "${ROLE_NAME}" \
      --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
    echo "Created IAM role: ${ROLE_NAME}"
  fi
}

build_image() {
  docker buildx build --platform linux/amd64 -t "${APP_NAME}:${IMAGE_TAG}" -f Dockerfile.lambda .
}

push_image() {
  aws ecr describe-repositories --repository-names "${APP_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1 || \
    aws ecr create-repository --repository-name "${APP_NAME}" --region "${AWS_REGION}" >/dev/null

  aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
  docker tag "${APP_NAME}:${IMAGE_TAG}" "${IMAGE_URI}"
  docker push "${IMAGE_URI}"
}

upsert_lambda() {
  ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
  if aws lambda get-function --function-name "${APP_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    aws lambda update-function-code \
      --function-name "${APP_NAME}" \
      --image-uri "${IMAGE_URI}" \
      --region "${AWS_REGION}" >/dev/null
  else
    aws lambda create-function \
      --function-name "${APP_NAME}" \
      --package-type Image \
      --code "ImageUri=${IMAGE_URI}" \
      --role "${ROLE_ARN}" \
      --timeout 30 \
      --memory-size 1024 \
      --architectures x86_64 \
      --region "${AWS_REGION}" >/dev/null
  fi

  aws lambda update-function-configuration \
    --function-name "${APP_NAME}" \
    --environment "Variables={AWS_LWA_PORT=8080,AWS_LWA_READINESS_CHECK_PATH=/health,OMP_NUM_THREADS=1,OPENBLAS_NUM_THREADS=1,MKL_NUM_THREADS=1}" \
    --region "${AWS_REGION}" >/dev/null

  aws lambda put-function-concurrency \
    --function-name "${APP_NAME}" \
    --reserved-concurrent-executions 2 \
    --region "${AWS_REGION}" >/dev/null
}

ensure_function_url() {
  if aws lambda get-function-url-config --function-name "${APP_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    echo "Function URL already exists."
  else
    aws lambda create-function-url-config \
      --function-name "${APP_NAME}" \
      --auth-type NONE \
      --cors "AllowOrigins=*,AllowMethods=GET,POST,AllowHeaders=*" \
      --region "${AWS_REGION}" >/dev/null

    aws lambda add-permission \
      --function-name "${APP_NAME}" \
      --statement-id FunctionURLAllowPublicAccess \
      --action lambda:InvokeFunctionUrl \
      --principal "*" \
      --function-url-auth-type NONE \
      --region "${AWS_REGION}" >/dev/null
  fi

  aws lambda get-function-url-config \
    --function-name "${APP_NAME}" \
    --region "${AWS_REGION}" \
    --query FunctionUrl \
    --output text
}

set_log_retention() {
  aws logs put-retention-policy \
    --log-group-name "/aws/lambda/${APP_NAME}" \
    --retention-in-days 3 \
    --region "${AWS_REGION}" >/dev/null || true
}

action="${1:-all}"

case "${action}" in
  build)
    build_image
    ;;
  push)
    build_image
    push_image
    ;;
  deploy)
    ensure_role
    build_image
    push_image
    upsert_lambda
    set_log_retention
    ensure_function_url
    ;;
  all)
    ensure_role
    build_image
    push_image
    upsert_lambda
    set_log_retention
    ensure_function_url
    ;;
  *)
    echo "Usage: $0 [build|push|deploy|all]"
    exit 1
    ;;
esac
