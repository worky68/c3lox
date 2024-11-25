module vm;

import std::io;
import libc;

import compiler;
import chunk;
import value;
import object;
import table;
import memory;
import debug;

const FRAMES_MAX = 64;
const STACK_MAX = 256 * FRAMES_MAX;

struct CallFrame {
  ObjClosure* closure;
  char* ip;
  Value* slots;
}

struct Vm {
  CallFrame[FRAMES_MAX] frames;
  int frameCount;
  Value[STACK_MAX] stack;
  Value* stackTop;
  Table globals;
  Table strings;
  ObjString* initString;
  ObjUpvalue* openUpvalues;
  usz bytesAllocated;
  usz nextGC;
  Obj* objects;
  int grayCount;
  int grayCapacity;
  Obj** grayStack;
}

fault InterpretError {
  COMPILE_ERROR,
  RUNTIME_ERROR
}

Vm vm;

fn Value clockNative(int argCount, Value* args) {
  return value::number_val((double)libc::clock() / libc::CLOCKS_PER_SEC);
}

fn void initVm() {
  resetStack();
  vm.objects = null;
  vm.bytesAllocated = 0;
  vm.nextGC = 1024 * 1024;

  vm.grayCount = 0;
  vm.grayCapacity = 0;
  vm.grayStack = null;

  table::initTable(&vm.globals);
  table::initTable(&vm.strings);

  vm.initString = null;
  vm.initString = object::copyString("init", 4);

  defineNative("clock", &clockNative);
}

fn void freeVm() {
  table::freeTable(&vm.globals);
  table::freeTable(&vm.strings);
  memory::freeObjects();
  vm.initString = null;
}

fn void resetStack() {
  vm.stackTop = &vm.stack;
  vm.frameCount = 0;
  vm.openUpvalues = null;
}

fn void runtimeError(String format, args...) {
  io::fprintfn(io::stderr(), format, ...args)!!;
  
  for (int i = vm.frameCount - 1; i >= 0; i--) {
    CallFrame* frame = &vm.frames[i];
    ObjFunction* function = frame.closure.function;
    usz instruction = frame.ip - function.chunk.code - 1;
    io::fprintf(io::stderr(), "[line %d] in ", function.chunk.lines[instruction])!!;
    if (function.name == null) {
      io::fprintf(io::stderr(), "script\n")!!;
    } else {
      io::fprintf(io::stderr(), "%s()\n", function.name.chars)!!;
    }
  }

  resetStack();
}

fn void defineNative(String name, NativeFn function) {
  push(value::obj_val(object::copyString(name, (int)libc::strlen((ZString) name)))); // TODO string length in c3
  push(value::obj_val(object::newNative(function)));
  table::tableSet(&vm.globals, object::as_string(vm.stack[0]), vm.stack[1]);
  pop();
  pop();
}

fn void push(Value value) {
  *vm.stackTop = value;
  vm.stackTop++;
}

fn Value pop() {
  vm.stackTop--;
  return *vm.stackTop;
}

fn Value peek(int distance) {
  return vm.stackTop[-1 - distance];
}

fn bool call(ObjClosure* closure, int argCount) {

  if (argCount != closure.function.arity) {
    runtimeError("Expected %d arguments but got %d.", closure.function.arity, argCount);
    return false;
  }

  if (vm.frameCount == FRAMES_MAX) {
    runtimeError("Stack overflow.");
    return false;
  }

  CallFrame* frame = &vm.frames[vm.frameCount++];
  frame.closure = closure;
  frame.ip = closure.function.chunk.code;
  frame.slots = vm.stackTop - argCount - 1;
  return true;
}

fn bool callValue(Value callee, int argCount) {
  if (value::is_obj(callee)) {
    switch (object::obj_type(callee)) {
      case OBJ_BOUND_METHOD: {
        ObjBoundMethod* bound = object::as_bound_method(callee);
        vm.stackTop[-argCount - 1] = bound.receiver;
        return call(bound.method, argCount);
      }
      case OBJ_CLASS: {
        ObjClass* klass = object::as_class(callee);
        vm.stackTop[-argCount - 1] = value::obj_val(object::newInstance(klass));
        Value initializer;
        if (table::tableGet(&klass.methods, vm.initString, &initializer)) {
          return call(object::as_closure(initializer), argCount);
        } else if (argCount != 0) {
          runtimeError("Expected 0 arguments but got %d.", argCount);
          return false;
        }
        return true;
      }
      case OBJ_CLOSURE:
        return call(object::as_closure(callee), argCount);
      case OBJ_NATIVE: {
        NativeFn native = object::as_native(callee);
        Value result = native(argCount, vm.stackTop - argCount);
        vm.stackTop -= argCount + 1;
        push(result);
        return true;
      }
      default:
        break; // Non-callable object type.
    }
  }
  runtimeError("Can only call functions and classes.");
  return false;
}

