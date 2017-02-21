#!/bin/sh

HOURS="$HOME/bin/hours" 

if ! [ -f "$HOURS" ]
then
  touch "$HOME/.no_hours"
  exit 1;
fi

OUTPUT=`$HOURS log IN 2>&1`
test -n "$OUTPUT" && echo "`date` :: $OUTPUT" >> "$HOME/.hours.log"
exit 0

