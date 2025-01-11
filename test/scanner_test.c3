import scanner;
import std::io;

fn void test_scanner_identifiers() @test {
  scanner::initScanner("andy formless fo _ _123 _abc ab123 abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890_\0");

  Token token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_IDENTIFIER);
  assert(token.value == "andy");
  assert(token.length == 4);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_IDENTIFIER);
  assert(token.value == "formless");
  assert(token.length == 8);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_IDENTIFIER);
  assert(token.value == "fo");
  assert(token.length == 2);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_IDENTIFIER);
  assert(token.value == "_");
  assert(token.length == 1);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_IDENTIFIER);
  assert(token.value == "_123");
  assert(token.length == 4);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_IDENTIFIER);
  assert(token.value == "_abc");
  assert(token.length == 4);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_IDENTIFIER);
  assert(token.value == "ab123");
  assert(token.length == 5);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_IDENTIFIER);
  assert(token.value == "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890_");
  assert(token.length == 63);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_EOF);
  assert(token.value == "");
  assert(token.length == 0);
  assert(token.line == 1);

}

fn void test_scanner_keywords() @test {
  scanner::initScanner("and class else false for fun if nil or return super this true var while\0");

  Token token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_AND);
  assert(token.value == "and");
  assert(token.length == 3);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_CLASS);
  assert(token.value == "class");
  assert(token.length == 5);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_ELSE);
  assert(token.value == "else");
  assert(token.length == 4);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_FALSE);
  assert(token.value == "false");
  assert(token.length == 5);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_FOR);
  assert(token.value == "for");
  assert(token.length == 3);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_FUN);
  assert(token.value == "fun");
  assert(token.length == 3);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_IF);
  assert(token.value == "if");
  assert(token.length == 2);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_NIL);
  assert(token.value == "nil");
  assert(token.length == 3);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_OR);
  assert(token.value == "or");
  assert(token.length == 2);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_RETURN);
  assert(token.value == "return");
  assert(token.length == 6);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_SUPER);
  assert(token.value == "super");
  assert(token.length == 5);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_THIS);
  assert(token.value == "this");
  assert(token.length == 4);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_TRUE);
  assert(token.value == "true");
  assert(token.length == 4);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_VAR);
  assert(token.value == "var");
  assert(token.length == 3);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_WHILE);
  assert(token.value == "while");
  assert(token.length == 5);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_EOF);
  assert(token.value == "");
  assert(token.length == 0);
  assert(token.line == 1);

}

fn void test_scanner_numbers() @test {
  scanner::initScanner("123\n123.456\n.456\n123.\0");

  Token token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_NUMBER);
  assert(token.value == "123");
  assert(token.length == 3);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_NUMBER);
  assert(token.value == "123.456");
  assert(token.length == 7);
  assert(token.line == 2);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_DOT);
  assert(token.value == ".");
  assert(token.length == 1);
  assert(token.line == 3);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_NUMBER);
  assert(token.value == "456");
  assert(token.length == 3);
  assert(token.line == 3);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_NUMBER);
  assert(token.value == "123");
  assert(token.length == 3);
  assert(token.line == 4);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_DOT);
  assert(token.value == ".");
  assert(token.length == 1);
  assert(token.line == 4);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_EOF);
  assert(token.value == "");
  assert(token.length == 0);
  assert(token.line == 4);

}

fn void test_scanner_punctuators() @test {
  scanner::initScanner("(){};,=+-*!!===<=>=<>/.\0");

  Token token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_LEFT_PAREN);
  assert(token.value == "(");
  assert(token.length == 1);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_RIGHT_PAREN);
  assert(token.value == ")");
  assert(token.length == 1);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_LEFT_BRACE);
  assert(token.value == "{");
  assert(token.length == 1);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_RIGHT_BRACE);
  assert(token.value == "}");
  assert(token.length == 1);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_SEMICOLON);
  assert(token.value == ";");
  assert(token.length == 1);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_COMMA);
  assert(token.value == ",");
  assert(token.length == 1);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_EQUAL);
  assert(token.value == "=");
  assert(token.length == 1);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_PLUS);
  assert(token.value == "+");
  assert(token.length == 1);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_MINUS);
  assert(token.value == "-");
  assert(token.length == 1);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_STAR);
  assert(token.value == "*");
  assert(token.length == 1);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_BANG);
  assert(token.value == "!");
  assert(token.length == 1);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_BANG_EQUAL);
  assert(token.value == "!=");
  assert(token.length == 2);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_EQUAL_EQUAL);
  assert(token.value == "==");
  assert(token.length == 2);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_LESS_EQUAL);
  assert(token.value == "<=");
  assert(token.length == 2);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_GREATER_EQUAL);
  assert(token.value == ">=");
  assert(token.length == 2);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_LESS);
  assert(token.value == "<");
  assert(token.length == 1);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_GREATER);
  assert(token.value == ">");
  assert(token.length == 1);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_SLASH);
  assert(token.value == "/");
  assert(token.length == 1);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_DOT);
  assert(token.value == ".");
  assert(token.length == 1);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_EOF);
  assert(token.value == "");
  assert(token.length == 0);
  assert(token.line == 1);

}


fn void test_scanner_strings() @test {
  scanner::initScanner("\"\" \"string\"\0");

  Token token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_STRING);
  assert(token.value == "\"\"");
  assert(token.length == 2);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_STRING);
  assert(token.value == "\"string\"");
  assert(token.length == 8);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_EOF);
  assert(token.value == "");
  assert(token.length == 0);
  assert(token.line == 1);

}

fn void test_scanner_whitespace() @test {
  scanner::initScanner("space    tabs				newlines\n\n\n\nend\0");

  Token token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_IDENTIFIER);
  assert(token.value == "space");
  assert(token.length == 5);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_IDENTIFIER);
  assert(token.value == "tabs");
  assert(token.length == 4);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_IDENTIFIER);
  assert(token.value == "newlines");
  assert(token.length == 8);
  assert(token.line == 1);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_IDENTIFIER);
  assert(token.value == "end");
  assert(token.length == 3);
  assert(token.line == 5);

  token = scanner::scanToken();

  assert(token.type == scanner::TokenType.TOKEN_EOF);
  assert(token.value == "");
  assert(token.length == 0);
  assert(token.line == 5);

}