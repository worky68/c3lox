# C3Lox

Implementation of the Lox language VM interpreter from [Crafting Interpreters](https://github.com/munificent/craftinginterpreters) in the [C3](https://github.com/c3lang/c3c) language. Nearly a direct port from the book that uses a few features from C3.

## Building and Using

### Prerequisites

You'll need to install the [C3 compiler](https://github.com/c3lang/c3c/releases/tag/latest) as well as its prerequisites for your environment and ensure its on your path.

### Building

The default build is the optimized build without debug information.

```bash
$ c3c build
```
This produces the ```lox``` interpreter executable under the ```build``` directory.

To produce a debug build.

```bash
$ c3c build loxd
```
This produces the enables debug information as well as debug feature flags 
```DEBUG_PRINT_CODE``` and ```DEBUG_TRACE_EXECUTION``` enabled. These assist in debugging the VM instructions during execution and are implemented in the book. There are also feature flags ```DEBUG_LOG_GC``` and ```DEBUG_STRESS_GC```to debug the garbage collector from the book available that can be added in the ```project.json``` file used by the C3 compiler.

### Using

Pass a lox file to the executable.

```bash
$ ./build/lox test.lox
```
or enter REPL mode by executing without any arguments.

```bash
$ ./build/lox
```
To leave the REPL type ```exit```

```bash
./build/lox
> exit
```

There are example files located in the examples directory that you can use to get started.

## License

This project is licensed under the Unlicense - see the [LICENSE](LICENSE) file for details

## Acknowledgments

* [Robert Nystrom for the excellent book Crafting Interpreters](https://craftinginterpreters.com/)