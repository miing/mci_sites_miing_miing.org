#!/bin/sh
#
# Launch Jenkins as a daemon process.
# This script is inspired heavily by gerrit.sh.
#
# Copyright (C) 2013 Miing.org <samuel.miing@gmail.com>
#
##################################################################################
# To get the service to restart correctly on reboot, uncomment below (3 lines):
# ========================
# chkconfig: 3 99 99
# description: Jenkins Continuous Integration
# processname: jenkins
# ========================
# For more information on it, have a look at http://linux.die.net/man/8/chkconfig
#
###################################################################################
# Default configuration file for Jenkins located at /etc/default/jenkins can be
# modified to fit your needs.
# 

usage() {
    me=`basename "$0"`
    echo >&2 "Usage: $me {start|stop|restart|check|run|supervise}"
    exit 1
}

test $# -gt 0 || usage


##################################################
# Some utility functions
##################################################
running() {
  test -f $1 || return 1
  PID=`cat $1`
  ps -p $PID >/dev/null 2>/dev/null || return 1
  return 0
}


##################################################
# Get the action
##################################################
ACTION=$1
shift

test -z "$NO_START" && NO_START=0
test -z "$START_STOP_DAEMON" && START_STOP_DAEMON=1


##################################################
# See if there's a default configuration file
##################################################
if test -f /etc/default/jenkins ; then 
  . /etc/default/jenkins
fi


##################################################
# Set tmp if not already set.
##################################################
if test -z "$TMP" ; then
  TMP=/tmp
fi
TMPJ=$TMP/j$$


##################################################
# Reasonable guess marker for Jenkins home
##################################################
JENKINS_INIT_SCRIPT_FILE=bin/jenkins.sh


##################################################
# Try to determine JENKINS_HOME if not set
##################################################
if test -z "$JENKINS_HOME" ; then
  JENKINS_HOME_1=`dirname "$0"`
  JENKINS_HOME_1=`dirname "$JENKINS_HOME"`
  if test -f "${JENKINS_HOME_1}/${JENKINS_INIT_SCRIPT_FILE}" ; then 
    JENKINS_HOME=${JENKINS_HOME_1} 
  fi
fi


##################################################
# No JENKINS_HOME yet? We're out of luck!
##################################################
if test -z "$JENKINS_HOME" ; then
    echo >&2 "** ERROR: JENKINS_HOME not set" 
    exit 1
fi

if cd "$JENKINS_HOME" ; then
  JENKINS_HOME=`pwd`
else
  echo >&2 "** ERROR: Jenkins home $JENKINS_HOME not found"
  exit 1
fi


#####################################################
# Check that the rest of base vars are set
#####################################################
test -z "$JENKINS_USER" && JENKINS_USER="jenkins"
test -z "$JENKINS_PID" && JENKINS_PID="$JENKINS_HOME/bin/gerrit.pid"
test -z "$JENKINS_LOG" && JENKINS_LOG="$JENKINS_HOME/log/jenkins.log"


##################################################
# Check for JAVA_HOME
##################################################
JAVA_HOME_OLD="$JAVA_HOME"
if test -z "$JAVA_HOME" ; then
  JAVA_HOME="$JAVA_HOME_OLD"
fi
if test -z "$JAVA_HOME" ; then
    # If a java runtime is not defined, search the following
    # directories for a JVM and sort by version. Use the highest
    # version number.

    JAVA_LOCATIONS="\
        /usr/java \
        /usr/bin \
        /usr/local/bin \
        /usr/local/java \
        /usr/local/jdk \
        /usr/local/jre \
        /usr/lib/jvm \
        /opt/java \
        /opt/jdk \
        /opt/jre \
    "
    for N in java jdk jre ; do
      for L in $JAVA_LOCATIONS ; do
        test -d "$L" || continue 
        find $L -name "$N" ! -type d | grep -v threads | while read J ; do
          test -x "$J" || continue
          VERSION=`eval "$J" -version 2>&1`
          test $? = 0 || continue
          VERSION=`expr "$VERSION" : '.*"\(1.[0-9\.]*\)["_]'`
          test -z "$VERSION" && continue
          expr "$VERSION" \< 1.2 >/dev/null && continue
          echo "$VERSION:$J"
        done
      done
    done | sort | tail -1 >"$TMPJ"
    JAVA=`cat "$TMPJ" | cut -d: -f2`
    JVERSION=`cat "$TMPJ" | cut -d: -f1`
    rm -f "$TMPJ"

    JAVA_HOME=`dirname "$JAVA"`
    while test -n "$JAVA_HOME" \
               -a "$JAVA_HOME" != "/" \
               -a ! -f "$JAVA_HOME/lib/tools.jar" ; do
      JAVA_HOME=`dirname "$JAVA_HOME"`
    done
    test -z "$JAVA_HOME" && JAVA_HOME=

    echo "** INFO: Using $JAVA"
fi

