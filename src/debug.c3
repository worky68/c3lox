module debug;

import std::io;
import chunk;
import opcode;
import value;
import object;

fn void disassembleChunk(Chunk* chunk, String name) {
  io::printfn("== %s ==", name);

  for (int offset = 0; offset < chunk.count;) {
    offset = disassembleInstruction(chunk, offset);
  }
}

fn int constantInstruction(String name, Chunk* chunk, int offset) {
  char constant = chunk.code[offset + 1];
  io::printf("%-16s %4d '", name, constant);
  value::printValue(chunk.constants.values[constant]);
  io::printf("'\n");

  return offset + 2;
}

fn int invokeInstruction(String name, Chunk* chunk, int offset) {
  char constant = chunk.code[offset + 1];
  char argCount = chunk.code[offset + 2];
  io::printf("%-16s (%d args) %4d '", name, argCount, constant);
  value::printValue(chunk.constants.values[constant]);
  io::printf("'\n");
  return offset + 3;
}

fn int simpleInstruction(String name, int offset) {
  io::printfn("%s", name);
  return offset + 1;
}

fn int byteInstruction(String name, Chunk* chunk, int offset) {
  char slot = chunk.code[offset + 1];
  io::printf("%-16s %4d\n", name, slot);
  return offset + 2; 
}

fn int jumpInstruction(String name, int sign, Chunk* chunk, int offset) {
  short jump = (short)(chunk.code[offset + 1] << 8);
  jump |= chunk.code[offset + 2];
  io::printf("%-16s %4d -> %d\n", name, offset, offset + 3 + sign * jump);
  return offset + 3;
}

fn int disassembleInstruction(Chunk* chunk, int offset) {
  io::printf("%04d ", offset);

  if (offset > 0 &&
      chunk.lines[offset] == chunk.lines[offset - 1]) {
    io::printf("| ");
  } else {
    io::printf("%d ", chunk.lines[offset]);
  }

  OpCode instruction = opcode::from(chunk.code[offset]);
  switch (instruction) {
    case OP_CONSTANT:
      return constantInstruction("OP_CONSTANT", chunk, offset);
    case OP_NIL:
      return simpleInstruction("OP_NIL", offset);
    case OP_TRUE:
      return simpleInstruction("OP_TRUE", offset);
    case OP_FALSE:
      return simpleInstruction("OP_FALSE", offset);
    case OP_POP:
      return simpleInstruction("OP_POP", offset);
    case OP_GET_LOCAL:
      return byteInstruction("OP_GET_LOCAL", chunk, offset);
    case OP_SET_LOCAL:
      return byteInstruction("OP_SET_LOCAL", chunk, offset);
    case OP_GET_GLOBAL:
      return constantInstruction("OP_GET_GLOBAL", chunk, offset);
    case OP_DEFINE_GLOBAL:
      return constantInstruction("OP_DEFINE_GLOBAL", chunk, offset);
    case OP_SET_GLOBAL:
      return constantInstruction("OP_SET_GLOBAL", chunk, offset);
    case OP_GET_UPVALUE:
      return byteInstruction("OP_GET_UPVALUE", chunk, offset);
    case OP_SET_UPVALUE:
      return byteInstruction("OP_SET_UPVALUE", chunk, offset);
    case OP_GET_PROPERTY:
      return constantInstruction("OP_GET_PROPERTY", chunk, offset);
    case OP_SET_PROPERTY:
      return constantInstruction("OP_SET_PROPERTY", chunk, offset);
    case OP_GET_SUPER:
      return constantInstruction("OP_GET_SUPER", chunk, offset);
    case OP_EQUAL:
      return simpleInstruction("OP_EQUAL", offset);
    case OP_GREATER:
      return simpleInstruction("OP_GREATER", offset);
    case OP_LESS:
      return simpleInstruction("OP_LESS", offset);
    case OP_ADD:
      return simpleInstruction("OP_ADD", offset);
    case OP_SUBTRACT:
      return simpleInstruction("OP_SUBTRACT", offset);
    case OP_MULTIPLY:
      return simpleInstruction("OP_MULTIPLY", offset);
    case OP_DIVIDE:
      return simpleInstruction("OP_DIVIDE", offset);
    case OP_NOT:
      return simpleInstruction("OP_NOT", offset);
    case OP_NEGATE:
      return simpleInstruction("OP_NEGATE", offset);
    case OP_JUMP:
      return jumpInstruction("OP_JUMP", 1, chunk, offset);
    case OP_JUMP_IF_FALSE:
      return jumpInstruction("OP_JUMP_IF_FALSE", 1, chunk, offset);
    case OP_LOOP:
      return jumpInstruction("OP_LOOP", -1, chunk, offset);
    case OP_CALL:
      return byteInstruction("OP_CALL", chunk, offset);
    case OP_INVOKE:
      return invokeInstruction("OP_INVOKE", chunk, offset);
    case OP_SUPER_INVOKE:
      return invokeInstruction("OP_SUPER_INVOKE", chunk, offset);
    case OP_CLOSURE: {
      offset++;
      char constant = chunk.code[offset++];
      io::printf("%-16s %4d ", "OP_CLOSURE", constant);
      value::printValue(chunk.constants.values[constant]);
      io::printf("\n");

      ObjFunction* function = object::as_function(chunk.constants.values[constant]);
      for (int j = 0; j < function.upvalueCount; j++) {
        int isLocal = chunk.code[offset++];
        int index = chunk.code[offset++];
        io::printf("%04d |                       %s %d\n", offset - 2, isLocal ? "local" : "upvalue", index);
      }

      return offset;
    }
    case OP_CLOSE_UPVALUE:
      return simpleInstruction("OP_CLOSE_UPVALUE", offset);
    case OP_RETURN:
      return simpleInstruction("OP_RETURN", offset);
    case OP_PRINT:
      return simpleInstruction("OP_PRINT", offset);
    case OP_CLASS:
      return constantInstruction("OP_CLASS", chunk, offset);
    case OP_INHERIT:
      return simpleInstruction("OP_INHERIT", offset);
    case OP_METHOD:
      return constantInstruction("OP_METHOD", chunk, offset);
    default:
      io::printfn("Unknown or unhandled opcode %s", instruction);
      return offset + 1;
  }
}