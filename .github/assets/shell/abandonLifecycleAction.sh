#!/bin/bash
set -eEx
echo "Signaling lifecycle ABANDON"
/var/aws-deployment/signalLifecycleAction.sh 1
