module lox;

import std::io;
import std::core::mem;
import libc;

import vm;

fn void! repl() {

  for(;;) {
    @pool() {
      io::printf("> ");
      String line = io::treadline()!;

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
    String! source = readFile(file);
    if(anyfault err = @catch(source)) {
      io::fprintfn(io::stderr(), "lox: can't read file '%s'\n[Errno %d] %s", file, libc::errno(), err)!!; 
      return 1;
    }

    if(catch err = vm::interpret(source)) {
      case InterpretError.COMPILE_ERROR: return 65;
      case InterpretError.RUNTIME_ERROR: return 70;
      default: return 1;
    }
  };
  return 0;
}

fn String! readFile(String filename) {

  if(!file::is_file(filename)) {
    libc::errno_set(errno::EISDIR);
    return IoError.FILE_IS_DIR?;
  }

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
    if(catch err = repl()) {
      io::fprintfn(io::stderr(), "lox: failed to read input\n[Errno %d] %s", libc::errno(), err)!!; 
      return 1;
    }
  } 
  else if(args.len == 2) {
    return runFile(args[1]);
  } 
  else {
    io::fprintfn(io::stderr(), "Usage: lox [path]")!!;
    return 64;
  }

  return 0;
}