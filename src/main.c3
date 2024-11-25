module lox;

import std::io;
import std::core::mem;

import vm;
import chunk;
import value;
import debug;

fn void repl() {

  for(;;) {
    @pool() {
      io::printf("> ");
      String line = io::treadline()!!; // TODO handle errors gracefully

      if(line == "exit") {
        return;
      }

      if(catch err = vm::interpret(line)) {
        case InterpretError.COMPILE_ERROR:
        case InterpretError.RUNTIME_ERROR:
        default: continue;
      }
    };
  }
}

fn int runFile(String file) {

  @pool() {
    String source = (String) file::load_temp(file)!!; // TODO handle errors gracefully
    // defer source.free();

    if(catch err = vm::interpret(source)) {
      case InterpretError.COMPILE_ERROR: return 65;
      case InterpretError.RUNTIME_ERROR: return 70;
      default: return 1;
    }
  };

  return 0;
}

fn int main(String[] args) {
  vm::initVm();
  defer vm::freeVm();

  if(args.len == 1) {
    repl();
  } 
  else if(args.len == 2) {
    return runFile(args[1]);
  } 
  else {
    io::fprintf(io::stderr(), "Usage: lox [path]\n")!!;
    return 64;
  }

  return 0;
}