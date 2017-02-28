# worklog

A working hours logger and report generator.

## Installation

Worklog is a single-script program. Just fetch it from Github.

```
# assuming that ~/bin direcotry exists
wget https://raw.githubusercontent.com/muroc/worklog/master/hours.sh \
 --output-document ~/bin/hours
chmod +x ~/bin/hours
```

## Usage

```
Usage: hours <command> (arguments...)"

Commands:"
  today - displays hours logged today"
  day (((y-)m-)d) - displays hours logged in a day (default=today)"
  month (m) (y) - displays hours logged in a month (default=this month)"
  log <action> (datetime) - logs an action"

Actions:"
  IN - start logging work"
  OUT - stop logging work"
```

## Configuration

Worklog looks for a config file located in `~/.worklog`, which must be a valid shell script.

The configuration script must define following variables:

```sh
DATA_DIR=</path/to/worklog/data/>
```

In case `~/.worklog` does not exist, the script creates it with following
default configuration.

```
DATA_DIR=$HOME/worklog
```

## Automatic Logging

Hours can be logged automatically on system events.

Scripts for LightDm (default on Ubuntu) can be found in [/lightdm](/lightdm)
folder. These scripts logs all errors into `~/.hours.log` file.

```
# in order to display the logfile with each login
echo 'cat $HOME/.hours.log 2>/dev/null' >> ~/.profile
```

## License

&copy; 2017 Maciej Chałapuk. Released under [MIT License](LICENSE).

