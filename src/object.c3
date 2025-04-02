module object;

import std::io;
import libc;

import vm;
import value;
import chunk;
import memory;
import table;

struct Obj {
  ObjType type;
  bool isMarked;
  Obj* next;
}

struct ObjFunction {
  Obj obj;
  int arity;
  int upvalueCount;
  Chunk chunk;
  ObjString* name;
}

alias NativeFn = fn Value (int argCount, Value* args);

struct ObjNative {
  Obj obj;
  NativeFn function;
}

// TODO chapter 19 optimization use flexible member for chars
struct ObjString {
  Obj obj;
  int length;
  String chars;
  uint hash;
}

struct ObjUpvalue {
  Obj obj;
  Value* location;
  Value closed;
  ObjUpvalue* next;
}

struct ObjClosure {
  Obj obj;
  ObjFunction* function;
  ObjUpvalue** upvalues;
  int upvalueCount;
}

struct ObjClass {
  Obj obj;
  ObjString* name;
  Table methods;
}

struct ObjInstance {
  Obj obj;
  ObjClass* klass;
  Table fields; 
}

struct ObjBoundMethod {
  Obj obj;
  Value receiver;
  ObjClosure* method;
}

enum ObjType {
  OBJ_BOUND_METHOD,
  OBJ_CLASS,
  OBJ_CLOSURE,
  OBJ_FUNCTION,
  OBJ_INSTANCE,
  OBJ_NATIVE,
  OBJ_STRING,
  OBJ_UPVALUE
}

fn Obj* allocateObject(usz size, ObjType type) {
  Obj* object = (Obj*) memory::reallocate(null, 0, size);
  object.isMarked = false;
  object.type = type;

  object.next = vm::vm.objects;
  vm::vm.objects = object;

  $if $feature(DEBUG_LOG_GC):
    io::printfn("%p allocate %d for %s", (void*)object, size, type);
  $endif

  return object;
}

fn ObjBoundMethod* newBoundMethod(Value receiver, ObjClosure* method) {
  ObjBoundMethod* bound = allocate_obj(ObjBoundMethod, ObjType.OBJ_BOUND_METHOD);
  bound.receiver = receiver;
  bound.method = method;
  return bound;
}

fn ObjClass* newClass(ObjString* name) {
  ObjClass* klass = allocate_obj(ObjClass, ObjType.OBJ_CLASS);
  table::initTable(&klass.methods);
  klass.name = name; 
  return klass;
}

fn ObjClosure* newClosure(ObjFunction* function) {
  ObjUpvalue** upvalues = memory::allocate(ObjUpvalue*, function.upvalueCount);
  for (int i = 0; i < function.upvalueCount; i++) {
    upvalues[i] = null;
  }
  ObjClosure* closure = allocate_obj(ObjClosure, ObjType.OBJ_CLOSURE);
  closure.function = function;
  closure.upvalues = upvalues;
  closure.upvalueCount = function.upvalueCount;
  return closure;
}

fn ObjFunction* newFunction() {
  ObjFunction* function = allocate_obj(ObjFunction, ObjType.OBJ_FUNCTION);
  function.arity = 0;
  function.upvalueCount = 0;
  function.name = null;
  chunk::initChunk(&function.chunk);
  return function;
}

fn ObjInstance* newInstance(ObjClass* klass) {
  ObjInstance* instance = allocate_obj(ObjInstance, ObjType.OBJ_INSTANCE);
  instance.klass = klass;
  table::initTable(&instance.fields);
  return instance;
}

fn ObjNative* newNative(NativeFn function) {
  ObjNative* native = allocate_obj(ObjNative, ObjType.OBJ_NATIVE);
  native.function = function;
  return native;
}

fn ObjUpvalue* newUpvalue(Value* slot) {
  ObjUpvalue* upvalue = allocate_obj(ObjUpvalue, ObjType.OBJ_UPVALUE);
  upvalue.closed = value::nil_val();
  upvalue.location = slot;
  upvalue.next = null;
  return upvalue;
}

