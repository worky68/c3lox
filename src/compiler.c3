import std::io;
import libc;

import scanner;
import value;
import object;
import chunk;
import opcode;
import common;
import memory;
import debug;

const UINT8_COUNT = 256;

struct Parser {
  Token current;
  Token previous;
  bool hadError;
  bool panicMode;
}

enum Precedence {
  PREC_NONE,
  PREC_ASSIGNMENT,  // =
  PREC_OR,          // or
  PREC_AND,         // and
  PREC_EQUALITY,    // == !=
  PREC_COMPARISON,  // < > <= >=
  PREC_TERM,        // + -
  PREC_FACTOR,      // * /
  PREC_UNARY,       // ! -
  PREC_CALL,        // . ()
  PREC_PRIMARY
}

def ParseFn = fn void(bool canAssign); 

struct ParseRule {
  ParseFn prefix;
  ParseFn infix;
  Precedence precedence;
}

struct Local {
  Token name;
  int depth;
  bool isCaptured;
}

struct Upvalue {
  char index;
  bool isLocal;
}

enum FunctionType {
  TYPE_FUNCTION,
  TYPE_INITIALIZER,
  TYPE_METHOD,
  TYPE_SCRIPT
}

struct Compiler {
  Compiler* enclosing;
  ObjFunction* function;
  FunctionType type;
  Local[UINT8_COUNT] locals;
  int localCount;
  Upvalue[UINT8_COUNT] upvalues;
  int scopeDepth;
}

struct ClassCompiler {
  ClassCompiler* enclosing;
  bool hasSuperclass;
}

Parser parser;
Compiler* current;
ClassCompiler* currentClass;

fn void initCompiler(Compiler* compiler, FunctionType type) {
  compiler.enclosing = current;
  compiler.function = null;
  compiler.type = type;
  compiler.localCount = 0;
  compiler.scopeDepth = 0;
  compiler.function = object::newFunction();
  current = compiler;
  if (type != TYPE_SCRIPT) {
    current.function.name = object::copyString(parser.previous.value, parser.previous.length);
  }

  Local* local = &current.locals[current.localCount++];
  local.depth = 0;
  local.isCaptured = false;
  if (type != TYPE_FUNCTION) {
    local.name.value = "this";
    local.name.length = 4;
  } else {
    local.name.value = "";
    local.name.length = 0;
  }
}

fn Chunk* currentChunk() {
  return &current.function.chunk;
}

fn void errorAt(Token* token, String message) {
  if (parser.panicMode) return;
  parser.panicMode = true;
  io::fprintf(io::stderr(), "[line %d] Error", token.line)!!; // TODO handle error gracefully

  if (token.type == TokenType.TOKEN_EOF) {
    io::fprintf(io::stderr(), " at end")!!; // TODO handle error gracefully
  } else if (token.type == TokenType.TOKEN_ERROR) {
    // Nothing.
  } else {
    io::fprintf(io::stderr(), " at '%s'", token.value)!!; // TODO handle error gracefully
  }

  io::fprintf(io::stderr(), ": %s\n", message)!!; // TODO handle error gracefully
  parser.hadError = true;
}

fn void error(String message) {
  errorAt(&parser.previous, message);
}

fn void errorAtCurrent(String message) {
  errorAt(&parser.current, message);
}

fn void advance() {
  parser.previous = parser.current;

  for (;;) {
    parser.current = scanner::scanToken();
    if (parser.current.type != TokenType.TOKEN_ERROR) break;

    errorAtCurrent(parser.current.value);
  }
}

fn void consume(TokenType type, String message) {
  if (parser.current.type == type) {
    advance();
    return;
  }

  errorAtCurrent(message);
}

fn bool match(TokenType type) {
  if (!check(type)) return false;
  advance();
  return true;
}

fn bool check(TokenType type) {
  return parser.current.type == type;
}

fn void emitByte(char byte) {
  chunk::writeChunk(currentChunk(), byte, parser.previous.line);
}

fn void emitBytes(char byte1, char byte2) {
  emitByte(byte1);
  emitByte(byte2);
}

fn void emitLoop(int loopStart) {
  emitByte(OpCode.OP_LOOP);

  int offset = currentChunk().count - loopStart + 2;
  if (offset > common::UINT16_MAX) error("Loop body too large.");

  emitByte((char) (offset >> 8) & 0xff);
  emitByte((char) offset & 0xff);
}

