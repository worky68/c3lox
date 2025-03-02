import std::io;

import vm;
import compiler;
import chunk;
import opcode;
import object;
import value;
import debug;

// TODO Add more test variations and negative tests using offical repo as reference
fn void test_compiler_expression() @test {
  vm::initVm();
  ObjFunction* func = compiler::compile("(5 - (3 - 1)) + -1;\0");

  OpCode code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  double value = value::as_number(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_CONSTANT);
  assert(value == 5);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  value = value::as_number(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_CONSTANT);
  assert(value == 3);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  value = value::as_number(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_CONSTANT);
  assert(value == 1);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_SUBTRACT);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_SUBTRACT);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  value = value::as_number(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_CONSTANT);
  assert(value == 1);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_NEGATE);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_ADD);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  assert(code == OpCode.OP_POP);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_NIL);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_RETURN);

}

fn void test_compiler_assignment() @test {
  vm::initVm();
  ObjFunction* func = compiler::compile("var i = 3;\0");
  
  OpCode code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  double value = value::as_number(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_CONSTANT);
  assert(value == 3);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  ObjString* global = object::as_string(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_DEFINE_GLOBAL);
  assert(global.chars == "i");

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_NIL);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_RETURN);
}

fn void test_compiler_if_statement() @test {
  vm::initVm();
  ObjFunction* func = compiler::compile("if (true) {\n  print \"good\";\n}\0");
  
  char* start = func.chunk.code;

  OpCode code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  assert(code == OpCode.OP_TRUE);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  short jump = (short)(*func.chunk.code << 8);
  func.chunk.code++;
  jump |= *func.chunk.code;

  int offset = (int) (func.chunk.code - start);
  func.chunk.code++;

  assert(code == OpCode.OP_JUMP_IF_FALSE);
  assert(offset + jump + 1 == 11);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  assert(code == OpCode.OP_POP);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  ObjString* str = object::as_string(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_CONSTANT);
  assert(str.chars == "good");

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  assert(code == OpCode.OP_PRINT);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  jump = (short)(*func.chunk.code << 8);
  func.chunk.code++;
  jump |= *func.chunk.code;

  offset = (int) (func.chunk.code - start);
  func.chunk.code++;

  assert(code == OpCode.OP_JUMP);
  assert(offset + jump + 1 == 12);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  assert(code == OpCode.OP_POP);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_NIL);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_RETURN);
}

fn void test_compiler_ifelse_statement() @test {
  vm::initVm();
  ObjFunction* func = compiler::compile("if (true) {\n  print \"good\";\n}\nelse {\n  print \"bad\";\n}\0");
  
  char* start = func.chunk.code;

  OpCode code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  assert(code == OpCode.OP_TRUE);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  short jump = (short)(*func.chunk.code << 8);
  func.chunk.code++;
  jump |= *func.chunk.code;

  int offset = (int) (func.chunk.code - start);
  func.chunk.code++;

  assert(code == OpCode.OP_JUMP_IF_FALSE);
  assert(offset + jump + 1 == 11);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  assert(code == OpCode.OP_POP);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  ObjString* str = object::as_string(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_CONSTANT);
  assert(str.chars == "good");

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  assert(code == OpCode.OP_PRINT);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  jump = (short)(*func.chunk.code << 8);
  func.chunk.code++;
  jump |= *func.chunk.code;

  offset = (int) (func.chunk.code - start);
  func.chunk.code++;

  assert(code == OpCode.OP_JUMP);
  assert(offset + jump + 1 == 15);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  assert(code == OpCode.OP_POP);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  str = object::as_string(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_CONSTANT);
  assert(str.chars == "bad");

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  assert(code == OpCode.OP_PRINT);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_NIL);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_RETURN);
}

