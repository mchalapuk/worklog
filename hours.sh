#!/bin/bash

#set -x

die() {
  echo "$@" >&2
  exit 1
}

CONFIG_FILE="$HOME/.worklog"
test -f "$CONFIG_FILE" || \
  die "no config file found; run \`touch $CONFIG_FILE\` to correct this"

. "$CONFIG_FILE"
test "$DATA_DIR" != "" || \
  die "DATA_DIR variable not defined; please add it to $CONFIG_FILE"

test -d "$DATA_DIR" || \
  die "DATA_DIR=$DATA_DIR is not a directory; run \`mkdir -p $DATA_DIR\` to correct it"

DATE=`date +%Y-%m-%d`
TIME=`date +%H:%M`

YEAR=`date +%Y`
MONTH=`date +%m`
DAY=`date +%d`
HOUR=`date +%H`
MINUTE=`date +%M`

YEAR_DIR="$DATA_DIR/$YEAR"
mkdir -p "$YEAR_DIR"

MONTH_FILE="$YEAR_DIR/$MONTH.log"
test -f "$MONTH_FILE" || touch "$MONTH_FILE"

PRG=$0

usage() {
  echo "Usage: $PRG command (arguments...)"
  echo ""
  echo "  Commands:"
}

CMD=$1
shift

print_total() {
  awk '{
    split($2, from, ":");
    split($3, to, ":");
    total += (to[1]*60 + to[2]) - (from[1]*60 + from[2]);
  }
  END {
    printf "%d:%d\n", total/60, total%60
  }'
}

case "$CMD" in
  today)
    egrep "$DATE [0-9]{2}:[0-9]{2} [0-9]{2}:[0-9]{2}" "$MONTH_FILE" | print_total
    ;;
  *)
    echo "unknown command: $CMD" >&2
    echo "" >&2
    usage >&2
    exit 1
    ;;
esac

