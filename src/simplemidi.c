#include "simplemidi.h"
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define MIDI_DEVICE "/dev/snd/midiC3D0"

pthread_t midiInThread;
int fd;

void *threadFunction();

// Global variable for easy access
SharedData shared;

// Function to safely read the current value
int getCurrentValue() {
    int value;
    pthread_mutex_lock(&shared.mutex);
    value = shared.currentValue;
    pthread_mutex_unlock(&shared.mutex);
    return value;
}

int start_midi(void) {

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
      printf("MIDI message: ");
      for (int i = 0; i < bytes_read; i++) {
        printf("%02X ", buffer[i]);
      }
      printf("\n");

      // Interpret MIDI message
      if ((buffer[0] & 0xF0) == 0x90) {
pthread_mutex_lock(&shared.mutex);
        shared.currentValue = buffer[1];
        printf("Note On - Note: %d, Velocity: %d\n", buffer[1], buffer[2]);
pthread_mutex_unlock(&shared.mutex);
      } else if ((buffer[0] & 0xF0) == 0x80) {
pthread_mutex_lock(&shared.mutex);
        shared.currentValue = buffer[1];
        printf("Note Off - Note: %d, Velocity: %d\n", buffer[1], buffer[2]);
pthread_mutex_unlock(&shared.mutex);
      }
    }
  }
}
