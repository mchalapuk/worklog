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
  if [ $1 -lt 0 ]
  then
    TS=`echo $1 | cut -d"-" -f2`
    PREFIX="-"
  else
    TS=$1
    PREFIX=" "
  fi

  DAYS=$[`date --utc -d @$TS +%j`-1]
  HOURS=$[`date --utc -d @$TS +%_H`+$[DAYS*24]]
  if [ $HOURS -lt 10 ]
  then
    HOURS="0$HOURS"
  fi
  MINUTES=`date --utc -d @$TS +%M`
  echo "$PREFIX$HOURS:$MINUTES"
}

diff() {
  RETVAL=$[$1 - $2]
  echo $RETVAL
}

workseconds_from_calendar_days() {
  echo $[$1*8*60*60]
}

case "$CMD" in
  day) ;&
  today)
    echo " date         work-hours   over-time"
    echo "------------+------------+-----------"
    WORK=`egrep "$DATE .*:.* .*:.*" "$MONTH_FILE" | total`
    LAST_IN=`tail -n1 "$MONTH_FILE" | egrep "$DATE +[0-9]+:[0-9]+"`
    if [ -n LAST_IN ]
    then
      UNTIL_CURRENT_TIME=`echo "$LAST_IN $TIME" | total`
      WORK=$[$WORK + $UNTIL_CURRENT_TIME]
    fi
    DIFF=`diff $WORK $(workseconds_from_calendar_days 1)`
    echo " $DATE       `pretty_print $WORK`      `pretty_print $DIFF`"
    ;;
  month)
    echo "------------+------------+-----------"
    echo " date         work-hours   over-time"
    echo "------------+------------+-----------"

    DAY_COUNT=0
    TOTAL=0
    for DAY in `cut -d" " -f1 $MONTH_FILE | sort | uniq`
    do
      WORK=`egrep "$DAY .*:.* .*:.*" "$MONTH_FILE" | total`
      if [ $DAY == $DATE ]
      then
        LAST_IN=`tail -n1 "$MONTH_FILE" | egrep "$DAY +[0-9]+:.[0-9]+"`
        if [ -n LAST_IN ]
        then
          UNTIL_CURRENT_TIME=`echo "$LAST_IN $TIME" | total`
          WORK=$[$WORK + $UNTIL_CURRENT_TIME]
        fi
      fi

      DIFF=`diff $WORK $(workseconds_from_calendar_days 1)`
      echo " $DAY       `pretty_print $WORK`      `pretty_print $DIFF`"

      DAY_COUNT=$[$DAY_COUNT+1]
      TOTAL=$[$TOTAL + $WORK]
    done

    EXPECTED=$(workseconds_from_calendar_days $DAY_COUNT)
    DIFF=`diff $TOTAL $EXPECTED`

    echo "------------+------------+-----------"
    echo " TOTAL            `pretty_print $TOTAL`      `pretty_print $DIFF`"
    echo "------------+------------+-----------"
    ;;
  *)
    echo "unknown command: $CMD" >&2
    echo "" >&2
    usage >&2
    exit 1
    ;;
esac