fn bool invokeFromClass(ObjClass* klass, ObjString* name, int argCount) {
  Value method;
  if (!table::tableGet(&klass.methods, name, &method)) {
    runtimeError("Undefined property '%s'.", name.chars);
    return false;
  }
  return call(object::as_closure(method), argCount);
}

fn bool invoke(ObjString* name, int argCount) {
  Value receiver = peek(argCount);

  if (!object::is_instance(receiver)) {
    runtimeError("Only instances have methods.");
    return false;
  }

  ObjInstance* instance = object::as_instance(receiver);

  Value value;
  if (table::tableGet(&instance.fields, name, &value)) {
    vm.stackTop[-argCount - 1] = value;
    return callValue(value, argCount);
  }

  return invokeFromClass(instance.klass, name, argCount);
}

fn bool bindMethod(ObjClass* klass, ObjString* name) {
  Value method;
  if (!table::tableGet(&klass.methods, name, &method)) {
    runtimeError("Undefined property '%s'.", name.chars);
    return false;
  }

  ObjBoundMethod* bound = object::newBoundMethod(peek(0), object::as_closure(method));
  pop();
  push(value::obj_val(bound));
  return true;
}

fn ObjUpvalue* captureUpvalue(Value* local) {
  ObjUpvalue* prevUpvalue = null;
  ObjUpvalue* upvalue = vm.openUpvalues;
  while (upvalue != null && upvalue.location > local) {
    prevUpvalue = upvalue;
    upvalue = upvalue.next;
  }

  if (upvalue != null && upvalue.location == local) {
    return upvalue;
  }
  ObjUpvalue* createdUpvalue = object::newUpvalue(local);
  createdUpvalue.next = upvalue;

  if (prevUpvalue == null) {
    vm.openUpvalues = createdUpvalue;
  } else {
    prevUpvalue.next = createdUpvalue;
  }

  return createdUpvalue;
}

fn void closeUpvalues(Value* last) {
  while (vm.openUpvalues != null && vm.openUpvalues.location >= last) {
    ObjUpvalue* upvalue = vm.openUpvalues;
    upvalue.closed = *upvalue.location;
    upvalue.location = &upvalue.closed;
    vm.openUpvalues = upvalue.next;
  }
}

fn void defineMethod(ObjString* name) {
  Value method = peek(0);
  ObjClass* klass = object::as_class(peek(1));
  table::tableSet(&klass.methods, name, method);
  pop();
}

fn bool isFalsey(Value value) {
  return value::is_nil(value) || (value::is_bool(value) && !value::as_bool(value));
}

fn void concatenate() {
  ObjString* b = object::as_string(peek(0));
  ObjString* a = object::as_string(peek(1));

  int length = a.length + b.length;
  char* chars = memory::allocate(char, length + 1);
  libc::memcpy(chars, a.chars, a.length);
  libc::memcpy(chars + a.length, b.chars, b.length);
  chars[length] = '\0';

  ObjString* result = object::takeString(chars, length);
  pop();
  pop();
  push(value::obj_val(result));
}