fn int emitJump(char instruction) {
  emitByte(instruction);
  emitByte(0xff);
  emitByte(0xff);
  return currentChunk().count - 2;
}

fn void emitReturn() {
  if (current.type == TYPE_INITIALIZER) {
    emitBytes(OpCode.OP_GET_LOCAL, 0);
  } else {
    emitByte(OpCode.OP_NIL);
  }

  emitByte(OpCode.OP_RETURN);
}

fn char makeConstant(Value value) {
  int constant = chunk::addConstant(currentChunk(), value);
  if (constant > common::UINT8_MAX) { // TODO support UINT16 constants
    error("Too many constants in one chunk.");
    return 0;
  }

  return (char)constant;
}

fn void emitConstant(Value value) {
  emitBytes(OpCode.OP_CONSTANT, makeConstant(value));
}

fn void patchJump(int offset) {
  // -2 to adjust for the bytecode for the jump offset itself.
  int jump = currentChunk().count - offset - 2;

  if (jump > common::UINT16_MAX) {
    error("Too much code to jump over.");
  }

  currentChunk().code[offset] = (char) (jump >> 8) & 0xff;
  currentChunk().code[offset + 1] = (char) jump & 0xff;
}

fn ObjFunction* endCompiler() {
  emitReturn();
  ObjFunction* function = current.function;

  $if $feature(DEBUG_PRINT_CODE):
    if (!parser.hadError) {
      debug::disassembleChunk(currentChunk(), function.name != null ? function.name.chars : "<script>");
    }
  $endif

  current = current.enclosing;
  return function;
}

fn void beginScope() {
  current.scopeDepth++;
}

fn void endScope() {
  current.scopeDepth--;

  while (current.localCount > 0 && current.locals[current.localCount - 1].depth > current.scopeDepth) {
    if (current.locals[current.localCount - 1].isCaptured) {
      emitByte((char) OpCode.OP_CLOSE_UPVALUE);
    } else {
      emitByte((char) OpCode.OP_POP);
    }
    current.localCount--;
  }
}

fn void binary(bool canAssign) {
  TokenType operatorType = parser.previous.type;
  ParseRule* rule = getRule(operatorType);
  parsePrecedence((Precedence)(rule.precedence + 1));

  switch (operatorType) {
    case TOKEN_BANG_EQUAL:    emitBytes((char) OpCode.OP_EQUAL, (char) OpCode.OP_NOT);
    case TOKEN_EQUAL_EQUAL:   emitByte((char) OpCode.OP_EQUAL);
    case TOKEN_GREATER:       emitByte((char) OpCode.OP_GREATER);
    case TOKEN_GREATER_EQUAL: emitBytes((char) OpCode.OP_LESS, (char) OpCode.OP_NOT);
    case TOKEN_LESS:          emitByte((char) OpCode.OP_LESS);
    case TOKEN_LESS_EQUAL:    emitBytes((char) OpCode.OP_GREATER, (char) OpCode.OP_NOT);
    case TOKEN_PLUS:          emitByte((char) OpCode.OP_ADD);
    case TOKEN_MINUS:         emitByte((char) OpCode.OP_SUBTRACT);
    case TOKEN_STAR:          emitByte((char) OpCode.OP_MULTIPLY);
    case TOKEN_SLASH:         emitByte((char) OpCode.OP_DIVIDE);
    default: return; // Unreachable.
  }
}

fn void call(bool canAssign) {
  char argCount = argumentList();
  emitBytes((char) OpCode.OP_CALL, argCount);
}

fn void dot(bool canAssign) {
  consume(TOKEN_IDENTIFIER, "Expect property name after '.'.");
  char name = identifierConstant(&parser.previous);

  if (canAssign && match(TokenType.TOKEN_EQUAL)) {
    expression();
    emitBytes(OpCode.OP_SET_PROPERTY, name);
  } else if (match(TOKEN_LEFT_PAREN)) {
    char argCount = argumentList();
    emitBytes(OpCode.OP_INVOKE, name);
    emitByte(argCount);
  } else {
    emitBytes(OpCode.OP_GET_PROPERTY, name);
  }
}

