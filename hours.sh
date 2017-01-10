#!/bin/bash

die() {
  echo "$@" >&2
  exit 1
}

CONFIG_FILE="$HOME/.worklog"
test -f "$CONFIG_FILE" || die "no config file found at $CONFIG_FILE"



