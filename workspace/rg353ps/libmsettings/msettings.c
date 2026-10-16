#define _DEFAULT_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <dirent.h>
#include <msettings.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

typedef struct Settings {
    int version;
    int brightness;
    int colortemperature;
    int headphones;
    int speaker;
    int contrast;
    int saturation;
    int exposure;
    int unused[2];
    int jack;
    int audiosink;
    int displaycal_enabled;
    int displaycal_red_gain;
    int displaycal_green_gain;
    int displaycal_blue_gain;
} Settings;

#define SETTINGS_VERSION 1
#define SHM_KEY "/SharedSettings"

static Settings defaults = {
    .version = SETTINGS_VERSION,
    .brightness = SETTINGS_DEFAULT_BRIGHTNESS,
    .colortemperature = SETTINGS_DEFAULT_COLORTEMP,
    .headphones = SETTINGS_DEFAULT_HEADPHONE_VOLUME,
    .speaker = SETTINGS_DEFAULT_VOLUME,
    .contrast = SETTINGS_DEFAULT_CONTRAST,
    .saturation = SETTINGS_DEFAULT_SATURATION,
    .exposure = SETTINGS_DEFAULT_EXPOSURE,
    .jack = 0,
    .audiosink = AUDIO_SINK_DEFAULT,
    .displaycal_enabled = 0,
    .displaycal_red_gain = 100,
    .displaycal_green_gain = 100,
    .displaycal_blue_gain = 100
};

static Settings *settings;
static int shared_fd = -1;
static int shared_owner;
static int mapped_shared;
static char settings_path[512];

static int clamp(int value, int low, int high)
{
    if (value < low) return low;
    if (value > high) return high;
    return value;
}

static void save_settings(void)
{
    if (!settings || !settings_path[0]) return;
    int fd = open(settings_path, O_CREAT | O_WRONLY | O_TRUNC | O_CLOEXEC, 0644);
    if (fd < 0) return;
    ssize_t written = write(fd, settings, sizeof(*settings));
    (void)written;
    fsync(fd);
    close(fd);
}

static void load_settings(void)
{
    int fd = open(settings_path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return;
    Settings saved;
    ssize_t n = read(fd, &saved, sizeof(saved));
    char extra;
    ssize_t extra_n = read(fd, &extra, 1);
    close(fd);
    if (n == (ssize_t)sizeof(saved) && extra_n == 0
        && saved.version == SETTINGS_VERSION) {
        memcpy(settings, &saved, sizeof(saved));
    }
}

static int find_backlight(char *path, size_t path_size)
{
    const char *root = "/sys/class/backlight";
    char candidate[256];
    snprintf(candidate, sizeof(candidate), "%s/backlight0/brightness", root);
    if (access(candidate, W_OK) == 0) {
        snprintf(path, path_size, "%s", candidate);
        return 1;
    }

    DIR *dir = opendir(root);
    if (!dir) return 0;
    struct dirent *entry;
    int found = 0;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] == '.') continue;
        snprintf(candidate, sizeof(candidate), "%s/%s/brightness", root, entry->d_name);
        if (access(candidate, W_OK) == 0) {
            snprintf(path, path_size, "%s", candidate);
            found = 1;
            break;
        }
    }
    closedir(dir);
    return found;
}

static int read_int_file(const char *path, int fallback)
{
    FILE *fp = fopen(path, "r");
    if (!fp) return fallback;
    int value = fallback;
    if (fscanf(fp, "%d", &value) != 1) value = fallback;
    fclose(fp);
    return value;
}

