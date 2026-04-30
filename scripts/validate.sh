#!/bin/bash

echo "Waiting for application to become healthy..."

for i in {1..30}
do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/actuator/health || true)

  if [ "$HTTP_CODE" = "200" ]; then
    echo "Application is healthy"
    exit 0
  fi

  echo "Attempt $i: app not ready (HTTP $HTTP_CODE)"
  sleep 5
done

echo "Application failed to become healthy"
exit 1