if test -z "$JAVA" \
     -a -n "$JAVA_HOME" \
     -a -x "$JAVA_HOME/bin/java" \
     -a ! -d "$JAVA_HOME/bin/java" ; then
  JAVA="$JAVA_HOME/bin/java"
fi

if test -z "$JAVA" ; then
  echo >&2 "Cannot find a JRE or JDK. Please set JAVA_HOME to a >=1.6 JRE"
  exit 1
fi


#####################################################
# Add Jenkins properties to Java VM options.
#####################################################
if test -n "$JENKINS_MEMORY" ; then
  JAVA_OPTIONS="-Xmx$JENKINS_MEMORY"
fi

test -z "$JENKINS_FDS" && GERRIT_FDS=128
test $JENKINS_FDS -lt 1024 && JENKINS_FDS=1024


#####################################################
# Configure sane ulimits for a daemon of our size.
#####################################################
ulimit -c 0            ; # core file size
ulimit -d unlimited    ; # data seg size
ulimit -f unlimited    ; # file size
ulimit -m >/dev/null 2>&1 && ulimit -m unlimited  ; # max memory size
ulimit -n $JENKINS_FDS  ; # open files
ulimit -t unlimited    ; # cpu time
ulimit -v unlimited    ; # virtual memory

ulimit -x >/dev/null 2>&1 && ulimit -x unlimited  ; # file locks


#####################################################
# This is how the Jenkins server will be started
#####################################################
if test -z "$JENKINS_WAR" ; then
  JENKINS_WAR="$JENKINS_HOME/bin/jenkins.war"
  test -f "$JENKINS_WAR" || JENKINS_WAR=
fi
if test -z "$JENKINS_WAR" -a -n "$JENKINS_USER" ; then
  for homedir in /home /Users ; do
    if test -d "$homedir/$JENKINS_USER" ; then
      JENKINS_WAR="$homedir/$JENKINS_USER/jenkins.war"
      if test -f "$JENKINS_WAR" ; then
        break
      else
        JENKINS_WAR=
      fi
    fi
  done
fi
if test -z "$JENKINS_WAR" ; then
  echo >&2 "** ERROR: Cannot find gerrit.war (try setting \$JENKINS_WAR)"
  exit 1
fi

test -z "$JENKINS_USER" && JENKINS_USER=`whoami`
RUN_ARGS="-jar $JENKINS_WAR"
test -n "$JENKINS_CONFIG" && RUN_ARGS="$RUN_ARGS --config=$JENKINS_CONFIG"
PREFIX="$PREFIX" && RUN_ARGS="$RUN_ARGS --prefix=$PREFIX"
test -n "$HTTP_PORT" && RUN_ARGS="$RUN_ARGS --httpPort=$HTTP_PORT"
test -n "$AJP_PORT" && RUN_ARGS="$RUN_ARGS --ajp13Port=$AJP_PORT"
if test -n "$JAVA_OPTIONS" ; then
  RUN_ARGS="$JAVA_OPTIONS $RUN_ARGS"
fi

if test -x /usr/bin/perl ; then
  # If possible, use Perl to mask the name of the process so its
  # something specific to us rather than the generic 'java' name.
  #
  export JAVA
  export JENKINS_HOME
  RUN_EXEC=/usr/bin/perl
  RUN_Arg1=-e
  RUN_Arg2='$x=$ENV{JAVA};exec $x @ARGV;die $!'
  RUN_Arg3='-- Jenkins'
else
  RUN_EXEC="$JENKINS_HOME $JAVA"
  RUN_Arg1=
  RUN_Arg2='-DJenkins=1'
  RUN_Arg3=
fi


