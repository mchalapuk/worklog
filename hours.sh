#!/bin/bash

#set -x

PRG=$0

usage() {
  echo "Usage: $PRG <command> (arguments...)"
  echo ""
  echo "Commands:"
  echo "  today - displays hours logged today"
  echo "  day (((y-)m-)d) - displays hours logged in a day (default=today)"
  echo "  month (m) (y) - displays hours logged in a month (default=this month)"
  echo "  log <action> (datetime) - logs an action"
  echo ""
  echo "Actions:"
  echo "  IN - start logging work"
  echo "  OUT - stop logging work"
  echo ""
}

CMD=$1
shift

die() {
  echo -e "$@" >&2
  exit 1
}

CONFIG_FILE="$HOME/.worklog"
test -f "$CONFIG_FILE" || echo "DATA_DIR=\$HOME/worklog" > "$CONFIG_FILE"
test -f "$CONFIG_FILE" || \
  die "no config file found; run \`touch $CONFIG_FILE\` to correct this"

. "$CONFIG_FILE"
test "$DATA_DIR" != "" || \
  die "DATA_DIR variable not defined; please add it to $CONFIG_FILE"

DAILY_WORK_HOURS=${DAILY_WORK_HOURS:-8}
MONTHLY_WORK_DAYS=${MONTHLY_WORK_DAYS:-21}

test -d "$DATA_DIR" || mkdir -p "$DATA_DIR"
test -d "$DATA_DIR" || \
  die "DATA_DIR=$DATA_DIR is not a directory; run \`mkdir -p $DATA_DIR\` to correct it"

TODAY=`date +%Y-%m-%d`
DATE="$TODAY"
TIME=`date +%H:%M:%S`

YEAR=`date +%Y`
MONTH=$(echo `date +%m`)
DAY=$(echo `date +%d`)
HOUR=`date +%H`
MINUTE=`date +%M`
SECOND=`date +%S`
UNIXTIME=`date +%s`

YEAR_REGEX="[0-9]{4,}"
MONTH_REGEX="(0?[1-9]|1[012])"
DAY_REGEX="(0?[1-9]|[12][0-9]|3[01])"
DATE_REGEX="${YEAR_REGEX}-${MONTH_REGEX}-${DAY_REGEX}"
TIME_REGEX="[0-9]{1,2}(:[0-9]{2}){1,2}"
DATE_TIME_REGEX="($DATE_REGEX\s+)?$TIME_REGEX"
ACTION_REGEX="[A-Z]+"

add_leading_zero() {
  if egrep -q "^[0-9]$" <<< "$1"
  then
    printf "%02d" "$1"
  else
    echo "$1"
  fi
}

check_year() {
  if ! egrep -q "^$YEAR_REGEX$" <<< "$1"
  then
    die "Wrong year format: $1; expected=$YEAR_REGEX" >&2
  fi
  echo "$1"
}

check_month() {
  if ! egrep -q "^$MONTH_REGEX$" <<< "$1"
  then
    die "Wrong month format: $1; expected=$MONTH_REGEX" >&2
  fi
  add_leading_zero $1
}

check_day() {
  if ! egrep -q "^$DAY_REGEX$" <<< "$1"
  then
    die "Wrong day format: $1; expected=$DAY_REGEX" >&2
  fi
  add_leading_zero $1
}

month_file() {
  YEAR_DIR="$DATA_DIR$YEAR"
  mkdir -p "$YEAR_DIR"

  MONTH_FILE="$YEAR_DIR/$MONTH.worklog"
  test -f "$MONTH_FILE" || touch "$MONTH_FILE"
  echo "$MONTH_FILE"
}

error() {
 test -n "$VERBOSE" && echo $@ >&2
}

total() {
  FIX_THE_LOGS="please fix the log files"
  RETVAL=0

  IN=""
  while read -r _DAY _HOUR _ACTION
  do
    TIMESTAMP=$(date -d "$_DAY $_HOUR `date +%z`" +%s)
    case "$_ACTION" in

      'IN')
        if [ "$IN" != "" ]
        then
          error "detected two IN actions in a row ($_DAY $_HOUR); $FIX_THE_LOGS"
        fi
        IN=$TIMESTAMP
        ;;

      'OUT')
        OUT=$TIMESTAMP

        if [ "$IN" == "" ]
        then
          error "detected OUT action without corresponding IN action ($_DAY $_HOUR); $FIX_THE_LOGS"
          continue
        fi

        if [ "$OUT" -lt "$IN" ]
        then
          error "OUT action's timestamp before corresponding IN action ($_DAY $_HOUR); $FIX_THE_LOGS"
          continue
        fi

        WORK=$[$OUT - $IN]
        RETVAL=$[$RETVAL + $WORK]
        IN=""
        ;;

      *)
        error "unrecognized action: $_ACTION; $FIX_THE_LOGS"
        continue
        ;;

    esac
  done

  if [ "$IN" != "" ] && [ "$UNIXTIME" -gt "$IN" ]
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
    SIGN="-"
  else
    TS=$1
    SIGN=""
  fi

  DAYS=$[`date --utc -d @$TS +%_j`- 1]
  HOURS=$[`date --utc -d @$TS +%_H` + $[$DAYS * 24]]
  MINUTES=`date --utc -d @$TS +%_M`

  HNM="$SIGN`printf "%02d:%02d\n" "$HOURS" "$MINUTES"`"
  printf "%10s\n" "$HNM"
}

diff() {
  RETVAL=$[$1 - $2]
  echo $RETVAL
}

workseconds_from_calendar_days() {
  echo $[$1*$DAILY_WORK_HOURS*60*60]
}

