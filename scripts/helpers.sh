#!/usr/bin/env bash

##
# Varialbes
##
PATH="/usr/local/bin:$PATH:/usr/sbin"
DOWNLOAD_FILE="/tmp/tmux_net_speed.download"
UPLOAD_FILE="/tmp/tmux_net_speed.upload"

export LANG=C
export LC_ALL=C

get_velocity()
{
    local new_value=$1
    local old_value=$2

    # Consts
    local THOUSAND=1024
    local MILLION=1048576

    local interval=$(get_tmux_option 'status-interval' 5)
    local vel=$(( ( new_value - old_value ) / interval ))
    local vel_kb=$(( vel / THOUSAND ))
    local vel_mb=$(( vel / MILLION ))

    if [[ $vel_mb != 0 ]] ; then
        echo -n "$vel_mb MB/s"
    elif [[ $vel_kb != 0 ]] ; then
        echo -n "$vel_kb KB/s";
    else
        echo -n "$vel B/s";
    fi
}

# Reads from value from file. If file does not exist,
# is empty, or not readable, starts back at 0
read_file()
{
    local path="$1"
    local fallback_val=0

    # File exists and is readdable?
    if [[ ! -f "$path" ]] ; then
        echo $fallback_val
        return 1
    elif [[ ! -r "$path" ]]; then
        echo $fallback_val
        return 1
    fi


    # Does the file have content?
    tmp=$(< "$path")
    if [[ "x${tmp}" == "x" ]] ; then
        echo $fallback_val
        return 1
    fi

    # Now return known value
    echo $tmp
}

# Update values in file
write_file()
{
    local path="$1"
    local val="$2"

    # TODO Add error checking
    echo "$val" > "$path"
}

get_interfaces()
{
    local interfaces=$(get_tmux_option @net_speed_interfaces "")

    if [[ -z "$interfaces" ]] ; then
        for interface in /sys/class/net/*; do
            interfaces+=$(echo $(basename $interface) " ");
        done
    fi

    # Do not quote the variable. This way will handle trailing whitespace
    echo -n $interfaces
}

sum_speed()
{
    local column=$1

    declare -a interfaces=$(get_interfaces)

    local line=""
    local val=0
    for intf in ${interfaces[@]} ; do
        line=$(cat /proc/net/dev | grep "$intf" | cut -d':' -f 2)
        speed="$(echo -n $line | cut -d' ' -f $column)"
        let val+=${speed:=0}
    done

    echo $val
}

set_tmux_option() {
    local option=$1
    local value=$2
    tmux set-option -gq "$option" "$value"
}

get_tmux_option() {
  local option
  local default_value
  local option_value
  option="$1"
  default_value="$2"
  option_value="$(tmux show-option -qv "$option")"
  if [ -z "$option_value" ]; then
    option_value="$(tmux show-option -gqv "$option")"
  fi
  if [ -z "$option_value" ]; then
    echo "$default_value"
  else
    echo "$option_value"
  fi
}

is_osx() {
  [ "$(uname)" == "Darwin" ]
}

is_freebsd() {
  [ "$(uname)" == "FreeBSD" ]
}

is_openbsd() {
  [ "$(uname)" == "OpenBSD" ]
}

is_linux() {
  [ "$(uname)" == "Linux" ]
}

is_cygwin() {
  command -v WMIC &>/dev/null
}

is_linux_iostat() {
  # Bug in early versions of linux iostat -V return error code
  iostat -c &>/dev/null
}

# is second float bigger or equal?
fcomp() {
  awk -v n1="$1" -v n2="$2" 'BEGIN {if (n1<=n2) exit 0; exit 1}'
}

load_status() {
  local percentage=$1
  local prefix=$2
  medium_thresh=$(get_tmux_option "@${prefix}_medium_thresh" "30")
  high_thresh=$(get_tmux_option "@${prefix}_high_thresh" "80")
  if fcomp "$high_thresh" "$percentage"; then
    echo "high"
  elif fcomp "$medium_thresh" "$percentage" && fcomp "$percentage" "$high_thresh"; then
    echo "medium"
  else
    echo "low"
  fi
}

temp_status() {
  local temp
  temp=$1
  cpu_temp_medium_thresh=$(get_tmux_option "@cpu_temp_medium_thresh" "80")
  cpu_temp_high_thresh=$(get_tmux_option "@cpu_temp_high_thresh" "90")
  if fcomp "$cpu_temp_high_thresh" "$temp"; then
    echo "high"
  elif fcomp "$cpu_temp_medium_thresh" "$temp" && fcomp "$temp" "$cpu_temp_high_thresh"; then
    echo "medium"
  else
    echo "low"
  fi
}

cpus_number() {
  if is_linux; then
    if command_exists "nproc"; then
      nproc
    else
      echo "$(($(sed -n 's/^processor.*:\s*\([0-9]\+\)/\1/p' /proc/cpuinfo | tail -n 1) + 1))"
    fi
  else
    sysctl -n hw.ncpu
  fi
}

command_exists() {
  local command
  command="$1"
  command -v "$command" &>/dev/null
}

get_tmp_dir() {
  local tmpdir
  tmpdir="${TMPDIR:-${TMP:-${TEMP:-/tmp}}}"
  [ -d "$tmpdir" ] || local tmpdir=~/tmp
  echo "$tmpdir/tmux-$EUID-cpu"
}

get_time() {
  date +%s.%N
}

get_cache_val() {
  local key
  local timeout
  local cache
  key="$1"
  # seconds after which cache is invalidated
  timeout="${2:-2}"
  cache="$(get_tmp_dir)/$key"
  if [ -f "$cache" ]; then
    awk -v cache="$(head -n1 "$cache")" -v timeout="$timeout" -v now="$(get_time)" \
      'BEGIN {if (now - timeout < cache) exit 0; exit 1}' &&
      tail -n+2 "$cache"
  fi
}

put_cache_val() {
  local key
  local val
  local tmpdir
  key="$1"
  val="${*:2}"
  tmpdir="$(get_tmp_dir)"
  [ ! -d "$tmpdir" ] && mkdir -p "$tmpdir" && chmod 0700 "$tmpdir"
  get_time >"$tmpdir/$key"
  echo -n "$val" >>"$tmpdir/$key"
  echo -n "$val"
}

cached_eval() {
  local command
  local key
  local val
  command="$1"
  key="$(basename "$command")"
  val="$(get_cache_val "$key")"
  if [ -z "$val" ]; then
    put_cache_val "$key" "$($command "${@:2}")"
  else
    echo -n "$val"
  fi
}