##################################################
# Do the action
##################################################
case "$ACTION" in
  start)
    printf '%s' "Starting Jenkins Continuous Integration: "

    if test 1 = "$NO_START" ; then 
      echo "Not starting jenkins - NO_START=1 in /etc/default/jenkins"
      exit 0
    fi

    test -z "$UID" && UID=`id | sed -e 's/^[^=]*=\([0-9]*\).*/\1/'`

    if test 1 = "$START_STOP_DAEMON" && type start-stop-daemon >/dev/null 2>&1
    then
      test $UID = 0 && CH_USER="-c $JENKINS_USER"
      if start-stop-daemon -S -b $CH_USER \
         -p "$JENKINS_PID" -m \
         -d "$JENKINS_HOME" \
         -a "$RUN_EXEC" -- $RUN_Arg1 "$RUN_Arg2" $RUN_Arg3 $RUN_ARGS
      then
        : OK
      else
        rc=$?
        if test $rc = 127; then
          echo >&2 "fatal: start-stop-daemon failed"
          rc=1
        fi
        exit $rc 
      fi
    else
      if test -f "$JENKINS_PID" ; then
        if running "$JENKINS_PID" ; then
          echo "Already Running!!"
          exit 1
        else
          rm -f "$JENKINS_PID" "$JENKINS_LOG"
        fi
      fi

      if test $UID = 0 -a -n "$JENKINS_USER" ; then 
        touch "$JENKINS_PID"
        chown $JENKINS_USER "$JENKINS_PID"
        su - $JENKINS_USER -c "
          JAVA='$JAVA' ; export JAVA ;
          $RUN_EXEC $RUN_Arg1 '$RUN_Arg2' $RUN_Arg3 $RUN_ARGS </dev/null >/dev/null 2>&1 &
          PID=\$! ;
          disown ;
          echo \$PID >\"$JENKINS_PID\""
      else
        $RUN_EXEC $RUN_Arg1 "$RUN_Arg2" $RUN_Arg3 $RUN_ARGS </dev/null >/dev/null 2>&1 &
        PID=$!
        type disown >/dev/null 2>&1 && disown
        echo $PID >"$JENKINS_PID"
      fi
    fi

    if test $UID = 0; then
        PID=`cat "$JENKINS_PID"`
        if test -f "/proc/${PID}/oom_score_adj" ; then
            echo -1000 > "/proc/${PID}/oom_score_adj"
        else
            if test -f "/proc/${PID}/oom_adj" ; then
                echo -16 > "/proc/${PID}/oom_adj"
            fi
        fi
    fi

    TIMEOUT=90  # seconds
    sleep 1
    while test $TIMEOUT -gt 0 ; do
      if running "$JENKINS_PID" ; then
        echo OK
        exit 0
      fi

      sleep 2
      TIMEOUT=`expr $TIMEOUT - 2`
    done

    echo FAILED
    exit 1
  ;;

  stop)
    printf '%s' "Stopping Jenkins Continuous Integration: "

    if test 1 = "$START_STOP_DAEMON" && type start-stop-daemon >/dev/null 2>&1
    then
      start-stop-daemon -K -p "$JENKINS_PID" -s HUP 
      sleep 1
      if running "$JENKINS_PID" ; then
        sleep 3
        if running "$JENKINS_PID" ; then
          sleep 30
          if running "$JENKINS_PID" ; then
            start-stop-daemon -K -p "$JENKINS_PID" -s KILL
          fi
        fi
      fi
      rm -f "$JENKINS_PID"
      echo OK
    else
      PID=`cat "$JENKINS_PID" 2>/dev/null`
      TIMEOUT=30
      while running "$JENKINS_PID" && test $TIMEOUT -gt 0 ; do
        kill $PID 2>/dev/null
        sleep 1
        TIMEOUT=`expr $TIMEOUT - 1`
      done
      test $TIMEOUT -gt 0 || kill -9 $PID 2>/dev/null
      rm -f "$JENKINS_PID"
      echo OK
    fi
  ;;

  restart)
    JENKINS_SH=$0
    if test -f "$JENKINS_SH" ; then
      : OK
    else
      echo >&2 "** ERROR: Cannot locate jenkins.sh"
      exit 1
    fi
    $JENKINS_SH stop $*
    sleep 5
    $JENKINS_SH start $*
  ;;

  supervise)
    #
    # Under control of daemontools supervise monitor which
    # handles restarts and shutdowns via the svc program.
    #
    exec "$RUN_EXEC" $RUN_Arg1 "$RUN_Arg2" $RUN_Arg3 $RUN_ARGS
    ;;

  run|daemon)
    echo "Running Gerrit Code Review:"

    if test -f "$JENKINS_PID" ; then
        if running "$JENKINS_PID" ; then
          echo "Jenkins Running already!!"
          exit 1
        else
          rm -f "$JENKINS_PID"
        fi
    fi

    exec "$RUN_EXEC" $RUN_Arg1 "$RUN_Arg2" $RUN_Arg3 $RUN_ARGS --console-log
  ;;

  check)
    echo "Checking arguments to Jenkins Continuous Integration:"
    echo "  JENKINS_HOME     =  $JENKINS_HOME"
    echo "  JENKINS_USER     =  $JENKINS_USER"
    echo "  JENKINS_CONFIG   =  $JENKINS_CONFIG"
    echo "  JENKINS_WAR      =  $JENKINS_WAR"
    echo "  JENKINS_PID      =  $JENKINS_PID"
    echo "  JENKINS_FDS      =  $JENKINS_FDS"
    echo "  JAVA            =  $JAVA"
    echo "  JAVA_OPTIONS    =  $JAVA_OPTIONS"
    echo "  RUN_EXEC        =  $RUN_EXEC $RUN_Arg1 '$RUN_Arg2' $RUN_Arg3"
    echo "  RUN_ARGS        =  $RUN_ARGS"
    echo

    if test -f "$JENKINS_PID" ; then
        if running "$JENKINS_PID" ; then
            echo "Jenkins running pid="`cat "$JENKINS_PID"`
            exit 0
        fi
    fi
    exit 1
  ;;

  *)
    usage
  ;;
esac

exit 0
