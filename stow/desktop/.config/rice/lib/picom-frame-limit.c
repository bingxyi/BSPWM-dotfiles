/* Per-process GLX/EGL frame ceiling for Picom's libepoxy presentation path.
 * Loaded only by animation_settings.py, never exported to the desktop session.
 * No graphics headers or driver changes are required. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

typedef void (*glx_swap)(void *, unsigned long);
typedef unsigned int (*egl_swap)(void *, void *);
static glx_swap *glx_slot, glx_real;
static egl_swap *egl_slot, egl_real;
static long period_ns;
static _Thread_local long long next_frame;
static _Thread_local long long first_frame;
static _Thread_local unsigned long frame_count;

static long long now_ns(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (long long)t.tv_sec * 1000000000LL + t.tv_nsec;
}

static void pace(void) {
    if (!period_ns) return;
    long long now = now_ns();
    if (next_frame > now) {
        struct timespec target = {next_frame / 1000000000LL, next_frame % 1000000000LL};
        while (clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &target, NULL) == EINTR) {}
        now = now_ns();
    }
    next_frame = now + period_ns;
    /* Optional sampling for verification, off during normal use. */
    const char *stats = getenv("RICE_PICOM_FRAME_STATS");
    if (stats) {
        if (!first_frame) first_frame = now;
        ++frame_count;
        if (frame_count > 1 && frame_count % 60 == 0) {
            FILE *f = fopen(stats, "w");
            if (f) {
                fprintf(f, "{\"frames\":%lu,\"fps\":%.3f}\n", frame_count,
                        (frame_count - 1) * 1e9 / (double)(now - first_frame));
                fclose(f);
            }
        }
    }
}

static void limited_glx(void *display, unsigned long drawable) {
    pace();
    glx_swap target = glx_real;
    target(display, drawable);
    /* libepoxy resolves its dispatch slot lazily on the first call. Preserve
       the resolved driver entry, then keep the limiter in that dispatch slot. */
    if (*glx_slot != limited_glx) glx_real = *glx_slot;
    *glx_slot = limited_glx;
}

static unsigned int limited_egl(void *display, void *surface) {
    pace();
    egl_swap target = egl_real;
    unsigned int result = target(display, surface);
    if (*egl_slot != limited_egl) egl_real = *egl_slot;
    *egl_slot = limited_egl;
    return result;
}

__attribute__((constructor)) static void initialize(void) {
    const char *value = getenv("RICE_PICOM_FPS");
    if (!value) return;
    char *end;
    long fps = strtol(value, &end, 10);
    if (*end || fps < 15 || fps > 240) return;
    period_ns = 1000000000L / fps;
    glx_slot = (glx_swap *)dlsym(RTLD_DEFAULT, "epoxy_glXSwapBuffers");
    egl_slot = (egl_swap *)dlsym(RTLD_DEFAULT, "epoxy_eglSwapBuffers");
    if (glx_slot && *glx_slot) {glx_real = *glx_slot; *glx_slot = limited_glx;}
    if (egl_slot && *egl_slot) {egl_real = *egl_slot; *egl_slot = limited_egl;}
}
