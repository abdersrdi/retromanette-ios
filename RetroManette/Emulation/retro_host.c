#include "retro_host.h"
#include "libretro.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define AUDIO_CAPACITY 48000   // frames (one second)

static struct {
    int open;
    unsigned pixel_format;
    char *system_dir;
    char *save_dir;
    uint8_t *rom;
    size_t rom_size;

    rh_info info;
    double in_rate;

    // video: the emulation thread writes `back`, then swaps it with `front` under the lock
    pthread_mutex_t video_lock;
    uint8_t *front;
    uint8_t *back;
    size_t video_capacity;
    int front_w, front_h;
    uint64_t frame_counter;

    // audio: single producer (emulation thread), single consumer (audio thread)
    int16_t audio[AUDIO_CAPACITY * 2];
    atomic_size_t audio_write;
    atomic_size_t audio_read;
    double phase;
    double step;
    int16_t prev_l, prev_r;

    atomic_int buttons[16];
} g = { .video_lock = PTHREAD_MUTEX_INITIALIZER };

// ---------------------------------------------------------------------------------------------------------------------
// video

static void ensure_video(size_t bytes) {
    if (bytes <= g.video_capacity) return;
    pthread_mutex_lock(&g.video_lock);
    free(g.front);
    free(g.back);
    g.front = calloc(1, bytes);
    g.back = calloc(1, bytes);
    g.video_capacity = g.front && g.back ? bytes : 0;
    pthread_mutex_unlock(&g.video_lock);
}

static void video_refresh(const void *data, unsigned width, unsigned height, size_t pitch) {
    if (!data || width == 0 || height == 0) return;          // the core repeats the last frame
    size_t bytes = (size_t)width * height * 4;
    ensure_video(bytes);
    if (!g.back) return;

    for (unsigned y = 0; y < height; y++) {
        const uint8_t *src = (const uint8_t *)data + y * pitch;
        uint32_t *dst = (uint32_t *)(g.back + (size_t)y * width * 4);
        if (g.pixel_format == RETRO_PIXEL_FORMAT_XRGB8888) {
            memcpy(dst, src, (size_t)width * 4);
        } else if (g.pixel_format == RETRO_PIXEL_FORMAT_RGB565) {
            const uint16_t *s = (const uint16_t *)src;
            for (unsigned x = 0; x < width; x++) {
                uint32_t p = s[x];
                uint32_t r = (p >> 11) & 0x1F, gr = (p >> 5) & 0x3F, b = p & 0x1F;
                r = (r << 3) | (r >> 2);
                gr = (gr << 2) | (gr >> 4);
                b = (b << 3) | (b >> 2);
                dst[x] = 0xFF000000u | (r << 16) | (gr << 8) | b;
            }
        } else {   // 0RGB1555
            const uint16_t *s = (const uint16_t *)src;
            for (unsigned x = 0; x < width; x++) {
                uint32_t p = s[x];
                uint32_t r = (p >> 10) & 0x1F, gr = (p >> 5) & 0x1F, b = p & 0x1F;
                r = (r << 3) | (r >> 2);
                gr = (gr << 3) | (gr >> 2);
                b = (b << 3) | (b >> 2);
                dst[x] = 0xFF000000u | (r << 16) | (gr << 8) | b;
            }
        }
    }

    pthread_mutex_lock(&g.video_lock);
    uint8_t *tmp = g.front;
    g.front = g.back;
    g.back = tmp;
    g.front_w = (int)width;
    g.front_h = (int)height;
    g.frame_counter++;
    pthread_mutex_unlock(&g.video_lock);
}

uint64_t rh_copy_frame(uint8_t *dst, size_t capacity, int *width, int *height) {
    uint64_t counter = 0;
    pthread_mutex_lock(&g.video_lock);
    size_t bytes = (size_t)g.front_w * g.front_h * 4;
    if (g.front && g.frame_counter > 0 && bytes <= capacity) {
        memcpy(dst, g.front, bytes);
        if (width) *width = g.front_w;
        if (height) *height = g.front_h;
        counter = g.frame_counter;
    }
    pthread_mutex_unlock(&g.video_lock);
    return counter;
}

// ---------------------------------------------------------------------------------------------------------------------
// audio

static void push_audio(int16_t l, int16_t r) {
    size_t w = atomic_load_explicit(&g.audio_write, memory_order_relaxed);
    size_t rd = atomic_load_explicit(&g.audio_read, memory_order_acquire);
    if (w - rd >= AUDIO_CAPACITY) return;                    // full: drop (only happens while fast-forwarding)
    size_t i = (w % AUDIO_CAPACITY) * 2;
    g.audio[i] = l;
    g.audio[i + 1] = r;
    atomic_store_explicit(&g.audio_write, w + 1, memory_order_release);
}