void InitSettings(void)
{
    const char *userdata = getenv("USERDATA_PATH");
    if (!userdata || !userdata[0]) userdata = "/mnt/SDCARD/.userdata/rg353ps";
    snprintf(settings_path, sizeof(settings_path), "%s/msettings.bin", userdata);

    shared_fd = shm_open(SHM_KEY, O_RDWR | O_CREAT | O_EXCL, 0644);
    if (shared_fd >= 0) {
        shared_owner = 1;
        if (ftruncate(shared_fd, (off_t)sizeof(Settings)) == 0) {
            settings = mmap(NULL, sizeof(Settings), PROT_READ | PROT_WRITE,
                            MAP_SHARED, shared_fd, 0);
            if (settings != MAP_FAILED) {
                mapped_shared = 1;
                memcpy(settings, &defaults, sizeof(defaults));
                load_settings();
            } else {
                settings = NULL;
            }
        }
    } else if (errno == EEXIST) {
        shared_fd = shm_open(SHM_KEY, O_RDWR, 0644);
        if (shared_fd >= 0) {
            settings = mmap(NULL, sizeof(Settings), PROT_READ | PROT_WRITE,
                            MAP_SHARED, shared_fd, 0);
            if (settings == MAP_FAILED) settings = NULL;
            else mapped_shared = 1;
        }
    }

    if (!settings) {
        // The UI can still run on a system where /dev/shm is not mounted; it
        // simply falls back to process-local settings until BaseOS fixes it.
        settings = calloc(1, sizeof(Settings));
        if (!settings) return;
        memcpy(settings, &defaults, sizeof(defaults));
        load_settings();
    }

    SetBrightness(GetBrightness());
    SetColortemp(GetColortemp());
    SetContrast(GetContrast());
    SetSaturation(GetSaturation());
    SetExposure(GetExposure());
    SetVolume(GetVolume());
}

int InitializedSettings(void)
{
    return settings != NULL;
}

void QuitSettings(void)
{
    if (!settings) return;
    save_settings();
    if (mapped_shared) munmap(settings, sizeof(Settings));
    else free(settings);
    settings = NULL;
    if (shared_fd >= 0) close(shared_fd);
    shared_fd = -1;
    if (shared_owner) shm_unlink(SHM_KEY);
    shared_owner = 0;
    mapped_shared = 0;
}

int GetBrightness(void) { return settings ? settings->brightness : SETTINGS_DEFAULT_BRIGHTNESS; }
int GetColortemp(void) { return settings ? settings->colortemperature : SETTINGS_DEFAULT_COLORTEMP; }
int GetContrast(void) { return settings ? settings->contrast : SETTINGS_DEFAULT_CONTRAST; }
int GetSaturation(void) { return settings ? settings->saturation : SETTINGS_DEFAULT_SATURATION; }
int GetExposure(void) { return settings ? settings->exposure : SETTINGS_DEFAULT_EXPOSURE; }
int GetDisplayCalEnabled(void) { return settings ? settings->displaycal_enabled : 0; }
int GetDisplayCalRedGain(void) { return settings ? settings->displaycal_red_gain : 100; }
int GetDisplayCalGreenGain(void) { return settings ? settings->displaycal_green_gain : 100; }
int GetDisplayCalBlueGain(void) { return settings ? settings->displaycal_blue_gain : 100; }
int GetVolume(void)
{
    if (!settings) return SETTINGS_DEFAULT_VOLUME;
    return (settings->jack || settings->audiosink != AUDIO_SINK_DEFAULT)
        ? settings->headphones : settings->speaker;
}
int GetJack(void) { return settings ? settings->jack : 0; }
int GetAudioSink(void) { return settings ? settings->audiosink : AUDIO_SINK_DEFAULT; }
int GetHDMI(void) { return 0; }
void SetHDMI(int value) { (void)value; }

void SetRawBrightness(int value)
{
    char path[512];
    if (!find_backlight(path, sizeof(path))) return;
    char max_path[640];
    snprintf(max_path, sizeof(max_path), "%s", path);
    char *slash = strrchr(max_path, '/');
    if (!slash) return;
    strcpy(slash + 1, "max_brightness");
    int maximum = read_int_file(max_path, 255);
    if (maximum < 1) maximum = 255;
    int raw = clamp(value, 0, 255) * maximum / 255;
    FILE *fp = fopen(path, "w");
    if (!fp) return;
    fprintf(fp, "%d\n", raw);
    fclose(fp);
}

void SetRawColortemp(int value) { (void)value; }
void SetRawContrast(int value) { (void)value; }
void SetRawSaturation(int value) { (void)value; }
void SetRawExposure(int value) { (void)value; }
void SetRawDisplayCal(int enabled, int red, int green, int blue)
{
    (void)enabled; (void)red; (void)green; (void)blue;
}

