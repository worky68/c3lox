module value;

import std::io;
import libc;

import memory;
import object;

enum ValueType : char {
  VAL_BOOL,
  VAL_NIL, 
  VAL_NUMBER,
  VAL_OBJ
}

struct Value {
  ValueType type;
  union as {
    bool boolean;
    double number;
    Obj* obj;
  } 
}

macro is_bool(Value value) {
  return value.type == VAL_BOOL;
}

macro is_nil(Value value) {
  return value.type == VAL_NIL;
}

macro is_number(Value value) {
  return value.type == VAL_NUMBER;
}

macro is_obj(Value value) {
  return value.type == VAL_OBJ;
}

macro as_bool(Value value) {
  return value.as.boolean;
}

macro as_number(Value value) {
  return value.as.number;
}

macro as_obj(Value value) {
  return value.as.obj;
}

macro Value bool_val(value) {
  return (Value) Value{VAL_BOOL, {.boolean = (bool) value}}; 
}

macro Value nil_val() {
  return (Value) Value{VAL_NIL, {.number = 0}}; 
}

macro Value number_val(value) {
  return (Value) Value{VAL_NUMBER, {.number = (double) value}}; 
}

macro Value obj_val(value) {
  return (Value) Value{VAL_OBJ, {.obj = (Obj*) value}}; 
}

struct ValueArray {
  int capacity;
  int count;
  Value* values;
}

fn void initValueArray(ValueArray* array) {
  array.values = null;
  array.capacity = 0;
  array.count = 0;
}

fn void writeValueArray(ValueArray* array, Value value) {
  if (array.capacity < array.count + 1) {
    int oldCapacity = array.capacity;
    array.capacity = memory::grow_capacity(oldCapacity);
    array.values = memory::grow_array(Value, array.values, oldCapacity, array.capacity);
  }

  array.values[array.count] = value;
  array.count++;
}

fn void freeValueArray(ValueArray* array) {
  memory::free_array(Value, array.values, array.capacity);
  initValueArray(array);
}

fn void printValue(Value value) {
  switch (value.type) {
    case VAL_BOOL: io::printf(as_bool(value) ? "true" : "false");
    case VAL_NIL: io::printf("nil");
    case VAL_NUMBER: io::printf("%.15g", as_number(value));
    case VAL_OBJ: object::printObject(value);
  }
}

fn bool valuesEqual(Value a, Value b) {
  if (a.type != b.type) return false;
  switch (a.type) {
    case VAL_BOOL:   return as_bool(a) == as_bool(b);
    case VAL_NIL:    return true;
    case VAL_NUMBER: return as_number(a) == as_number(b);
    case VAL_OBJ:    return as_obj(a) == as_obj(b);
    default:         return false; // Unreachable.
  }
}