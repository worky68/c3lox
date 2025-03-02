module chunk;

import vm;
import value;
import memory;
import debug;

struct Chunk {
  int count;
  int capacity;
  char* code;
  int* lines;
  ValueArray constants;
}

fn void initChunk(Chunk* chunk) {
  chunk.count = 0;
  chunk.capacity = 0;
  chunk.code = null;
  chunk.lines = null;
  value::initValueArray(&chunk.constants);
}

fn void freeChunk(Chunk* chunk) {
  memory::free_array(char, chunk.code, chunk.capacity);
  memory::free_array(int, chunk.lines, chunk.capacity);
  value::freeValueArray(&chunk.constants);
  initChunk(chunk);
}

fn void writeChunk(Chunk* chunk, char byte, int line) {
    if (chunk.capacity < chunk.count + 1) {
    int oldCapacity = chunk.capacity;
    chunk.capacity = memory::grow_capacity(oldCapacity);
    chunk.code = memory::grow_array(char, chunk.code,
        oldCapacity, chunk.capacity);
    chunk.lines = memory::grow_array(int, chunk.lines,
        oldCapacity, chunk.capacity);
  }

  chunk.code[chunk.count] = byte;
  chunk.lines[chunk.count] = line;
  chunk.count++;
}

fn int addConstant(Chunk* chunk, Value value) {
  vm::push(value);
  value::writeValueArray(&chunk.constants, value);
  vm::pop();
  return chunk.constants.count - 1;
}