fn void literal(bool canAssign) {
  switch (parser.previous.type) {
    case TOKEN_FALSE: emitByte(OpCode.OP_FALSE);
    case TOKEN_NIL: emitByte(OpCode.OP_NIL);
    case TOKEN_TRUE: emitByte(OpCode.OP_TRUE);
    default: return; // Unreachable.
  }
}

fn void grouping(bool canAssign) {
  expression();
  consume(TOKEN_RIGHT_PAREN, "Expected ')' after expression.");
}

fn void number(bool canAssign) {
  double value = libc::strtod(parser.previous.value, null);
  emitConstant(value::number_val(value));
}

fn void string(bool canAssign) {
  emitConstant(value::obj_val(object::copyString(((char*)parser.previous.value) + 1, parser.previous.length - 2)));
}

fn void namedVariable(Token name, bool canAssign) {
  char getOp, setOp;
  int arg = resolveLocal(current, &name);
  if (arg != -1) {
    getOp = OpCode.OP_GET_LOCAL;
    setOp = OpCode.OP_SET_LOCAL;
  } else if ((arg = resolveUpvalue(current, &name)) != -1) {
    getOp = OpCode.OP_GET_UPVALUE;
    setOp = OpCode.OP_SET_UPVALUE;
  } else {
    arg = identifierConstant(&name);
    getOp = OpCode.OP_GET_GLOBAL;
    setOp = OpCode.OP_SET_GLOBAL;
  }

  if (canAssign && match(TokenType.TOKEN_EQUAL)) {
    expression();
    emitBytes(setOp, (char) arg);
  } else {
    emitBytes(getOp, (char) arg);
  }
}

fn void variable(bool canAssign) {
  namedVariable(parser.previous, canAssign);
}

fn Token syntheticToken(String text) {
  Token token;
  token.value = text;
  token.length = text.len;
  return token;
}

fn void super(bool canAssign) {
  if (currentClass == null) {
    error("Can't use 'super' outside of a class.");
  } else if (!currentClass.hasSuperclass) {
    error("Can't use 'super' in a class with no superclass.");
  }

  consume(TokenType.TOKEN_DOT, "Expect '.' after 'super'.");
  consume(TokenType.TOKEN_IDENTIFIER, "Expect superclass method name.");
  char name = identifierConstant(&parser.previous);

  namedVariable(syntheticToken("this"), false);
  if (match(TokenType.TOKEN_LEFT_PAREN)) {
    char argCount = argumentList();
    namedVariable(syntheticToken("super"), false);
    emitBytes(OpCode.OP_SUPER_INVOKE, name);
    emitByte(argCount);
  } else {
    namedVariable(syntheticToken("super"), false);
    emitBytes(OpCode.OP_GET_SUPER, name);
  }
}

fn void this(bool canAssign) {
  if (currentClass == null) {
    error("Can't use 'this' outside of a class.");
    return;
  }
  variable(false);
}

fn void unary(bool canAssign) {
  TokenType operatorType = parser.previous.type;

  // Compile the operand.
  parsePrecedence(PREC_UNARY);

  // Emit the operator instruction.
  switch (operatorType) {
    case TOKEN_BANG: emitByte(OpCode.OP_NOT);
    case TOKEN_MINUS: emitByte(OpCode.OP_NEGATE);
    default: return; // Unreachable.
  }
}

fn void parsePrecedence(Precedence precedence) {
  advance();
  ParseFn prefixRule = getRule(parser.previous.type).prefix;
  if (prefixRule == null) {
    error("Expected expression.");
    return;
  }

  bool canAssign = precedence <= PREC_ASSIGNMENT;
  prefixRule(canAssign);

  while (precedence <= getRule(parser.current.type).precedence) {
    advance();
    ParseFn infixRule = getRule(parser.previous.type).infix;
    infixRule(canAssign);
  }

}

fn char identifierConstant(Token* name) {
  return makeConstant(value::obj_val(object::copyString(name.value, name.length)));
}

fn bool identifiersEqual(Token* a, Token* b) {
  if (a.length != b.length) return false;
  return libc::memcmp(a.value, b.value, a.length) == 0;
}

fn int resolveLocal(Compiler* compiler, Token* name) {
  for (int i = compiler.localCount - 1; i >= 0; i--) {
    Local* local = &compiler.locals[i];
    if (identifiersEqual(name, &local.name)) {
      if (local.depth == -1) {
        error("Can't read local variable in its own initializer.");
      }
      return i;
    }
  }

  return -1;
}