fn void! run() {
  CallFrame* frame = &vm.frames[vm.frameCount - 1];
  for (;;) {
    $if $feature(DEBUG_TRACE_EXECUTION):
      io::printf("          ");
      for (Value* slot = &vm.stack; slot < vm.stackTop; slot++) {
        io::printf("[ ");
        value::printValue(*slot);
        io::printf(" ]");
      }
      io::printf("\n");
      debug::disassembleInstruction(&frame.closure.function.chunk, (int)(frame.ip - frame.closure.function.chunk.code));
    $endif
    OpCode instruction;
    switch (instruction = (chunk::OpCode) read_byte(frame)) {
      case OP_CONSTANT: {
        Value constant = read_constant(frame);
        push(constant);
      }
      case OP_NIL: push(value::nil_val());
      case OP_TRUE: push(value::bool_val(true));
      case OP_FALSE: push(value::bool_val(false));
      case OP_POP: pop();
      case OP_GET_LOCAL: {
        char slot = read_byte(frame);
        push(frame.slots[slot]);
      }
      case OP_SET_LOCAL: {
        char slot = read_byte(frame);
        frame.slots[slot] = peek(0);
      }
      case OP_GET_GLOBAL: {
        ObjString* name = read_string(frame);
        Value value;
        if (!table::tableGet(&vm.globals, name, &value)) {
          runtimeError("Undefined variable '%s'.", name.chars);
          return InterpretError.RUNTIME_ERROR?;
        }
        push(value);
      }
      case OP_DEFINE_GLOBAL: {
        ObjString* name = read_string(frame);
        table::tableSet(&vm.globals, name, peek(0));
        pop();
      }
      case OP_SET_GLOBAL: {
        ObjString* name = read_string(frame);
        if (table::tableSet(&vm.globals, name, peek(0))) {
          table::tableDelete(&vm.globals, name); 
          runtimeError("Undefined variable '%s'.", name.chars);
          return InterpretError.RUNTIME_ERROR?;
        }
      }
      case OP_GET_UPVALUE: {
        char slot = read_byte(frame);
        push(*frame.closure.upvalues[slot].location);
        break;
      }
      case OP_SET_UPVALUE: {
        char slot = read_byte(frame);
        *frame.closure.upvalues[slot].location = peek(0);
        break;
      }
      case OP_GET_PROPERTY: {
        if (!object::is_instance(peek(0))) {
          runtimeError("Only instances have properties.");
          return InterpretError.RUNTIME_ERROR?;
        }

        ObjInstance* instance = object::as_instance(peek(0));
        ObjString* name = read_string(frame);

        Value value;
        if (table::tableGet(&instance.fields, name, &value)) {
          pop(); // Instance.
          push(value);
          break;
        }

        if (!bindMethod(instance.klass, name)) {
          return InterpretError.RUNTIME_ERROR?;
        }
      }
      case OP_SET_PROPERTY: {
        if (!object::is_instance(peek(1))) {
          runtimeError("Only instances have fields.");
          return InterpretError.RUNTIME_ERROR?;
        }

        ObjInstance* instance = object::as_instance(peek(1));
        table::tableSet(&instance.fields, read_string(frame), peek(0));
        Value value = pop();
        pop();
        push(value);
      }
      case OP_GET_SUPER: {
        ObjString* name = read_string(frame);
        ObjClass* superclass = object::as_class(pop());

        if (!bindMethod(superclass, name)) {
          return InterpretError.RUNTIME_ERROR?;
        }
      }
      case OP_EQUAL: {
        Value b = pop();
        Value a = pop();
        push(value::bool_val(value::valuesEqual(a, b)));
      }
      case OP_GREATER:  @binary_op(value::bool_val, gt)!;
      case OP_LESS:     @binary_op(value::bool_val, lt)!;
      case OP_ADD: {
        // TODO consolidate this logic
        if(object::is_string(peek(0)) && object::is_string(peek(1))) {
          concatenate();
        } else if(value::is_number(peek(0)) && value::is_number(peek(1))) {
          @binary_op(value::number_val, add)!;
        } else {
          runtimeError("Operands must be two numbers or two strings.");
          return InterpretError.RUNTIME_ERROR?;
        }
      }
      case OP_SUBTRACT: @binary_op(value::number_val, sub)!;
      case OP_MULTIPLY: @binary_op(value::number_val, mult)!;
      case OP_DIVIDE:   @binary_op(value::number_val, div)!;
      case OP_NOT: push(value::bool_val(isFalsey(pop())));
      case OP_NEGATE: {
        if(!value::is_number(peek(0))) {
          runtimeError("Operand must be a number.");
          return InterpretError.RUNTIME_ERROR?;
        }
        push(value::number_val(-value::as_number(pop())));
      }
      case OP_PRINT: {
        value::printValue(pop());
        io::printf("\n");
      }
      case OP_JUMP: {
        short offset = read_short(frame);
        frame.ip += offset;
      }
      case OP_JUMP_IF_FALSE: {
        short offset = read_short(frame);
        if (isFalsey(peek(0))) frame.ip += offset;
      }
      case OP_LOOP: {
        short offset = read_short(frame);
        frame.ip -= offset;
      }
      case OP_CALL: {
        int argCount = read_byte(frame);
        if (!callValue(peek(argCount), argCount)) {
          return InterpretError.RUNTIME_ERROR?;
        }
        frame = &vm.frames[vm.frameCount - 1];
      }
      case OP_INVOKE: {
        ObjString* method = read_string(frame);
        int argCount = read_byte(frame);
        if (!invoke(method, argCount)) {
          return InterpretError.RUNTIME_ERROR?;
        }
        frame = &vm.frames[vm.frameCount - 1];
      }
      case OP_SUPER_INVOKE: {
        ObjString* method = read_string(frame);
        int argCount = read_byte(frame);
        ObjClass* superclass = object::as_class(pop());
        if (!invokeFromClass(superclass, method, argCount)) {
          return InterpretError.RUNTIME_ERROR?;
        }
        frame = &vm.frames[vm.frameCount - 1];
      }
      case OP_CLOSURE: {
        ObjFunction* function = object::as_function(read_constant(frame));
        ObjClosure* closure = object::newClosure(function);
        push(value::obj_val(closure));
        for (int i = 0; i < closure.upvalueCount; i++) {
          char isLocal = read_byte(frame);
          char index = read_byte(frame);
          if (isLocal) {
            closure.upvalues[i] = captureUpvalue(frame.slots + index);
          } else {
            closure.upvalues[i] = frame.closure.upvalues[index];
          }
        }
      }
      case OP_CLOSE_UPVALUE:
        closeUpvalues(vm.stackTop - 1);
        pop();
      case OP_CLASS:
        push(value::obj_val(object::newClass(read_string(frame))));
      case OP_INHERIT: {
        Value superclass = peek(1);
        
        if (!object::is_class(superclass)) {
          runtimeError("Superclass must be a class.");
          return InterpretError.RUNTIME_ERROR?;
        }

        ObjClass* subclass = object::as_class(peek(0));
        table::tableAddAll(&object::as_class(superclass).methods, &subclass.methods);
        pop(); // Subclass.
      }
      case OP_METHOD:
        defineMethod(read_string(frame));
      case OP_RETURN: {
        Value result = pop();
        closeUpvalues(frame.slots);
        vm.frameCount--;
        if (vm.frameCount == 0) {
          pop();
          return;
        }

        vm.stackTop = frame.slots;
        push(result);
        frame = &vm.frames[vm.frameCount - 1];
      }
    }
  }
}

