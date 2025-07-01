#!/bin/bash
if [ -z "$1" ]; then
  echo "Usage: $0 <linux / macos>"
  exit 1
fi


case "$1" in
  linux)
    echo "Starting Koreflow Community Edition for Linux..."
    ./koreflow.linux
    ;;
  macos)
    echo "Starting Koreflow  Edition for macOS..."
    ./koreflow.macos.arm
    ;;
  *)
    echo "Invalid argument. Use 'linux' or 'macos'."
    exit 1
    ;;
esac
