#!/usr/bin/env bash

echo "=> Shutting down all local AI Stack services..."

pkill -f llama-server
pkill -f opencode

echo "=> Everything has been successfully terminated."
