# Configure safe_asterisk to collect backtrace information after a crash.
# Store this file as /etc/asterisk/startup.d/mail-backtrace.sh.
#
# Walter Doekes 2015.


# Don't use a TTY (with CONSOLE). We'll never look at that console
# anyway.
TTY=no

# ASTARGS and TTY setting have been altered before startup.d scripts
# are run. Undo it, because TTY=no.
ASTARGS=

# Email problems to root.
NOTIFY=root

# Set higher priority.
PRIORITY=-2

# No need to set this anymore. The safe_asterisk script will check it
# and set it to 50723 automatically. (startup.d scripts are run very
# late, so setting the MAXFILES variable is pointless.)
#ulimit -n 12288  # MAXFILES=12288

# Dump directory AST_DUMPCORE_DIR is not propagated from /etc/default/asterisk
# to safe_asterisk. Set it here.
DUMPDROP=/var/spool/asterisk

# Extend post-crash behaviour. (NET-62 and GRID-811)
post_crash_exec() {
    # Create filenames equal to the ones in safe_asterisk.
    PID=`cat ${ASTPIDFILE}`
    DATE=`date "+%Y-%m-%dT%H:%M:%S%z"`
    CORESRC=
    COREDST="${DUMPDROP}/core.`hostname`-$DATE"
    if test -f "${RUNDIR}/core.${PID}"; then
        CORESRC="${RUNDIR}/core.${PID}"
    elif test -f "${RUNDIR}/core"; then
        CORESRC="${RUNDIR}/core"
    fi

    # Create a location for more informational stuff.
    mkdir "$COREDST.d"
    chmod 700 "$COREDST.d"
    # Fetch gdb info.
    if test -n "$CORESRC" && test -x /usr/bin/gdb; then
        for command in "bt" "bt full" "info threads" \
                "thread apply all bt" "thread apply all bt full"; do
            file="`echo $command | sed -e 's/ /-/g'`.txt"
            /usr/bin/gdb `which asterisk` "$CORESRC" \
                    --batch -ex "$command" > "$COREDST.d/$file"
        done
    fi

    # Save recent pcaps and log files for further inspection. We do
    # this after the GDB, so tcpdump gets a little more time to flush
    # its buffers. (BEWARE: we might be too early still. Tcpdump
    # doesn't seem to take SIGUSR1 to flush its buffers.)
    find /var/spool/tcpdump/ /var/log/asterisk/ \
            -maxdepth 1 -mmin -5 -type f |
        xargs -I{} -d\\n cp -a {} "$COREDST.d/"

    # Attempt to rename this to the same "second" as the core file
    # which is about to be moved.
    DATE=`date "+%Y-%m-%dT%H:%M:%S%z"`
    COREDST_old="$COREDST"
    COREDST="${DUMPDROP}/core.`hostname`-$DATE"
    mv "$COREDST_old.d" "$COREDST.d"

    # Finally, mail what we have. An improved version of the basic
    # NOTIFY setting where we have MACHINE and EXITSIGNAL in the
    # subject and a backtrace in the body.
    mail -s "Asterisk on $MACHINE died (sig $EXITSIGNAL)" root << EOF
Asterisk on $MACHINE exited on signal $EXITSIGNAL.

Might want to take a peek in: $COREDST.d

Files:

`ls -l "$COREDST.d"`

Backtrace:

`grep -v '^\[New LWP ' "$COREDST.d/bt.txt" 2>&1`

EOF
}

NOTIFY=  # we NOTIFY from post_crash_exec
EXEC=post_crash_exec


# vim: set ts=8 sw=4 sts=4 et ai:
