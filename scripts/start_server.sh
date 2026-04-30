#!/bin/bash
set -e

cd /opt/sprintly

echo "Loading env file..."
if [ ! -f sprintly.env ]; then
  echo "ERROR: sprintly.env missing"
  exit 1
fi

set -a
source sprintly.env
set +a

echo "Verifying critical env..."
echo "SPRING_DATASOURCE_URL=$SPRING_DATASOURCE_URL"

if [ -z "$SPRING_DATASOURCE_URL" ]; then
  echo "ERROR: SPRING_DATASOURCE_URL is empty"
  exit 1
fi

echo "Fetching secrets from AWS..."

if [ -n "$SPRING_DATASOURCE_PASSWORD_SECRET_NAME" ]; then
  export SPRING_DATASOURCE_PASSWORD=$(aws secretsmanager get-secret-value \
    --secret-id "$SPRING_DATASOURCE_PASSWORD_SECRET_NAME" \
    --query SecretString \
    --output text \
    --region "$AWS_REGION")
fi

if [ -n "$JWT_SECRET_NAME" ]; then
  export JWT_SECRET=$(aws secretsmanager get-secret-value \
    --secret-id "$JWT_SECRET_NAME" \
    --query SecretString \
    --output text \
    --region "$AWS_REGION")
fi

echo "Starting application..."

nohup java -jar app.jar > /opt/sprintly/app.log 2>&1 &
