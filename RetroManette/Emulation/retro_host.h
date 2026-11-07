// A small libretro frontend written in C. It loads a game into the statically linked core (mGBA), runs frames, collects
// the picture and sound, and keeps button state. The Swift code (EmulatorSession) calls these functions from ONE thread
// (the emulation thread), except rh_set_button / rh_copy_frame / rh_audio_pop / rh_audio_fill which are safe to call
// from the main thread and the audio thread.
#ifndef RETRO_HOST_H
#define RETRO_HOST_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define RH_AUDIO_RATE 48000

typedef struct {
    int width;          // size of the picture the core produces
    int height;
    double aspect;      // display aspect ratio (width / height)
    double fps;         // frames per second the core wants
} rh_info;

// 0 = ok, -1 = cannot read the file, -2 = the core refused the game, -3 = out of memory
int  rh_open(const char *rom_path, const char *system_dir, const char *save_dir);
void rh_close(void);
int  rh_is_open(void);

void rh_run(void);      // one frame
void rh_reset(void);
rh_info rh_get_info(void);

// RetroPad button numbers: B=0 Y=1 Select=2 Start=3 Up=4 Down=5 Left=6 Right=7 A=8 X=9 L=10 R=11
void rh_set_button(unsigned id, int pressed);

// Copies the newest finished frame as 32-bit (B, G, R, unused) pixels into dst. Returns the frame counter (it grows with
// every new frame; 0 = nothing yet) and the picture size.
uint64_t rh_copy_frame(uint8_t *dst, size_t capacity, int *width, int *height);

// Sound is resampled to 48000 Hz stereo. rh_audio_pop fills `frames` stereo frames (missing ones are silence).
size_t rh_audio_pop(int16_t *out, size_t frames);
size_t rh_audio_fill(void);   // frames waiting in the buffer

size_t rh_state_size(void);
int    rh_state_save(void *buffer, size_t size);          // 1 = ok
int    rh_state_load(const void *buffer, size_t size);    // 1 = ok

int    rh_sram_load(const char *path);                    // 1 = loaded something
int    rh_sram_save(const char *path);                    // 1 = written

#ifdef __cplusplus
}
#endif

#endif