fn int resolveUpvalue(Compiler* compiler, Token* name) {
  if (compiler.enclosing == null) return -1;

  int local = resolveLocal(compiler.enclosing, name);
  if (local != -1) {
    compiler.enclosing.locals[local].isCaptured = true;
    return addUpvalue(compiler, (char)local, true);
  }

  int upvalue = resolveUpvalue(compiler.enclosing, name);
  if (upvalue != -1) {
    return addUpvalue(compiler, (char)upvalue, false);
  }

  return -1;
}

fn int addUpvalue(Compiler* compiler, char index, bool isLocal) {
  int upvalueCount = compiler.function.upvalueCount;

  for (int i = 0; i < upvalueCount; i++) {
    Upvalue* upvalue = &compiler.upvalues[i];
    if (upvalue.index == index && upvalue.isLocal == isLocal) {
      return i;
    }
  }

  if (upvalueCount == UINT8_COUNT) {
    error("Too many closure variables in function.");
    return 0;
  }

  compiler.upvalues[upvalueCount].isLocal = isLocal;
  compiler.upvalues[upvalueCount].index = index;
  return compiler.function.upvalueCount++;
}

fn void addLocal(Token name) {

  if (current.localCount == UINT8_COUNT) {
    error("Too many local variables in function.");
    return;
  }

  Local* local = &current.locals[current.localCount++];
  local.name = name;
  local.depth = current.scopeDepth;
  local.depth = -1;
  local.isCaptured = false;
}

fn void declareVariable() {
  if (current.scopeDepth == 0) return;

  Token* name = &parser.previous;
  for (int i = current.localCount - 1; i >= 0; i--) {
    Local* local = &current.locals[i];
    if (local.depth != -1 && local.depth < current.scopeDepth) {
      break; 
    }

    if (identifiersEqual(name, &local.name)) {
      error("Already a variable with this name in this scope.");
    }
  }
  addLocal(*name);
}

fn char parseVariable(String errorMessage) {
  consume(TokenType.TOKEN_IDENTIFIER, errorMessage);

  declareVariable();
  if (current.scopeDepth > 0) return 0;

  return identifierConstant(&parser.previous);
}

fn void markInitialized() {
  if (current.scopeDepth == 0) return;
  current.locals[current.localCount - 1].depth = current.scopeDepth;
}

fn void defineVariable(char global) {
  if (current.scopeDepth > 0) {
    markInitialized();
    return;
  }

  emitBytes(OpCode.OP_DEFINE_GLOBAL, global);
}

fn char argumentList() {
  char argCount = 0;
  if (!check(TokenType.TOKEN_RIGHT_PAREN)) {
    do {
      expression();
      if (argCount == 255) {
        error("Can't have more than 255 arguments.");
      }
      argCount++;
    } while (match(TokenType.TOKEN_COMMA));
  }
  consume(TokenType.TOKEN_RIGHT_PAREN, "Expect ')' after arguments.");
  return argCount;
}

fn void and(bool canAssign) {
  int endJump = emitJump(OpCode.OP_JUMP_IF_FALSE);

  emitByte(OpCode.OP_POP);
  parsePrecedence(PREC_AND);

  patchJump(endJump);
}

fn void or(bool canAssign) {
  int elseJump = emitJump(OpCode.OP_JUMP_IF_FALSE);
  int endJump = emitJump(OpCode.OP_JUMP);

  patchJump(elseJump);
  emitByte(OpCode.OP_POP);

  parsePrecedence(PREC_OR);
  patchJump(endJump);
}

fn ParseRule* getRule(TokenType type) {
  return &rules[type];
}

