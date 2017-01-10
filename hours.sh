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

total() {
  awk '{
    split($2, from, ":");
    split($3, to, ":");
    total += (to[1]*60 + to[2]) - (from[1]*60 + from[2]);
  }
  END {
    printf "%d", total*60
  }'
}

pretty_print() {
  DAYS=$[`date --utc -d @$1 +%j`-1]
  HOURS=$[`date --utc -d @$1 +%_H`+$[DAYS*24]]
  if [ $HOURS -lt 10 ]
  then
    HOURS="0$HOURS"
  fi
  MINUTES=`date --utc -d @$1 +%M`
  echo $HOURS:$MINUTES
}

diff() {
  RETVAL=$[$1-$2]
  if [ $RETVAL -ge 0 ]
  then
    RETVAL="+$RETVAL"
  fi
  echo $RETVAL
}

case "$CMD" in
  today)
    WORK=`egrep "$DATE [0-9]{2}:[0-9]{2} [0-9]{2}:[0-9]{2}" "$MONTH_FILE" | total`
    pretty_print $WORK
    ;;
  month)
    echo "-----------+------"
    echo "date            wh"
    echo "-----------+------"

    DAY_COUNT=0
    for DAY in `cut -d" " -f1 $MONTH_FILE | sort | uniq`
    do
      WORK=`egrep "$DAY [0-9]{2}:[0-9]{2} [0-9]{2}:[0-9]{2}" "$MONTH_FILE" | total`
      DIFF=`diff $WORK 8`
      echo "$DAY   `pretty_print $WORK` `pretty_print $DIFF`"
      DAY_COUNT=$[$DAY_COUNT+1]
    done

    TOTAL=`cat $MONTH_FILE | total`
    DIFF=`diff $TOTAL $[$DAY_COUNT*8]`
    echo "-----------+------"
    echo "TOTAL        `pretty_print $TOTAL` `pretty_print $DIFF`"
    echo "-----------+------"
    ;;
  *)
    echo "unknown command: $CMD" >&2
    echo "" >&2
    usage >&2
    exit 1
    ;;
esac

