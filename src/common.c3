module common;

import std::io;

const UINT8_MAX = 255;

// TODO remove?
fn void fprintf(OutStream stream, char* message, int length) {
  for(int i = 0; i < length; i++) {
    io::fprintf(stream, "%c", message[i])!!; // TODO handle error gracefully
  }
}