static size_t audio_batch(const int16_t *data, size_t frames) {
    for (size_t i = 0; i < frames; i++) {
        int16_t cl = data[i * 2], cr = data[i * 2 + 1];
        while (g.phase < 1.0) {                              // linear resampling from the core's rate to 48000 Hz
            double t = g.phase;
            push_audio((int16_t)(g.prev_l + (cl - g.prev_l) * t), (int16_t)(g.prev_r + (cr - g.prev_r) * t));
            g.phase += g.step;
        }
        g.phase -= 1.0;
        g.prev_l = cl;
        g.prev_r = cr;
    }
    return frames;
}

static void audio_sample(int16_t l, int16_t r) {
    int16_t pair[2] = { l, r };
    audio_batch(pair, 1);
}

size_t rh_audio_fill(void) {
    return atomic_load_explicit(&g.audio_write, memory_order_acquire) - atomic_load_explicit(&g.audio_read, memory_order_acquire);
}

size_t rh_audio_pop(int16_t *out, size_t frames) {
    size_t rd = atomic_load_explicit(&g.audio_read, memory_order_relaxed);
    size_t wr = atomic_load_explicit(&g.audio_write, memory_order_acquire);
    size_t avail = wr - rd;
    size_t n = avail < frames ? avail : frames;
    for (size_t i = 0; i < n; i++) {
        size_t k = ((rd + i) % AUDIO_CAPACITY) * 2;
        out[i * 2] = g.audio[k];
        out[i * 2 + 1] = g.audio[k + 1];
    }
    for (size_t i = n; i < frames; i++) { out[i * 2] = 0; out[i * 2 + 1] = 0; }
    atomic_store_explicit(&g.audio_read, rd + n, memory_order_release);
    return n;
}

// ---------------------------------------------------------------------------------------------------------------------
// input

void rh_set_button(unsigned id, int pressed) {
    if (id < 16) atomic_store_explicit(&g.buttons[id], pressed ? 1 : 0, memory_order_relaxed);
}

static void input_poll(void) {}

static int16_t input_state(unsigned port, unsigned device, unsigned index, unsigned id) {
    (void)index;
    if (port != 0 || device != RETRO_DEVICE_JOYPAD) return 0;
    if (id == RETRO_DEVICE_ID_JOYPAD_MASK) {
        int16_t mask = 0;
        for (unsigned i = 0; i < 16; i++) if (atomic_load_explicit(&g.buttons[i], memory_order_relaxed)) mask |= (int16_t)(1 << i);
        return mask;
    }
    return id < 16 ? (int16_t)atomic_load_explicit(&g.buttons[id], memory_order_relaxed) : 0;
}

// ---------------------------------------------------------------------------------------------------------------------
// environment

static void update_info(const struct retro_system_av_info *av) {
    g.info.width = (int)av->geometry.base_width;
    g.info.height = (int)av->geometry.base_height;
    g.info.aspect = av->geometry.aspect_ratio > 0 ? av->geometry.aspect_ratio : (double)av->geometry.base_width / (double)av->geometry.base_height;
    g.info.fps = av->timing.fps > 1 ? av->timing.fps : 60.0;
    g.in_rate = av->timing.sample_rate > 1000 ? av->timing.sample_rate : 32768.0;
    g.step = g.in_rate / (double)RH_AUDIO_RATE;
}

static bool environment(unsigned cmd, void *data) {
    switch (cmd) {
        case RETRO_ENVIRONMENT_GET_CAN_DUPE:
            *(bool *)data = true;
            return true;
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
            unsigned fmt = *(const unsigned *)data;
            if (fmt == RETRO_PIXEL_FORMAT_XRGB8888 || fmt == RETRO_PIXEL_FORMAT_RGB565 || fmt == RETRO_PIXEL_FORMAT_0RGB1555) {
                g.pixel_format = fmt;
                return true;
            }
            return false;
        }
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
            *(const char **)data = g.system_dir ? g.system_dir : ".";
            return true;
        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
            *(const char **)data = g.save_dir ? g.save_dir : ".";
            return true;
        case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION:
            *(unsigned *)data = 0;                           // legacy option list: the core keeps its defaults
            return true;
        case RETRO_ENVIRONMENT_GET_LANGUAGE:
            *(unsigned *)data = RETRO_LANGUAGE_ENGLISH;
            return true;
        case RETRO_ENVIRONMENT_SET_GEOMETRY: {
            const struct retro_game_geometry *geo = (const struct retro_game_geometry *)data;
            g.info.width = (int)geo->base_width;
            g.info.height = (int)geo->base_height;
            if (geo->aspect_ratio > 0) g.info.aspect = geo->aspect_ratio;
            return true;
        }
        case RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO:
            update_info((const struct retro_system_av_info *)data);
            return true;
        case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
        case RETRO_ENVIRONMENT_SET_VARIABLES:
        case RETRO_ENVIRONMENT_SET_MEMORY_MAPS:
        case RETRO_ENVIRONMENT_SET_SERIALIZATION_QUIRKS:
        case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:
        case RETRO_ENVIRONMENT_SET_SUPPORT_ACHIEVEMENTS:
        case RETRO_ENVIRONMENT_SET_ROTATION:
            return true;
        default:
            return false;                                    // variables, logging, VFS, hardware rendering, ...: not offered
    }
}

