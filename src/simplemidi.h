#include <pthread.h>
#include <stdatomic.h>  // Add this for _Atomic
#include <stdbool.h>
#ifndef SIMPLEMIDI_H
#define SIMPLEMIDI_H

// Use a simple int with a mutex for thread safety
typedef struct SharedData {
    int currentValue;
    pthread_mutex_t mutex;
} SharedData;

typedef struct KeyData {
    bool keys[120];
    pthread_mutex_t mutex;
} KeyData;


// Function declarations
int start_midi(void);

// If you need to expose these variables to other files, declare them as extern
extern pthread_t midiInThread;
extern int fd;
extern SharedData shared;
extern KeyData keydata;
#endif // SIMPLEMIDI_H