static int find_rk817_audio_card(void)
{
    const char *configured = getenv("BASEOS_AUDIO_CARD");
    if (configured && configured[0]) {
        char *end = NULL;
        long card = strtol(configured, &end, 10);
        if (end && *end == '\0' && card >= 0 && card <= 31)
            return (int)card;
    }

    FILE *fp = fopen("/proc/asound/cards", "r");
    if (!fp)
        return -1;

    char line[256];
    int card = -1;
    while (fgets(line, sizeof(line), fp)) {
        if (!strstr(line, "rk817ext") && !strstr(line, "rk817_ext"))
            continue;
        char *end = NULL;
        long parsed = strtol(line, &end, 10);
        if (end != line && parsed >= 0 && parsed <= 31)
            card = (int)parsed;
        break;
    }
    fclose(fp);
    return card;
}

void SetRawVolume(int value)
{
    value = clamp(value, 0, 100);
    char command[320];
    int card = find_rk817_audio_card();

    // RG353PS enumerates HDMI before the RK817 codec. Target the internal
    // codec explicitly and change playback only, never capture gain.
    if (card >= 0) {
        snprintf(command, sizeof(command),
            "amixer -q -c %d sset Master playback %d%% >/dev/null 2>&1 || "
            "amixer -q -c %d sset PCM playback %d%% >/dev/null 2>&1 || "
            "amixer -q -c %d sset 'Playback Volume' %d%% playback >/dev/null 2>&1",
            card, value, card, value, card, value);
        if (system(command) == 0)
            return;
    }

    // A fallback keeps the settings API useful on an alternative sound card,
    // but still selects the playback stream rather than a capture element.
    snprintf(command, sizeof(command),
        "amixer -q sset Master playback %d%% >/dev/null 2>&1",
        value);
    (void)system(command);
}

void SetBrightness(int value)
{
    if (!settings) return;
    value = clamp(value, 0, 10);
    settings->brightness = value;
    SetRawBrightness(value * 255 / 10);
    save_settings();
}
void SetColortemp(int value)
{
    if (!settings) return;
    settings->colortemperature = clamp(value, 0, 40);
    save_settings();
}
void SetContrast(int value)
{
    if (!settings) return;
    settings->contrast = clamp(value, -4, 5);
    save_settings();
}
void SetSaturation(int value)
{
    if (!settings) return;
    settings->saturation = clamp(value, -5, 5);
    save_settings();
}
void SetExposure(int value)
{
    if (!settings) return;
    settings->exposure = clamp(value, -4, 5);
    save_settings();
}
void SetDisplayCalEnabled(int value)
{
    if (!settings) return;
    settings->displaycal_enabled = value != 0;
    save_settings();
}
void SetDisplayCalRedGain(int value)
{
    if (!settings) return;
    settings->displaycal_red_gain = clamp(value, 0, 200);
    save_settings();
}
void SetDisplayCalGreenGain(int value)
{
    if (!settings) return;
    settings->displaycal_green_gain = clamp(value, 0, 200);
    save_settings();
}
void SetDisplayCalBlueGain(int value)
{
    if (!settings) return;
    settings->displaycal_blue_gain = clamp(value, 0, 200);
    save_settings();
}
void SetVolume(int value)
{
    if (!settings) return;
    value = clamp(value, 0, 20);
    if (settings->jack || settings->audiosink != AUDIO_SINK_DEFAULT)
        settings->headphones = value;
    else
        settings->speaker = value;
    SetRawVolume(value * 5);
    save_settings();
}
void SetJack(int value)
{
    if (!settings) return;
    settings->jack = value != 0;
    SetVolume(GetVolume());
}
void SetAudioSink(int value)
{
    if (!settings) return;
    if (value < AUDIO_SINK_DEFAULT || value > AUDIO_SINK_USBDAC)
        value = AUDIO_SINK_DEFAULT;
    settings->audiosink = value;
    SetVolume(GetVolume());
}
