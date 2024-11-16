#include "simplemidi.h"
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define MIDI_DEVICE "/dev/snd/midiC3D0"

pthread_t midiInThread;
int fd;

extern void parseKeyMap();
void *threadFunction();
int KEYBOARDSIZE = 120;
// Global variable for easy access
SharedData shared;

KeyData keydata;

int getCurrentKeyValue(int i) {
  if (i < 0 || i >= KEYBOARDSIZE) { // Check bounds against known array size
    return -1;                      // Error for invalid index
  }
  return keydata.keys[i] ? 1 : 0; // Convert bool to int
}

void printKeyState(bool *keys) {
  int i, value;
  for (i = 0; i < KEYBOARDSIZE; i++) { // Use known array size
    value = getCurrentKeyValue(i);
    printf("%d", value);
  }
}

int updateKeyState(int i, bool state) {
  if (i < 0 || i >= KEYBOARDSIZE) {
    return -1;
  }

  keydata.keys[i] = state;

  return 1;
}

// Function to safely read the current value
int getCurrentValue() {
  int value;
  value = shared.currentValue;
  return value;
}

int start_midi(void) {
  // Initialize all keys to false
  for (int i = 0; i < 49; i++) {
    keydata.keys[i] = false;
  }
  // Initialize the mutex
  int result = pthread_mutex_init(&keydata.mutex, NULL);
  if (result != 0) {
    // Handle mutex initialization error
    return -1;
  }

  // Open the MIDI device
  fd = open(MIDI_DEVICE, O_RDONLY);
  if (fd < 0) {
    perror("Error opening MIDI device");
    return 1;
  }

  /*start tread*/
  int status;
  status = pthread_create(&midiInThread, NULL, threadFunction, NULL);
  if (status == -1) {
    printf("Unable to create thread\n");
    exit(1);
  }

  printf("Reading MIDI input from %s...\n", MIDI_DEVICE);

  return 0;
}

void *threadFunction(void *x) {

  ssize_t bytes_read;
  unsigned char buffer[3]; // Standard MIDI message is 3 bytes
  int status;

  printf("Thread id = %lu", pthread_self());

  while (1) {
    bytes_read = read(fd, buffer, sizeof(buffer));
    if (bytes_read > 0) {
      for (int i = 0; i < bytes_read; i++) {
      }

      // Interpret MIDI message
      if ((buffer[0] & 0xF0) == 0x90) {
        pthread_mutex_lock(&keydata.mutex);
        updateKeyState(buffer[1], true);
        parseKeyMap(&keydata.keys);
        pthread_mutex_unlock(&keydata.mutex);
        printf("\n");
      } else if ((buffer[0] & 0xF0) == 0x80) {
        pthread_mutex_lock(&keydata.mutex);
        updateKeyState(buffer[1], false);
        parseKeyMap(&keydata.keys);
        pthread_mutex_unlock(&keydata.mutex);
        printf("\n");
      }
    }
  }
}