ParseRule[*] rules = {
  [TokenType.TOKEN_LEFT_PAREN]    = {&grouping, &call,    PREC_CALL},
  [TokenType.TOKEN_RIGHT_PAREN]   = {null,      null,     PREC_NONE},
  [TokenType.TOKEN_LEFT_BRACE]    = {null,      null,     PREC_NONE}, 
  [TokenType.TOKEN_RIGHT_BRACE]   = {null,      null,     PREC_NONE},
  [TokenType.TOKEN_COMMA]         = {null,      null,     PREC_NONE},
  [TokenType.TOKEN_DOT]           = {null,      &dot,     PREC_CALL},
  [TokenType.TOKEN_MINUS]         = {&unary,    &binary,  PREC_TERM},
  [TokenType.TOKEN_PLUS]          = {null,      &binary,  PREC_TERM},
  [TokenType.TOKEN_SEMICOLON]     = {null,      null,     PREC_NONE},
  [TokenType.TOKEN_SLASH]         = {null,      &binary,  PREC_FACTOR},
  [TokenType.TOKEN_STAR]          = {null,      &binary,  PREC_FACTOR},
  [TokenType.TOKEN_BANG]          = {&unary,    null,     PREC_NONE},
  [TokenType.TOKEN_BANG_EQUAL]    = {null,      &binary,  PREC_EQUALITY},
  [TokenType.TOKEN_EQUAL]         = {null,      null,     PREC_NONE},
  [TokenType.TOKEN_EQUAL_EQUAL]   = {null,      &binary,  PREC_EQUALITY},
  [TokenType.TOKEN_GREATER]       = {null,      &binary,  PREC_COMPARISON},
  [TokenType.TOKEN_GREATER_EQUAL] = {null,      &binary,  PREC_COMPARISON},
  [TokenType.TOKEN_LESS]          = {null,      &binary,  PREC_COMPARISON},
  [TokenType.TOKEN_LESS_EQUAL]    = {null,      &binary,  PREC_COMPARISON},
  [TokenType.TOKEN_IDENTIFIER]    = {&variable, null,     PREC_NONE},
  [TokenType.TOKEN_STRING]        = {&string,   null,     PREC_NONE},
  [TokenType.TOKEN_NUMBER]        = {&number,   null,     PREC_NONE},
  [TokenType.TOKEN_AND]           = {null,      &and,     PREC_AND},
  [TokenType.TOKEN_CLASS]         = {null,      null,     PREC_NONE},
  [TokenType.TOKEN_ELSE]          = {null,      null,     PREC_NONE},
  [TokenType.TOKEN_FALSE]         = {&literal,  null,     PREC_NONE},
  [TokenType.TOKEN_FOR]           = {null,      null,     PREC_NONE},
  [TokenType.TOKEN_FUN]           = {null,      null,     PREC_NONE},
  [TokenType.TOKEN_IF]            = {null,      null,     PREC_NONE},
  [TokenType.TOKEN_NIL]           = {&literal,  null,     PREC_NONE},
  [TokenType.TOKEN_OR]            = {null,      &or,      PREC_OR},
  [TokenType.TOKEN_PRINT]         = {null,      null,     PREC_NONE},
  [TokenType.TOKEN_RETURN]        = {null,      null,     PREC_NONE},
  [TokenType.TOKEN_SUPER]         = {&super,    null,     PREC_NONE},
  [TokenType.TOKEN_THIS]          = {&this,     null,     PREC_NONE},
  [TokenType.TOKEN_TRUE]          = {&literal,  null,     PREC_NONE},
  [TokenType.TOKEN_VAR]           = {null,      null,     PREC_NONE},
  [TokenType.TOKEN_WHILE]         = {null,      null,     PREC_NONE},
  [TokenType.TOKEN_ERROR]         = {null,      null,     PREC_NONE},
  [TokenType.TOKEN_EOF]           = {null,      null,     PREC_NONE},
};

fn void expression() {
  parsePrecedence(PREC_ASSIGNMENT);
}

fn void block() {
  while (!check(TokenType.TOKEN_RIGHT_BRACE) && !check(TokenType.TOKEN_EOF)) {
    declaration();
  }
  consume(TokenType.TOKEN_RIGHT_BRACE, "Expect '}' after block.");
}

fn void function(FunctionType type) {
  Compiler compiler;
  initCompiler(&compiler, type);
  beginScope(); 

  consume(TokenType.TOKEN_LEFT_PAREN, "Expect '(' after function name.");
  if (!check(TokenType.TOKEN_RIGHT_PAREN)) {
    do {
      current.function.arity++;
      if (current.function.arity > 255) {
        errorAtCurrent("Can't have more than 255 parameters.");
      }
      char constant = parseVariable("Expect parameter name.");
      defineVariable(constant);
    } while (match(TokenType.TOKEN_COMMA));
  }
  consume(TokenType.TOKEN_RIGHT_PAREN, "Expect ')' after parameters.");
  consume(TokenType.TOKEN_LEFT_BRACE, "Expect '{' before function body.");
  block();

  ObjFunction* function = endCompiler();
  emitBytes(OpCode.OP_CLOSURE, makeConstant(value::obj_val(function)));

  for (int i = 0; i < function.upvalueCount; i++) {
    emitByte(compiler.upvalues[i].isLocal ? 1 : 0);
    emitByte(compiler.upvalues[i].index);
  }
}

