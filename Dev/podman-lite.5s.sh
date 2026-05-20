#!/usr/bin/env zsh

# Metadata allows your plugin to show up in the app, and website.
#
#  <xbar.title>Podman Manager (Simple View)</xbar.title>
#  <xbar.version>v1.1</xbar.version>
#  <xbar.author>Tiago Faustino, Séamus Ó Ceanainn</xbar.author>
#  <xbar.author.github>tiagofaustino,soceanainn</xbar.author.github>
#  <xbar.desc>A visually simpler Podman menu bar plugin</xbar.desc>
#  <xbar.image>https://i.imgur.com/IOFzxJz.png</xbar.image>
#  <xbar.dependencies>zsh,podman</xbar.dependencies>
#  <xbar.abouturl>https://github.com/matryer/xbar-plugins</xbar.abouturl>

# Inspired by the original Podman plugin by Seamus O Ceanainn.

# Variables become preferences in the app:
#
#  <xbar.var>string(VAR_PATH="/opt/homebrew/bin/podman"): Absolute path to podman binary</xbar.var>
#  <xbar.var>string(VAR_BREW_PATH="/opt/homebrew/bin/brew"): Absolute path to Homebrew 'brew' binary</xbar.var>
#  <xbar.var>number(VAR_IDLE_LIMIT=600): Idle time in seconds before pausing checks (set 0 to disable).</xbar.var>

GRAY='\033[1;30m'
INTERMEDIATE_GRAY='\033[38;5;238m'
SLIGHTLY_LIGHTER_GRAY='\033[38;5;243m'
NC='\033[0m'

# For some reason, this isn't working to open plugin configuration screen (below)
PLUGIN_PATH=`awk -F '/' '{print $NF}'<<<"$0"`

# Idle threshold (in seconds)
IDLE_LIMIT="${VAR_IDLE_LIMIT:-600}"  # 10 minutos
get_idle_time() {
  local idle_ns=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print $NF; exit}')
  if [[ -n "${idle_ns}" ]]; then
    echo $((idle_ns / 1000000000))
  else
    echo 0
  fi
}

if [[ -f "${VAR_PATH}" ]]; then
  alias podman="${VAR_PATH}"
  
  # Skip checks when idle time exceeds the configured threshold
  if (( IDLE_LIMIT > 0 )); then
    idle_time=$(get_idle_time)
    if (( idle_time > IDLE_LIMIT )); then
      echo -e "${GRAY}? pod${NC}"
      echo "---"
      echo "Inactive (idle time > ${IDLE_LIMIT} seconds)"
      exit 0
    fi
  fi
  
  running_machine="$(podman machine list | grep 'Currently running' | awk '{print $1}' | sed 's/*//g')"
  if [[ "${running_machine}" != "" ]]; then
    mem_usage=$(podman stats --no-stream --format "{{.MemUsage}}" | awk '{sum += $1} END {if (sum == "") print "0 MB"; else printf "%d MB", sum}')
    count_up=$(podman ps --format "{{.ID}}" | grep . | wc -l | xargs)
    
    echo -e "↑ ${SLIGHTLY_LIGHTER_GRAY}${count_up} $( (( count_up > 0 )) && echo -e "${INTERMEDIATE_GRAY} ${mem_usage}" )${NC}"

    echo "---"
    echo "Currently running: ${running_machine}"
    if (( count_up > 0 )); then
      echo "Stop all containers | shell=/bin/bash | param1=-c | param2='${VAR_PATH} stop \$(${VAR_PATH} ps -q)' | refresh=true | terminal=false"
    fi
    echo "Stop machine: ${running_machine} | shell=${VAR_PATH} | param1=machine | param2=stop | param3=${running_machine} | refresh=true"
  else
    echo -e "${GRAY}↓"
    echo "---"
    echo "Start available machines:"
    all_machines=`podman machine list --noheading --format "{{.Name}}"`
    for machine in `echo ${all_machines}`; do
      echo "-- ${machine} | shell=${VAR_PATH} | param1=machine | param2=start | param3=${machine//\*} | refresh=true"
    done
  fi
else 
  echo -e "pod ⚠️"
  echo "---"
  echo "Cannot find Podman at: '${VAR_PATH}'"
  echo "Try installing Podman or updating plugin configuration with corect path"
  if [[ -f ${VAR_BREW_PATH} ]]; then
    echo "Install podman | shell=${VAR_BREW_PATH} | param1=install | param2=podman"
  fi
#  echo "Configure plugin | href=xbar://app.xbarapp.com/openPlugin?path=${PLUGIN_PATH}"
  echo ""
  exit 0
fi


if [[ "${running_machine}" != "" ]]; then
  machine_info=$(podman machine inspect "${running_machine}")
  cpu_count=$(echo "$machine_info" | grep -A5 '"Resources": {' | grep '"CPUs":' | awk '{print $2}' | tr -d ',')
  mem_mb=$(echo "$machine_info" | grep -A5 '"Resources": {' | grep '"Memory":' | awk '{print $2}' | tr -d ',')
  disk_mb=$(echo "$machine_info" | grep -A5 '"Resources": {' | grep '"DiskSize":' | awk '{print $2}' | tr -d ',')
  if [[ -n "$mem_mb" ]]; then
    mem_gb=$(awk "BEGIN {printf \"%.1f\", $mem_mb/1024}")
    if [[ -n "$disk_mb" ]]; then
      echo "Allocated: CPU: ${cpu_count}, RAM: ${mem_gb} GB, Disk: ${disk_mb} MB | size=10 | color=#888888"
    else
      echo "Allocated: CPU: ${cpu_count}, RAM: ${mem_gb} GB | size=10 | color=#888888"
    fi
  fi
fi
# echo "Configure plugin | href=xbar://app.xbarapp.com/openPlugin?path=${PLUGIN_PATH}"
echo "`podman --version` | disabled=true | size=10"
if [[ -f ${VAR_BREW_PATH} &&`${VAR_BREW_PATH} outdated | grep "podman"` ]]; then
  echo "A new version of podman is available | size 10"
  echo "Upgrade | shell=${VAR_BREW_PATH} | param1=upgrade | param2=podman"
fi