logged_workseconds_from_day() {
  if ! egrep -q "^$DATE_REGEX$" <<< "$1"
  then
    die "Wrong date format: $1; expected=$DATE_REGEX"
  fi
  egrep "^$1\s+$TIME_REGEX\s+$ACTION_REGEX$" "`month_file`" | total
}

is_weekday() {
  DAY_OF_WEEK="`date -d $1 +%u`"
  test "$DAY_OF_WEEK" -lt 6
}

is_current_month() {
  test $1 == `date +%m`
}
is_current_year() {
  test $1 == `date +%Y`
}

# <commands>

day() {
  if [ "" == "$1" ]
  then
    DATE="$DATE"
  elif egrep -q "^${DATE_REGEX}$" <<< "$1"
  then
    DATE=$1
  elif egrep -q "^${MONTH_REGEX}-${DAY_REGEX}$" <<< "$1"
  then
    MONTH=$(check_month `cut -d'-' -f1 <<< "$1"`)
    DAY=$(check_day `cut -d"-" -f2 <<< "$1"`)
    DATE="${YEAR}-${MONTH}-${DAY}"
  elif egrep -q "^${DAY_REGEX}$" <<< "$1"
  then
    DAY=`check_day "$1"`
    DATE="${YEAR}-${MONTH}-${DAY}"
  else
    die "Unrecognized day format: $1;\n"\
      "  expected=${DATE_REGEX},\n"\
      "  expected=${MONTH_REGEX}-${DAY_REGEX},\n"\
      "  expected=${DAY_REGEX}"
  fi

  echo " date         work-hours   over-time"
  echo "------------+------------+-----------"
  WORK=`logged_workseconds_from_day $DATE`
  DIFF=`diff $WORK $(workseconds_from_calendar_days 1)`
  echo " $DATE   `pretty_print $WORK`  `pretty_print $DIFF`"

  test "$DATE" == "$TODAY" || return

  EOW=$[$UNIXTIME - $DIFF]
  echo ""
  echo "Expected EOW: `date -d @$EOW +'%Y-%m-%d %R %Z'`"
}

month() {
  MONTH=`check_month ${1:-$MONTH}`
  YEAR=`check_year ${2:-$YEAR}`

  echo "----+------------+------------+-----------"
  echo " no   date         work-hours   over-time "
  echo "----+------------+------------+-----------"

  EXPECTED_WEEKDAYS_WORK=$(workseconds_from_calendar_days 1)
  EXPECTED_WEEKEND_WORK=0

  DAY_COUNT=0
  TOTAL=0
  TOTAL_DIFF=0

  for DAY in $(cut -d" " -f1 "`month_file`" | grep -v $DATE | sort | uniq)
  do
    WORK=`logged_workseconds_from_day $DAY`
    if is_weekday $DAY
    then
      DAY_COUNT=$[$DAY_COUNT + 1]
      DIFF=`diff $WORK $EXPECTED_WEEKDAYS_WORK`
      echo -n " `add_leading_zero $DAY_COUNT`  "
    else
      DIFF=`diff $WORK $EXPECTED_WEEKEND_WORK`
      echo -n "     "
    fi

    echo " $DAY   `pretty_print $WORK`  `pretty_print $DIFF`"
    TOTAL=$[$TOTAL + $WORK]
    TOTAL_DIFF=$[$TOTAL_DIFF + $DIFF]
  done

  WORK=`logged_workseconds_from_day $DATE`

  if is_current_month $MONTH && is_current_year $YEAR
  then
    if is_weekday $DATE
    then
      DAY_COUNT=$[$DAY_COUNT + 1]
      DIFF=`diff $WORK $EXPECTED_WEEKDAYS_WORK`
      echo -n " `add_leading_zero $DAY_COUNT`  "
      echo " $DATE   `pretty_print $WORK`  `pretty_print $DIFF`"
    elif [ "$WORK" -ne "0" ]
    then
      DIFF=`diff $WORK $EXPECTED_WEEKEND_WORK`
      echo -n "     "
      echo " $DATE   `pretty_print $WORK`  `pretty_print $DIFF`"
    fi
  fi

  TOTAL=$[$TOTAL + $WORK]
  TOTAL_DIFF=$[$TOTAL_DIFF + $DIFF]

  echo "----+------------+------------+-----------"
  echo "      TOTAL        `pretty_print $TOTAL`  `pretty_print $TOTAL_DIFF`"
  echo "----+------------+------------+-----------"

  EXPECTED_MONTH_WORK=`workseconds_from_calendar_days $MONTHLY_WORK_DAYS`
  ABSOLUTE_DIFF=`diff $TOTAL $EXPECTED_MONTH_WORK`

  echo "      ABSOLUTE                 `pretty_print $ABSOLUTE_DIFF`"
  echo "----+------------+------------+-----------"
}

log() {
  ACTION=$1

  case "$ACTION" in
    IN) ;& OUT) ;;
    '') die "No action specified";;
    *) die "Unknown action: $ACTION";;
  esac

  DATE=${2:-$DATE}
  TIME=${3:-$TIME}

  DATE_TIME="$DATE $TIME"
  if ! egrep -q "^$DATE_TIME_REGEX$" <<< "$DATE_TIME"
  then
    die "Wrong date-time format: $DATE_TIME; expected=$DATE_TIME_REGEX"
  fi

  echo "$DATE_TIME $ACTION" >> "`month_file`"
}

# </commands>

case "$CMD" in
  day) day "$@";;
  today) day "$DATE";;
  month) month "$@";;
  log) log "$@";;
  help) ;& usage) ;& ?) usage;;
  '')
    echo "no command specified" >&2
    echo "" >&2
    usage >&2
    exit 1
    ;;
  *)
    echo "unknown command: $CMD" >&2
    echo "" >&2
    usage >&2
    exit 1
    ;;
esac