fn void method() {
  consume(TOKEN_IDENTIFIER, "Expect method name.");
  char constant = identifierConstant(&parser.previous);

  FunctionType type = TYPE_METHOD;
  if (parser.previous.length == 4 && libc::memcmp(parser.previous.value, "init", 4) == 0) {
    type = TYPE_INITIALIZER;
  }
  function(type);
  emitBytes(OpCode.OP_METHOD, constant);
}

fn void classDeclaration() {
  consume(TokenType.TOKEN_IDENTIFIER, "Expect class name.");
  Token className = parser.previous;
  char nameConstant = identifierConstant(&parser.previous);
  declareVariable();

  emitBytes(OpCode.OP_CLASS, nameConstant);
  defineVariable(nameConstant);

  ClassCompiler classCompiler;
  classCompiler.hasSuperclass = false;
  classCompiler.enclosing = currentClass;
  currentClass = &classCompiler;

  if (match(TokenType.TOKEN_LESS)) {
    consume(TokenType.TOKEN_IDENTIFIER, "Expect superclass name.");
    variable(false);

    if (identifiersEqual(&className, &parser.previous)) {
      error("A class can't inherit from itself.");
    }

    beginScope();
    addLocal(syntheticToken("super"));
    defineVariable(0);

    namedVariable(className, false);
    emitByte(OpCode.OP_INHERIT);
    classCompiler.hasSuperclass = true;
  }

  namedVariable(className, false);
  consume(TokenType.TOKEN_LEFT_BRACE, "Expect '{' before class body.");
  while (!check(TokenType.TOKEN_RIGHT_BRACE) && !check(TokenType.TOKEN_EOF)) {
    method();
  }
  consume(TokenType.TOKEN_RIGHT_BRACE, "Expect '}' after class body.");
  emitByte(OpCode.OP_POP);

  if (classCompiler.hasSuperclass) {
    endScope();
  }

  currentClass = currentClass.enclosing;
}

fn void funDeclaration() {
  char global = parseVariable("Expect function name.");
  markInitialized();
  function(FunctionType.TYPE_FUNCTION);
  defineVariable(global);
}

fn void varDeclaration() {
  char global = parseVariable("Expect variable name.");

  if (match(TokenType.TOKEN_EQUAL)) {
    expression();
  } else {
    emitByte(OpCode.OP_NIL);
  }
  consume(TokenType.TOKEN_SEMICOLON, "Expect ';' after variable declaration.");

  defineVariable(global);
}

fn void expressionStatement() {
  expression();
  consume(TOKEN_SEMICOLON, "Expect ';' after expression.");
  emitByte(OpCode.OP_POP);
}

fn void forStatement() {
  beginScope();
  consume(TokenType.TOKEN_LEFT_PAREN, "Expect '(' after 'for'.");
  if (match(TokenType.TOKEN_SEMICOLON)) {
    // No initializer.
  } else if (match(TokenType.TOKEN_VAR)) {
    varDeclaration();
  } else {
    expressionStatement();
  }

  int loopStart = currentChunk().count;
  int exitJump = -1;
  if (!match(TokenType.TOKEN_SEMICOLON)) {
    expression();
    consume(TokenType.TOKEN_SEMICOLON, "Expect ';' after loop condition.");

    // Jump out of the loop if the condition is false.
    exitJump = emitJump(OpCode.OP_JUMP_IF_FALSE);
    emitByte(OpCode.OP_POP); // Condition.
  }

  if (!match(TokenType.TOKEN_RIGHT_PAREN)) {
    int bodyJump = emitJump(OpCode.OP_JUMP);
    int incrementStart = currentChunk().count;
    expression();
    emitByte(OpCode.OP_POP);
    consume(TokenType.TOKEN_RIGHT_PAREN, "Expect ')' after for clauses.");

    emitLoop(loopStart);
    loopStart = incrementStart;
    patchJump(bodyJump);
  }

  statement();
  emitLoop(loopStart);

  if (exitJump != -1) {
    patchJump(exitJump);
    emitByte(OpCode.OP_POP); // Condition.
  }

  endScope();
}