fn void! interpret(String source) {

  ObjFunction* function = compiler::compile(source);
  if (function == null) return InterpretError.COMPILE_ERROR?;

  push(value::obj_val(function));
  ObjClosure* closure = object::newClosure(function);
  pop();
  push(value::obj_val(closure));
  call(closure, 0);

  run()!;

}

macro read_byte(frame) {
  return *frame.ip++;
}

macro read_constant(frame) {
  return frame.closure.function.chunk.constants.values[read_byte(frame)];
}

macro read_short(frame) {
  frame.ip += 2;
  return (short)((frame.ip[-2] << 8) | frame.ip[-1]);
}

macro read_string(frame) {
  return object::as_string(read_constant(frame));
}

macro void! @binary_op(#as_value, #op) {
  if (!value::is_number(peek(0)) || !value::is_number(peek(1))) {
    runtimeError("Operands must be numbers.");
    return InterpretError.RUNTIME_ERROR?;
  }
  double b = value::as_number(pop());
  double a = value::as_number(pop());
  push(#as_value(#op(a, b)));
}

macro add(a, b) {
  return a + b;
}

macro sub(a, b) {
  return a - b;
}

macro mult(a, b) {
  return a * b;
}

macro div(a, b) {
  return a / b;
}

macro gt(a, b) {
  return a > b;
}

macro gte(a, b) {
  return a >= b;
}

macro lt(a, b) {
  return a < b;
}

macro lte(a, b) {
  return a <= b;
}