fn ObjString* allocateString(char* chars, int length, uint hash) {
  ObjString* string = allocate_obj(ObjString, ObjType.OBJ_STRING);
  string.length = length;
  string.chars = (String) chars[:length];
  string.hash = hash;

  vm::push(value::obj_val(string));
  table::tableSet(&vm::vm.strings, string, value::nil_val());
  vm::pop();

  return string;
}

fn uint hashString(char* key, int length) {
  uint hash = 2166136261;
  for (int i = 0; i < length; i++) {
    hash ^= (char)key[i];
    hash *= 16777619;
  }
  return hash;
}

fn ObjString* takeString(char* chars, int length) {
  uint hash = hashString(chars, length);
  
  ObjString* interned = table::tableFindString(&vm::vm.strings, chars, length, hash);
  if (interned != null) {
    memory::free_array(char, chars, length + 1);
    return interned;
  }

  return allocateString(chars, length, hash);
}

fn ObjString* copyString(char* chars, int length) {
  uint hash = hashString(chars, length);

  ObjString* interned = table::tableFindString(&vm::vm.strings, chars, length, hash);
  if (interned != null) return interned;

  char* heapChars = memory::allocate(char, length + 1);
  libc::memcpy(heapChars, chars, length);
  heapChars[length] = '\0';
  return allocateString(heapChars, length, hash);
}

fn void printFunction(ObjFunction* function) {
  if (function.name == null) {
    io::printf("<script>");
    return;
  }
  io::printf("<fn %s>", function.name.chars);
}

fn void printObject(Value value) {
  switch (obj_type(value)) {
    case OBJ_BOUND_METHOD:
      printFunction(object::as_bound_method(value).method.function);
    case OBJ_CLASS:
      io::printf("%s", as_class(value).name.chars);
    case OBJ_CLOSURE:
      printFunction(as_closure(value).function);
    case OBJ_FUNCTION:
      printFunction(as_function(value));
    case OBJ_INSTANCE:
      io::printf("%s instance", as_instance(value).klass.name.chars);
    case OBJ_NATIVE:
      io::printf("<native fn>");
    case OBJ_STRING:
      io::printf("%s", as_cstring(value));
    case OBJ_UPVALUE:
      io::printf("upvalue");
  }
}

macro allocate_obj($Type, objectType) {
  return ($Type*) allocateObject($Type.sizeof, objectType);
}

macro obj_type(value) {
  return value::as_obj(value).type;
}

macro is_obj_type(value, type) {
  return value::is_obj(value) && value::as_obj(value).type == type;
}

macro is_bound_method(value) {
  return is_obj_type(value, ObjType.OBJ_BOUND_METHOD);
}

macro is_class(value) {
  return is_obj_type(value, ObjType.OBJ_CLASS);
}

macro is_closure(value) {
  return is_obj_type(value, ObjType.OBJ_CLOSURE);
}

macro is_function(value) {
  return is_obj_type(value, ObjType.OBJ_FUNCTION);
}

macro is_instance(value) {
  return is_obj_type(value, ObjType.OBJ_INSTANCE);
}

macro is_native(value) {
  return is_obj_type(value, ObjType.OBJ_NATIVE);
}

macro is_string(value) {
  return is_obj_type(value, ObjType.OBJ_STRING);
}

macro as_bound_method(value) {
  return (ObjBoundMethod*) value::as_obj(value);
}

macro as_class(value) {
  return (ObjClass*) value::as_obj(value);
}

macro as_closure(value) {
  return (ObjClosure*) value::as_obj(value);
}

macro as_function(value) {
  return (ObjFunction*) value::as_obj(value);
}

macro as_instance(value) {
  return (ObjInstance*) value::as_obj(value);
}

macro as_native(value) {
  return ((ObjNative*) value::as_obj(value)).function;
}

macro as_string(value) {
  return (ObjString*) value::as_obj(value);
}

macro as_cstring(value) {
  return ((ObjString*) value::as_obj(value)).chars;
}