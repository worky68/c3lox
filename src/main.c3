module lox;

import std::io;
import std::core::mem;

import vm;

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
    String source = readFile(file)!!; // TODO handle errors gracefully

    if(catch err = vm::interpret(source)) {
      case InterpretError.COMPILE_ERROR: return 65;
      case InterpretError.RUNTIME_ERROR: return 70;
      default: return 1;
    }
  };
  return 0;
}

fn String! readFile(String filename) {
  File file = file::open(filename, "rb")!;
  defer (void)file.close();
  usz len = file.seek(0, END)! + 1;
  file.seek(0, SET)!;
  char* data = allocator::malloc_try(allocator::temp(), len)!;
  defer catch allocator::free(allocator::temp(), data);
  usz read = 0;
  while (read < len - 1)
  {
    read += file.read(data[read:len - read])!;
  }
  data[len - 1] = '\0';
  return (String) data[:len];
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