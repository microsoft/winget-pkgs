<div align="center">

# VSS Programming Language

**A beginner-friendly, dynamically typed scripting language with clean, English-like syntax**

[![Version](https://img.shields.io/badge/version-2.2.2-blue?style=flat-square)](https://github.com/siddharth-1118/vss-language/releases/tag/v2.2.2)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
[![VS Code](https://img.shields.io/visual-studio-marketplace/v/saisiddharth.vss-language?label=VS%20Code&style=flat-square&color=007ACC)](https://marketplace.visualstudio.com/items?itemName=saisiddharth.vss-language)
[![WinGet](https://img.shields.io/badge/winget-VSS.VSS-0078D4?style=flat-square&logo=windows)](https://github.com/microsoft/winget-pkgs/pull/408829)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey?style=flat-square)](https://github.com/siddharth-1118/vss-language/releases)

<br/>

| 📦 [VSS Source Code](#-vss-source-code) | ⚙️ [Compiler Source Code](#️-compiler-source-code) | 🔧 [Runtime](#-runtime) | 📚 [Documentation / User Manual](#-documentation--user-manual) |
|:---:|:---:|:---:|:---:|

</div>

---

## Install VSS

### Windows

```powershell
irm https://raw.githubusercontent.com/siddharth-1118/vss-language/main/install/install.ps1 | iex
```

Or with WinGet:
```
winget install VSS.VSS
```

### Linux / macOS

```sh
curl -fsSL https://raw.githubusercontent.com/siddharth-1118/vss-language/main/install/install.sh | sh
```

---

## Quick Start

```vss
say "Hello, World!"
```

```vss
# Variables
name is "VSS"
version is 2.2.2

# Conditions
when version is greater than 2
    say "Welcome to " + name
end

# Loops
repeat 3 times
    say "VSS is simple!"
end
```

---

## 📦 VSS Source Code

The complete VSS language source is in the [`vss/`](vss/) directory.

| Path | Description |
|------|-------------|
| [`vss/src/`](vss/src/) | All C source files (compiler, VM, builtins, stdlib) |
| [`vss/include/`](vss/include/) | Public header files for all modules |
| [`vss/stdlib/`](vss/stdlib/) | Standard library modules (math, string, file, json, http…) |
| [`vss/examples/`](vss/examples/) | Example VSS programs |
| [`vss/Makefile`](vss/Makefile) | Build system — run `make` to compile |

### Build from Source

```bash
# Linux / macOS
git clone https://github.com/siddharth-1118/vss-language.git
cd vss-language/vss
make
./vss --version

# Windows (MSVC)
cd vss
nmake /f Makefile.win
vss.exe --version
```

---

## ⚙️ Compiler Source Code

The compiler is a multi-stage pipeline written in C, located in [`vss/src/`](vss/src/).

| File | Stage | Description |
|------|-------|-------------|
| [`lexer.c`](vss/src/lexer.c) | **Lexing** | Tokenises VSS source into a stream of tokens |
| [`parser.c`](vss/src/parser.c) | **Parsing** | Recursive-descent parser — builds the AST |
| [`ast.c`](vss/src/ast.c) | **AST** | Abstract Syntax Tree node definitions and utilities |
| [`semantic.c`](vss/src/semantic.c) | **Semantic Analysis** | Type checking, scope resolution, error diagnostics |
| [`compiler.c`](vss/src/compiler.c) | **Code Generation** | Walks the AST and emits bytecode chunks |
| [`chunk.c`](vss/src/chunk.c) | **Bytecode** | Bytecode chunk format and opcode table |
| [`main.c`](vss/src/main.c) | **Entry Point** | CLI driver — connects all stages |
| [`cli.c`](vss/src/cli.c) | **CLI** | `run`, `build`, `new`, `test`, `fmt`, `lint`, `docs` commands |

### Compiler Architecture

```
Source (.vss)
    │
    ▼
 Lexer (lexer.c)
    │  Token stream
    ▼
 Parser (parser.c)
    │  Abstract Syntax Tree
    ▼
 Semantic Analyser (semantic.c)
    │  Resolved AST + error diagnostics
    ▼
 Compiler / Code Gen (compiler.c)
    │  Bytecode chunks
    ▼
 VM (vm.c)  ──►  Output
```

See [`vss/docs/compiler-architecture.md`](vss/docs/compiler-architecture.md) for full design notes.

---

## 🔧 Runtime

The VSS runtime is a **register-less stack-based bytecode VM** with **Automatic Reference Counting (ARC)** for memory management.

| File | Description |
|------|-------------|
| [`vm.c`](vss/src/vm.c) | Core bytecode interpreter / execution loop |
| [`value.c`](vss/src/value.c) | Value types — numbers, strings, booleans, lists, maps |
| [`object.c`](vss/src/object.c) | Heap-allocated objects — Shapes, Closures, Blueprints, Generators |
| [`builtins.c`](vss/src/builtins.c) | Built-in functions (print, input, len, type, …) |
| [`env.c`](vss/src/env.c) | Variable environment / scope chain |
| [`interpreter.c`](vss/src/interpreter.c) | Tree-walk interpreter (fallback / debug mode) |
| [`platform.c`](vss/src/platform.c) | OS abstraction layer (Windows / Linux / macOS) |

### Runtime Features

| Feature | Description |
|---------|-------------|
| **ARC** | Zero-cost automatic memory management via reference counting |
| **Coroutines** | Stackful coroutines with `yield` / `resume` for cooperative concurrency |
| **Closures** | First-class functions capturing lexical environments |
| **Shapes** | Struct-like value types with named fields |
| **Blueprints** | Interfaces / protocols for polymorphism |
| **Pattern Matching** | Exhaustive `match` over `choice` algebraic types |
| **Standard Library** | `math`, `string`, `file`, `json`, `http`, `time`, `random`, `system`, `database`, `crypto`, `network` |

---

## 📚 Documentation / User Manual

| Document | Description |
|----------|-------------|
| [`vss/docs/vss-spec-v0.1.md`](vss/docs/vss-spec-v0.1.md) | Full VSS language specification |
| [`vss/docs/compiler-architecture.md`](vss/docs/compiler-architecture.md) | Compiler internals deep-dive |
| [`vss/docs/lexer-implementation.md`](vss/docs/lexer-implementation.md) | Lexer design and token reference |
| [`vss/examples/`](vss/examples/) | Runnable example programs |
| [`CHANGELOG.md`](vss/CHANGELOG.md) | Full version history |

### Language Reference

#### Variables
```vss
name is "Alice"
age is 25
score is 98.5
active is true
```

#### Functions
```vss
task greet with person
    say "Hello, " + person
end

greet "World"
```

#### Shapes (Structs)
```vss
shape Point
    x
    y
end

p is Point with x as 10 y as 20
say p.x
```

#### Closures & Lambdas
```vss
adder is task with n
    give task with x
        give x + n
    end
end

add5 is adder 5
say add5 3    # 8
```

#### Choices & Pattern Matching
```vss
choice Direction
    North
    South
    East
    West
end

d is Direction.North

match d
    when North: say "Going north"
    when South: say "Going south"
    else:       say "Going somewhere"
end
```

#### Blueprints (Interfaces)
```vss
blueprint Drawable
    draw
end

shape Circle uses Drawable
    radius
    task draw
        say "Drawing circle r=" + self.radius
    end
end
```

#### Coroutines & Generators
```vss
task counter with start
    n is start
    repeat forever
        yield n
        n is n + 1
    end
end

gen is coroutine counter 1
say resume gen    # 1
say resume gen    # 2
say resume gen    # 3
```

#### Interactive User Input

VSS supports interactive user input via the `ask` statement. You can read lines from the terminal (stdin) and automatically assign them to mutable variables. The input will be converted to match the target variable's existing type.

##### Basic Syntax
```vss
make name becomes ""
ask name
say "Hello, " + name
```

##### Optional Prompt
```vss
make age becomes 0
ask "Enter your age: " into age
say "Next year you will be " + (age + 1)
```

##### Supported Types
VSS automatically converts input into the target variable's existing type:
* **String** (`VSS_VAL_STRING` / `"text"`): input is assigned as a string (with trailing newline removed).
* **Number** (`VSS_VAL_NUMBER` / `"number"`): input is parsed as a number. If input is empty or invalid, a VSS runtime error is raised.
* **Boolean** (`VSS_VAL_BOOL` / `"boolean"`): input is matched case-insensitively. `"yes"`, `"true"`, and `"1"` resolve to `yes` (true), while `"no"`, `"false"`, and `"0"` resolve to `no` (false). Other values raise a VSS runtime error.

---

## VS Code Extension

Install syntax highlighting, IntelliSense, and code snippets for `.vss` files:

**[VSS Language — VS Code Marketplace](https://marketplace.visualstudio.com/items?itemName=saisiddharth.vss-language)**

Or in VS Code: `Ctrl+P` → `ext install saisiddharth.vss-language`

---

## Releases

| Platform | Download |
|----------|----------|
| Windows (Installer) | [VSS-2.2.2-Setup.exe](https://github.com/siddharth-1118/vss-language/releases/download/v2.2.2/VSS-2.2.2-Setup.exe) |
| Windows (Zip) | [vss-windows-x64.zip](https://github.com/siddharth-1118/vss-language/releases/download/v2.2.2/vss-windows-x64.zip) |
| Linux x64 | [vss-linux-x64.tar.gz](https://github.com/siddharth-1118/vss-language/releases/download/v2.2.2/vss-linux-x64.tar.gz) |
| macOS (Apple Silicon) | [vss-macos-arm64.tar.gz](https://github.com/siddharth-1118/vss-language/releases/download/v2.2.2/vss-macos-arm64.tar.gz) |
| macOS (Intel) | [vss-macos-x64.tar.gz](https://github.com/siddharth-1118/vss-language/releases/download/v2.2.2/vss-macos-x64.tar.gz) |

View all releases: [github.com/siddharth-1118/vss-language/releases](https://github.com/siddharth-1118/vss-language/releases)

---

## License

MIT License — Copyright (c) 2024-2026 Siddharth (siddharth-1118)

See [LICENSE](LICENSE) for full text.
