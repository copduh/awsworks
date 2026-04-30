#!/bin/bash
set -e
pkill -f 'java -jar app.jar' || true