fn void test_compiler_for_statement() @test {
  vm::initVm();
  ObjFunction* func = compiler::compile("for (var a = 0; a < 3; a = a + 1)\n {\n print a;\n}\0");
  
  char* start = func.chunk.code;

  OpCode code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  double value = value::as_number(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_CONSTANT);
  assert(value == 0);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  char slot = *func.chunk.code++;

  assert(code == OpCode.OP_GET_LOCAL);
  assert(slot == 1);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  value = value::as_number(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_CONSTANT);
  assert(value == 3);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  assert(code == OpCode.OP_LESS);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  short jump = (short)(*func.chunk.code << 8);
  func.chunk.code++;
  jump |= *func.chunk.code;

  int offset = (int) (func.chunk.code - start);
  func.chunk.code++;

  assert(code == OpCode.OP_JUMP_IF_FALSE);
  assert(offset + jump + 1 == 31);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  assert(code == OpCode.OP_POP);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  jump = (short)(*func.chunk.code << 8);
  func.chunk.code++;
  jump |= *func.chunk.code;

  offset = (int) (func.chunk.code - start);
  func.chunk.code++;

  assert(code == OpCode.OP_JUMP);
  assert(offset + jump + 1 == 25);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  slot = *func.chunk.code++;

  assert(code == OpCode.OP_GET_LOCAL);
  assert(slot == 1);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  value = value::as_number(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_CONSTANT);
  assert(value == 1);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  assert(code == OpCode.OP_ADD);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  slot = *func.chunk.code++;

  assert(code == OpCode.OP_SET_LOCAL);
  assert(slot == 1);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  assert(code == OpCode.OP_POP);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  jump = (short)(*func.chunk.code << 8);
  func.chunk.code++;
  jump |= *func.chunk.code;

  offset = (int) (func.chunk.code - start);
  func.chunk.code++;

  assert(code == OpCode.OP_LOOP);
  assert(offset + -jump + 1 == 2);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  slot = *func.chunk.code++;

  assert(code == OpCode.OP_GET_LOCAL);
  assert(slot == 1);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  assert(code == OpCode.OP_PRINT);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  jump = (short)(*func.chunk.code << 8);
  func.chunk.code++;
  jump |= *func.chunk.code;

  offset = (int) (func.chunk.code - start);
  func.chunk.code++;

  assert(code == OpCode.OP_LOOP);
  assert(offset + -jump + 1 == 14);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  assert(code == OpCode.OP_POP);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  assert(code == OpCode.OP_POP);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  assert(code == OpCode.OP_NIL);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  assert(code == OpCode.OP_RETURN);

}

fn void test_compiler_whilte_statement() @test {
  vm::initVm();
  ObjFunction* func = compiler::compile("var a = 0;\nwhile (a < 3)\n{\n print a;\n a = a + 1;\n}\0");

  char* start = func.chunk.code;

  OpCode code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  double value = value::as_number(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_CONSTANT);
  assert(value == 0);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  ObjString* global = object::as_string(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_DEFINE_GLOBAL);
  assert(global.chars == "a");

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  global = object::as_string(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_GET_GLOBAL);
  assert(global.chars == "a");

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  value = value::as_number(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_CONSTANT);
  assert(value == 3);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_LESS);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  short jump = (short)(*func.chunk.code << 8);
  func.chunk.code++;
  jump |= *func.chunk.code;

  int offset = (int) (func.chunk.code - start);
  func.chunk.code++;

  assert(code == OpCode.OP_JUMP_IF_FALSE);
  assert(offset + jump + 1 == 27);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_POP);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  global = object::as_string(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_GET_GLOBAL);
  assert(global.chars == "a");

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_PRINT);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  global = object::as_string(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_GET_GLOBAL);
  assert(global.chars == "a");

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  value = value::as_number(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_CONSTANT);
  assert(value == 1);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_ADD);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  global = object::as_string(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_SET_GLOBAL);
  assert(global.chars == "a");

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_POP);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  jump = (short)(*func.chunk.code << 8);
  func.chunk.code++;
  jump |= *func.chunk.code;

  offset = (int) (func.chunk.code - start);
  func.chunk.code++;

  assert(code == OpCode.OP_LOOP);
  assert(offset + -jump + 1 == 4);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_POP);
  
  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_NIL);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_RETURN);

}

fn void test_compiler_block_empty() @test {
  vm::initVm();
  ObjFunction* func = compiler::compile("{}\0");

  OpCode code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_NIL);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_RETURN);

}

fn void test_compiler_block_scope() @test {
  vm::initVm();
  ObjFunction* func = compiler::compile("var a = \"outer\";\n{\nvar a = \"inner\";\n}\0");

  OpCode code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  ObjString* global = object::as_string(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_CONSTANT);
  assert(global.chars == "outer");

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  global = object::as_string(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_DEFINE_GLOBAL);
  assert(global.chars == "a");

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  global = object::as_string(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_CONSTANT);
  assert(global.chars == "inner");

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_POP);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_NIL);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_RETURN);

}

fn void test_compiler_fun_empty_body() @test {
  vm::initVm();
  ObjFunction* func = compiler::compile("fun f() {}\nf();\0");

  OpCode code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  ObjFunction* fun = object::as_function(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_CLOSURE);
  assert(fun.name.chars == "f");
  assert(fun.arity == 0);
  assert(fun.upvalueCount == 0);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  ObjString* global = object::as_string(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_DEFINE_GLOBAL);
  assert(global.chars == "f");


  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  global = object::as_string(func.chunk.constants.values[*func.chunk.code]);
  func.chunk.code++;

  assert(code == OpCode.OP_GET_GLOBAL);
  assert(global.chars == "f");

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;

  char slot = *func.chunk.code;
  func.chunk.code++;
  
  assert(code == OpCode.OP_CALL);
  assert(slot == 0);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_POP);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_NIL);

  code = opcode::from(*func.chunk.code);
  func.chunk.code++;
  
  assert(code == OpCode.OP_RETURN);

}

fn void test_compiler_fun_recursion() @test {

}