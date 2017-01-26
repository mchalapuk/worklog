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
UNIXTIME=`date +%s`

YEAR_DIR="$DATA_DIR/$YEAR"
mkdir -p "$YEAR_DIR"

MONTH_FILE="$YEAR_DIR/$MONTH.worklog"
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
  FIX_THE_LOGS="please fix the log files"
  RETVAL=0

  IN=""
  while read -r _DAY _HOUR _ACTION
  do
    TIMESTAMP=$(date -d "$_DAY $_HOUR:00 `date +%Z`" +%s)
    case "$_ACTION" in

      'IN')
        if [ "$IN" != "" ]
        then
          printf "detected two IN actions in a row; %s\n", $FIX_THE_LOGS >&2
          exit 1
        fi
        IN=$TIMESTAMP
        ;;

      'OUT')
        OUT=$TIMESTAMP
        if [ $OUT -lt $IN ]
        then
          printf "OUT action's timestamp before corresponding IN action; %s\n",
            $FIX_THE_LOGS >&2
        fi
        WORK=$[$OUT - $IN]
        RETVAL=$[$RETVAL + $WORK]
        IN=""
        ;;

      *)
        printf "unrecognized action: %s; %s\n", $_ACTION, $FIX_THE_LOGS >&2
        exit 1
        ;;

    esac
  done

  if [ "$IN" != "" ] && [ $UNIXTIME -gt $IN ]
  then
    WORK=$[$UNIXTIME - $IN]
    RETVAL=$[$RETVAL + $WORK]
  fi

  echo $RETVAL
}

pretty_print() {
  if [ $1 -lt 0 ]
  then
    TS=`echo $1 | cut -d"-" -f2`
    SIGN="-1"
  else
    TS=$1
    SIGN="1"
  fi

  DAYS=$[`date --utc -d @$TS +%j`-1]
  HOURS=$[$SIGN * $[`date --utc -d @$TS +%_H`+$[DAYS*24]]]
  MINUTES=`date --utc -d @$TS +%_M`
  printf "%7d:%02d" "$HOURS" "$MINUTES"
}

diff() {
  RETVAL=$[$1 - $2]
  echo $RETVAL
}

workseconds_from_calendar_days() {
  echo $[$1*8*60*60]
}

logged_workseconds_from_day() {
  egrep "$1 .*:.* .*" "$MONTH_FILE" | total
}

# <commands>

today() {
  echo " date         work-hours   over-time"
  echo "------------+------------+-----------"
  WORK=`logged_workseconds_from_day $DATE`
  DIFF=`diff $WORK $(workseconds_from_calendar_days 1)`
  echo " $DATE   `pretty_print $WORK`  `pretty_print $DIFF`"
  EOW=$[$UNIXTIME - $DIFF]
  echo ""
  echo "Expected EOW: `date -d @$EOW +'%Y-%m-%d %R %Z'`"
}

month() {
  echo "------------+------------+-----------"
  echo " date         work-hours   over-time"
  echo "------------+------------+-----------"

  DAY_COUNT=0
  TOTAL=0
  for DAY in `cut -d" " -f1 $MONTH_FILE | grep -v $DATE | sort | uniq`
  do
    WORK=`logged_workseconds_from_day $DAY`
    DIFF=`diff $WORK $(workseconds_from_calendar_days 1)`
    echo " $DAY   `pretty_print $WORK`  `pretty_print $DIFF`"

    DAY_COUNT=$[$DAY_COUNT+1]
    TOTAL=$[$TOTAL + $WORK]
  done

  EXPECTED=`workseconds_from_calendar_days $DAY_COUNT`
  TOTALDIFF=`diff $TOTAL $EXPECTED`

  echo "------------+------------+-----------"
  echo "              `pretty_print $TOTAL`  `pretty_print $TOTALDIFF`"
  echo "------------+------------+-----------"

  TODAY=`logged_workseconds_from_day $DATE`
  DIFF=`diff $TODAY $(workseconds_from_calendar_days 1)`

  echo " Today        `pretty_print $TODAY`  `pretty_print $DIFF`"
  echo "------------+------------+-----------"

  TOTAL=$[$TOTAL + $TODAY]
  TOTALDIFF=$[$TOTALDIFF + $DIFF]

  echo " TOTAL        `pretty_print $TOTAL`  `pretty_print $TOTALDIFF`"
  echo "------------+------------+-----------"
}

# </commands>

case "$CMD" in
  day) ;& today) today;;
  month) month;;
  *)
    echo "unknown command: $CMD" >&2
    echo "" >&2
    usage >&2
    exit 1
    ;;
esac

