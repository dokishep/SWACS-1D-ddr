#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <syslog.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <time.h>

#define WATCHDOG_DEV "/dev/watchdog"
#define WATCHDOG_TIMEOUT 15 /* seconds */

static int watchdog_fd = -1;
static volatile int running = 1;

static void signal_handler(int sig)
{
    running = 0;
    syslog(LOG_INFO, "Received signal %d, shutting down", sig);
}

static int watchdog_open(void)
{
    watchdog_fd = open(WATCHDOG_DEV, O_WRONLY);
    if (watchdog_fd == -1) {
        syslog(LOG_ERR, "Cannot open %s: %s", WATCHDOG_DEV, strerror(errno));
        return -1;
    }
    syslog(LOG_INFO, "Opened watchdog device %s", WATCHDOG_DEV);
    return 0;
}

static int watchdog_feed(void)
{
    int ret;
    /* Write a single byte to feed the watchdog */
    ret = write(watchdog_fd, "\0", 1);
    if (ret != 1) {
        syslog(LOG_ERR, "Cannot write to watchdog: %s", strerror(errno));
        return -1;
    }
    return 0;
}

static void watchdog_close(void)
{
    if (watchdog_fd != -1) {
        close(watchdog_fd);
        watchdog_fd = -1;
    }
}

int main(int argc, char *argv[])
{
    struct sigaction sa;
    time_t last_feed = 0;

    /* Initialize syslog */
    openlog("ddr-reaper", LOG_PID|LOG_CONS, LOG_USER);
    syslog(LOG_INFO, "DDR Reaper watchdog daemon starting");

    /* Set up signal handling */
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = signal_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT, &sa, NULL);

    /* Open watchdog device */
    if (watchdog_open() == -1) {
        syslog(LOG_ERR, "Failed to open watchdog device, continuing without hardware watchdog");
        /* We continue anyway, but without feeding */
    }

    /* Main loop */
    while (running) {
        time_t now = time(NULL);
        if (watchdog_fd != -1 && (now - last_feed) >= (WATCHDOG_TIMEOUT / 2)) {
            if (watchdog_feed() == -1) {
                /* If feeding fails, we might want to exit or try to reopen */
                syslog(LOG_ERR, "Failed to feed watchdog");
                watchdog_close();
                /* Try to reopen next time */
            } else {
                last_feed = now;
            }
        }
        sleep(1);
    }

    /* Cleanup */
    watchdog_close();
    closelog();
    return 0;
}