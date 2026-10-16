// RG353PS: RK3566, 640x480 DSI panel, mainline DRM/KMS and Panfrost.
#ifndef PLATFORM_H
#define PLATFORM_H

#ifdef SDL
# include "sdl.h"
#endif

extern int panel_w;
extern int panel_h;
extern double panel_fps;
extern int dev_has_lstick;
extern int dev_has_rstick;
extern int dev_has_rgb;
extern int dev_num_leds;
extern int needs_portrait_sdl;

#define BUTTON_UP       BUTTON_NA
#define BUTTON_DOWN     BUTTON_NA
#define BUTTON_LEFT     BUTTON_NA
#define BUTTON_RIGHT    BUTTON_NA
#define BUTTON_SELECT   BUTTON_NA
#define BUTTON_START    BUTTON_NA
#define BUTTON_A        BUTTON_NA
#define BUTTON_B        BUTTON_NA
#define BUTTON_X        BUTTON_NA
#define BUTTON_Y        BUTTON_NA
#define BUTTON_L1       BUTTON_NA
#define BUTTON_R1       BUTTON_NA
#define BUTTON_L2       BUTTON_NA
#define BUTTON_R2       BUTTON_NA
#define BUTTON_L3       BUTTON_NA
#define BUTTON_R3       BUTTON_NA
#define BUTTON_L4       BUTTON_NA
#define BUTTON_R4       BUTTON_NA
#define BUTTON_MENU     BUTTON_NA
#define BUTTON_MENU_ALT BUTTON_NA
#define BUTTON_POWER    116
#define BUTTON_PLUS     BUTTON_NA
#define BUTTON_MINUS    BUTTON_NA

// Built-in RK353PS evdev button codes. The face buttons deliberately use the
// Nintendo layout: right= A, bottom= B, top= X, left= Y.
#define CODE_UP         103
#define CODE_DOWN       108
#define CODE_LEFT       105
#define CODE_RIGHT      106
#define CODE_SELECT     314
#define CODE_START      315
#define CODE_A          305  // BTN_EAST
#define CODE_B          304  // BTN_SOUTH
#define CODE_X          307  // BTN_NORTH
#define CODE_Y          308  // BTN_WEST
#define CODE_L1         310  // BTN_TL
#define CODE_R1         311  // BTN_TR
#define CODE_L2         312  // BTN_TL2
#define CODE_R2         313  // BTN_TR2
#define CODE_L3         317  // BTN_THUMBL
#define CODE_R3         318  // BTN_THUMBR
#define CODE_L4         CODE_NA
#define CODE_R4         CODE_NA
#define CODE_MENU       316  // BTN_MODE
#define CODE_MENU_ALT   354
#define CODE_POWER      116
#define CODE_PLUS       115
#define CODE_MINUS      114

// External SDL joystick defaults; built-in keys are read via evdev.
#define JOY_UP          JOY_NA
#define JOY_DOWN        JOY_NA
#define JOY_LEFT        JOY_NA
#define JOY_RIGHT       JOY_NA
#define JOY_SELECT      6
#define JOY_START       7
#define JOY_A           0
#define JOY_B           1
#define JOY_X           3
#define JOY_Y           2
#define JOY_L1          4
#define JOY_R1          5
#define JOY_L2          10
#define JOY_R2          11
#define JOY_L4          JOY_NA
#define JOY_R4          JOY_NA
#define JOY_L3          (dev_has_lstick ? 9 : JOY_NA)
#define JOY_R3          (dev_has_rstick ? 12 : JOY_NA)
#define JOY_MENU        8
#define JOY_POWER       JOY_NA
#define JOY_PLUS        16
#define JOY_MINUS       15

// RG353PS has no dedicated FN buttons.
#define BTN_FN1         BTN_NONE
#define BTN_FN2         BTN_NONE
#define BTN_FN3         BTN_NONE
#define BTN_FN1_NAME    ""
#define BTN_FN2_NAME    ""
#define BTN_FN3_NAME    ""

#define AXIS_L2         AXIS_NA
#define AXIS_R2         AXIS_NA
#define AXIS_LX         (dev_has_lstick ? 0 : AXIS_NA)
#define AXIS_LY         (dev_has_lstick ? 1 : AXIS_NA)
#define AXIS_RX         (dev_has_rstick ? 2 : AXIS_NA)
#define AXIS_RY         (dev_has_rstick ? 3 : AXIS_NA)

#define BTN_RESUME          BTN_X
#define BTN_SLEEP           BTN_POWER
#define BTN_WAKE            BTN_POWER
#define BTN_MOD_VOLUME      BTN_NONE
#define BTN_MOD_BRIGHTNESS  BTN_MENU
#define BTN_MOD_COLORTEMP   BTN_SELECT
#define BTN_MOD_PLUS        BTN_PLUS
#define BTN_MOD_MINUS       BTN_MINUS

#define FIXED_SCALE     2
#define FIXED_WIDTH     panel_w
#define FIXED_HEIGHT    panel_h
#define FIXED_BPP       2
#define FIXED_DEPTH     (FIXED_BPP * 8)
#define FIXED_PITCH     (FIXED_WIDTH * FIXED_BPP)
#define FIXED_SIZE      (FIXED_PITCH * FIXED_HEIGHT)
#define MAIN_ROW_COUNT  6
#define QUICK_SWITCHER_COUNT 3
#define PADDING         10
#define SDCARD_PATH     "/mnt/SDCARD"
#define MUTE_VOLUME_RAW 0
#define SND_CLOSE_ON_SLEEP 0
#define SCREEN_FPS      panel_fps
#define MAX_LIGHTS      0

#endif