// ---------------------------------------------------------------------------------------------------------------------
// life cycle

static char *dup_string(const char *s) {
    if (!s) return NULL;
    size_t n = strlen(s) + 1;
    char *p = malloc(n);
    if (p) memcpy(p, s, n);
    return p;
}

int rh_open(const char *rom_path, const char *system_dir, const char *save_dir) {
    if (g.open) rh_close();

    FILE *f = fopen(rom_path, "rb");
    if (!f) return -1;
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (size <= 0) { fclose(f); return -1; }
    uint8_t *rom = malloc((size_t)size);
    if (!rom) { fclose(f); return -3; }
    if (fread(rom, 1, (size_t)size, f) != (size_t)size) { fclose(f); free(rom); return -1; }
    fclose(f);

    g.rom = rom;
    g.rom_size = (size_t)size;
    g.system_dir = dup_string(system_dir);
    g.save_dir = dup_string(save_dir);
    g.pixel_format = RETRO_PIXEL_FORMAT_0RGB1555;
    g.phase = 0;
    g.prev_l = g.prev_r = 0;
    g.frame_counter = 0;
    g.front_w = g.front_h = 0;
    atomic_store(&g.audio_write, 0);
    atomic_store(&g.audio_read, 0);
    for (int i = 0; i < 16; i++) atomic_store(&g.buttons[i], 0);

    retro_set_environment(environment);
    retro_init();
    retro_set_video_refresh(video_refresh);
    retro_set_audio_sample(audio_sample);
    retro_set_audio_sample_batch(audio_batch);
    retro_set_input_poll(input_poll);
    retro_set_input_state(input_state);

    struct retro_game_info game = { rom_path, g.rom, g.rom_size, NULL };
    if (!retro_load_game(&game)) {
        retro_deinit();
        free(g.rom); g.rom = NULL;
        free(g.system_dir); g.system_dir = NULL;
        free(g.save_dir); g.save_dir = NULL;
        return -2;
    }

    struct retro_system_av_info av;
    memset(&av, 0, sizeof av);
    retro_get_system_av_info(&av);
    update_info(&av);
    retro_set_controller_port_device(0, RETRO_DEVICE_JOYPAD);
    g.open = 1;
    return 0;
}

void rh_close(void) {
    if (!g.open) return;
    retro_unload_game();
    retro_deinit();
    g.open = 0;
    free(g.rom); g.rom = NULL;
    free(g.system_dir); g.system_dir = NULL;
    free(g.save_dir); g.save_dir = NULL;
}

int rh_is_open(void) { return g.open; }
void rh_run(void) { if (g.open) retro_run(); }
void rh_reset(void) { if (g.open) retro_reset(); }
rh_info rh_get_info(void) { return g.info; }

// ---------------------------------------------------------------------------------------------------------------------
// save states and battery saves

size_t rh_state_size(void) { return g.open ? retro_serialize_size() : 0; }

int rh_state_save(void *buffer, size_t size) { return g.open && retro_serialize(buffer, size) ? 1 : 0; }
int rh_state_load(const void *buffer, size_t size) { return g.open && retro_unserialize(buffer, size) ? 1 : 0; }

int rh_sram_load(const char *path) {
    if (!g.open) return 0;
    size_t size = retro_get_memory_size(RETRO_MEMORY_SAVE_RAM);
    void *ram = retro_get_memory_data(RETRO_MEMORY_SAVE_RAM);
    if (!ram || size == 0) return 0;
    FILE *f = fopen(path, "rb");
    if (!f) return 0;
    size_t n = fread(ram, 1, size, f);
    fclose(f);
    return n > 0;
}

int rh_sram_save(const char *path) {
    if (!g.open) return 0;
    size_t size = retro_get_memory_size(RETRO_MEMORY_SAVE_RAM);
    void *ram = retro_get_memory_data(RETRO_MEMORY_SAVE_RAM);
    if (!ram || size == 0) return 0;
    FILE *f = fopen(path, "wb");
    if (!f) return 0;
    size_t n = fwrite(ram, 1, size, f);
    fclose(f);
    return n == size;
}