fn void ifStatement() {
  consume(TokenType.TOKEN_LEFT_PAREN, "Expect '(' after 'if'.");
  expression();
  consume(TokenType.TOKEN_RIGHT_PAREN, "Expect ')' after condition."); 

  int thenJump = emitJump(OpCode.OP_JUMP_IF_FALSE);
  emitByte(OpCode.OP_POP);
  statement();

  int elseJump = emitJump(OpCode.OP_JUMP);

  patchJump(thenJump);
  emitByte(OpCode.OP_POP);

  if (match(TokenType.TOKEN_ELSE)) statement();
  patchJump(elseJump);
}

fn void printStatement() {
  expression();
  consume(TokenType.TOKEN_SEMICOLON, "Expect ';' after value.");
  emitByte(OpCode.OP_PRINT);
}

fn void returnStatement() {
  if (current.type == TYPE_SCRIPT) {
    error("Can't return from top-level code.");
  }

  if (match(TokenType.TOKEN_SEMICOLON)) {
    emitReturn();
  } else {
    if (current.type == TYPE_INITIALIZER) {
      error("Can't return a value from an initializer.");
    }
    
    expression();
    consume(TokenType.TOKEN_SEMICOLON, "Expect ';' after return value.");
    emitByte(OpCode.OP_RETURN);
  }
}

fn void whileStatement() {
  int loopStart = currentChunk().count;
  consume(TOKEN_LEFT_PAREN, "Expect '(' after 'while'.");
  expression();
  consume(TOKEN_RIGHT_PAREN, "Expect ')' after condition.");

  int exitJump = emitJump(OpCode.OP_JUMP_IF_FALSE);
  emitByte(OpCode.OP_POP);
  statement();
  emitLoop(loopStart);

  patchJump(exitJump);
  emitByte(OpCode.OP_POP);
}

fn void synchronize() {
  parser.panicMode = false;

  while (parser.current.type != TokenType.TOKEN_EOF) {
    if (parser.previous.type == TokenType.TOKEN_SEMICOLON) return;
    switch (parser.current.type) {
      case TOKEN_CLASS:
      case TOKEN_FUN:
      case TOKEN_VAR:
      case TOKEN_FOR:
      case TOKEN_IF:
      case TOKEN_WHILE:
      case TOKEN_PRINT:
      case TOKEN_RETURN:
        return;
      default:
        ; // Do nothing.
    }

    advance();
  }
}

fn void declaration() {
  if (match(TokenType.TOKEN_CLASS)) {
    classDeclaration();
  } else if (match(TokenType.TOKEN_FUN)) {
    funDeclaration();
  } else if (match(TokenType.TOKEN_VAR)) {
    varDeclaration();
  } else {
    statement();
  }

  if (parser.panicMode) synchronize();
}

fn void statement() {
  if (match(TokenType.TOKEN_PRINT)) {
    printStatement();
  } else if (match(TokenType.TOKEN_FOR)) {
    forStatement();
  } else if (match(TokenType.TOKEN_IF)) {
    ifStatement();
  } else if (match(TokenType.TOKEN_RETURN)) {
    returnStatement();
  } else if (match(TokenType.TOKEN_WHILE)) {
    whileStatement();
  } else if (match(TokenType.TOKEN_LEFT_BRACE)) {
    beginScope();
    block();
    endScope();
  } else {
    expressionStatement();
  }
}

fn ObjFunction* compile(String source) {
  scanner::initScanner(source);
  Compiler compiler;
  initCompiler(&compiler, TYPE_SCRIPT);
  
  parser.hadError = false;
  parser.panicMode = false;

  advance();

  while (!match(TokenType.TOKEN_EOF)) {
    declaration();
  }

  ObjFunction* function = endCompiler();
  return parser.hadError ? null : function;
}

fn void markCompilerRoots() {
  Compiler* compiler = current;
  while (compiler != null) {
    memory::markObject((Obj*)compiler.function);
    compiler = compiler.enclosing;
  }
}