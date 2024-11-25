module memory;

import std::core::mem::allocator;
import std::io;
import libc;

import chunk;
import object;
import vm;
import value;
import table;
import compiler;

const GC_HEAP_GROW_FACTOR = 2;

macro allocate($Type, count) {
  return ($Type*) reallocate(null, 0, $Type.sizeof * count);
}

macro ofree($Type, pointer) {
  return reallocate(pointer, $Type.sizeof, 0);
}

macro int grow_capacity(capacity) {
  return capacity < 8 ? 8 : capacity * 2;
}

macro grow_array($Type, pointer, oldCount, newCount) {
  return ($Type*) reallocate(pointer, $Type.sizeof * oldCount, $Type.sizeof * newCount);
}

macro void free_array($Type, pointer, oldCount) {
  reallocate(pointer, $Type.sizeof * oldCount, 0);
}

fn void* reallocate(void* pointer, usz oldSize, usz newSize) {
  vm::vm.bytesAllocated += newSize - oldSize;
  if (newSize > oldSize) {
    $if $feature(DEBUG_STRESS_GC):
      collectGarbage();
    $endif

    if (vm::vm.bytesAllocated > vm::vm.nextGC) {
      collectGarbage();
    }
  }

  if (newSize == 0) {
    free(pointer);
    return null;
  }

  void* result = allocator::realloc(allocator::heap(), pointer, newSize);

  return result;
}

fn void collectGarbage() {
  $if $feature(DEBUG_LOG_GC):
    io::printfn("-- gc begin");
    usz before = vm::vm.bytesAllocated;
  $endif

  markRoots();
  traceReferences();
  table::tableRemoveWhite(&vm::vm.strings);
  sweep();

  vm::vm.nextGC = vm::vm.bytesAllocated * GC_HEAP_GROW_FACTOR;

  $if $feature(DEBUG_LOG_GC):
    io::printfn("-- gc end");
    io::printf("   collected %d bytes (from %d to %d) next at %d\n",
         before - vm::vm.bytesAllocated, before, vm::vm.bytesAllocated, vm::vm.nextGC);
  $endif
}

fn void markRoots() {
  for (Value* slot = &vm::vm.stack[1]; slot < vm::vm.stackTop; slot++) {
    markValue(*slot);
  }

  for (int i = 0; i < vm::vm.frameCount; i++) {
    markObject((Obj*)vm::vm.frames[i].closure);
  }

  for (ObjUpvalue* upvalue = vm::vm.openUpvalues; upvalue != null; upvalue = upvalue.next) {
    markObject((Obj*)upvalue);
  }

  table::markTable(&vm::vm.globals);
  compiler::markCompilerRoots();
  markObject((Obj*)vm::vm.initString);
}

fn void traceReferences() {
  while (vm::vm.grayCount > 0) {
    Obj* object = vm::vm.grayStack[--vm::vm.grayCount];
    blackenObject(object);
  }
}

fn void sweep() {
  Obj* previous = null;
  Obj* object = vm::vm.objects;
  while (object != null) {
    if (object.isMarked) {
      object.isMarked = false;
      previous = object;
      object = object.next;
    } else {
      Obj* unreached = object;
      object = object.next;
      if (previous != null) {
        previous.next = object;
      } else {
        vm::vm.objects = object;
      }

      freeObject(unreached);
    }
  }
}

fn void markValue(Value value) {
  if (value::is_obj(value)) markObject(value::as_obj(value));
}

fn void markArray(ValueArray* array) {
  for (int i = 0; i < array.count; i++) {
    markValue(array.values[i]);
  }
}

fn void blackenObject(Obj* object) {
  $if $feature(DEBUG_LOG_GC):
    io::printf("%p blacken ", (void*)object);
    value::printValue(value::obj_val(object));
    io::printf("\n");
  $endif

  switch (object.type) {
    case OBJ_BOUND_METHOD: {
      ObjBoundMethod* bound = (ObjBoundMethod*)object;
      markValue(bound.receiver);
      markObject((Obj*)bound.method);
    }
    case OBJ_CLASS: {
      ObjClass* klass = (ObjClass*)object;
      markObject((Obj*)klass.name);
      table::markTable(&klass.methods);
    }
    case OBJ_CLOSURE: {
      ObjClosure* closure = (ObjClosure*)object;
      markObject((Obj*)closure.function);
      for (int i = 0; i < closure.upvalueCount; i++) {
        markObject((Obj*)closure.upvalues[i]);
      }
    }
    case OBJ_FUNCTION: {
      ObjFunction* function = (ObjFunction*)object;
      markObject((Obj*)function.name);
      markArray(&function.chunk.constants);
    }
    case OBJ_INSTANCE: {
      ObjInstance* instance = (ObjInstance*)object;
      markObject((Obj*)instance.klass);
      table::markTable(&instance.fields);
    }
    case OBJ_UPVALUE:
      markValue(((ObjUpvalue*)object).closed);
    case OBJ_NATIVE:
    case OBJ_STRING:
      break;
  }
}

fn void markObject(Obj* object) {
  if (object == null) return;
  if (object.isMarked) return;

  $if $feature(DEBUG_LOG_GC):
    io::printf("%p mark ", (void*)object);
    value::printValue(value::obj_val(object));
    io::printf("\n");
  $endif

  object.isMarked = true;

  if (vm::vm.grayCapacity < vm::vm.grayCount + 1) {
    vm::vm.grayCapacity = grow_capacity(vm::vm.grayCapacity);
    vm::vm.grayStack = (Obj**)realloc(vm::vm.grayStack, Obj*.sizeof * vm::vm.grayCapacity);
  }

  vm::vm.grayStack[vm::vm.grayCount++] = object;

  if (vm::vm.grayStack == null) libc::exit(1);

}

fn void freeObject(Obj* object) {
  switch (object.type) {
    case OBJ_BOUND_METHOD: {
      ofree(ObjBoundMethod, object);
    }
    case OBJ_CLASS: {
      ObjClass* klass = (ObjClass*)object;
      table::freeTable(&klass.methods);
      ofree(ObjClass, object);
    } 
    case OBJ_CLOSURE: {
      ObjClosure* closure = (ObjClosure*)object;
      free_array(ObjUpvalue*, closure.upvalues, closure.upvalueCount);
      ofree(ObjClosure, object);
    }
    case OBJ_FUNCTION: {
      ObjFunction* function = (ObjFunction*) object;
      chunk::freeChunk(&function.chunk);
      ofree(ObjFunction, object);
    }
    case OBJ_INSTANCE: {
      ObjInstance* instance = (ObjInstance*)object;
      table::freeTable(&instance.fields);
      ofree(ObjInstance, object);
    }
    case OBJ_NATIVE: {
      ofree(ObjNative, object);
    }
    case OBJ_STRING: {
      ObjString* string = (ObjString*)object;
      free_array(char, string.chars, string.length + 1);
      ofree(ObjString, object);
    }
    case OBJ_UPVALUE:
      ofree(ObjUpvalue, object);
  }
}

fn void freeObjects() {

  Obj* object = vm::vm.objects;

  $if $feature(DEBUG_LOG_GC):
    io::printfn("%p free type %s", (void*)object, object.type);
  $endif

  while (object != null) {
    Obj* next = object.next;
    freeObject(object);
    object = next;
  }

  libc::free(vm::vm.grayStack);
}