export interface Lesson {
  id: string;
  slug: string;
  title: string;
  module: string;
  level: 'Beginner' | 'Intermediate' | 'Advanced' | 'Professional';
  version: string;
  estimatedTime: string;
  summary: string;
  conceptExplanation: string;
  whyItMatters: string;
  vssSyntax: string;
  codeExample: string;
  codeOutput: string;
  lineByLineExplanation: { line: string; explanation: string }[];
  anotherExample?: { code: string; output: string; desc: string };
  commonMistakes: { wrong: string; correct: string; explanation: string }[];
  practiceQuestion: { question: string; hint: string };
  challenge: { title: string; description: string; hint: string; solution: string };
  miniExercise: { prompt: string; expectedOutput: string; hint: string; solution: string };
  quiz?: {
    question: string;
    options: string[];
    correctIndex: number;
    explanation: string;
  };
  summaryPoints: string[];
  prevSlug?: string;
  nextSlug?: string;
}

export interface CourseModule {
  id: string;
  title: string;
  level: 'Beginner' | 'Intermediate' | 'Advanced' | 'Professional';
  description: string;
  icon: string;
  lessons: { slug: string; title: string; isImplemented: boolean }[];
}

export const COURSE_MODULES: CourseModule[] = [
  {
    id: "beginner-module",
    title: "VSS Beginner — Language & Syntax Fundamentals",
    level: "Beginner",
    description: "Learn programming from absolute zero. Understand code, variables, input/output, conditions, loops, and basic problem solving in VSS.",
    icon: "BookOpen",
    lessons: [
      { slug: "01-what-is-vss", title: "1. What is VSS & Why Was It Created?", isImplemented: true },
      { slug: "02-installation", title: "2. Installing VSS & Setting Up VS Code", isImplemented: true },
      { slug: "03-first-program", title: "3. Your First Program & The `say` Statement", isImplemented: true },
      { slug: "04-variables-and-constants", title: "4. Variables (`make`) and Constants (`keep`)", isImplemented: true },
      { slug: "05-data-types", title: "5. Numbers, Strings, and Booleans", isImplemented: true },
      { slug: "06-operators", title: "6. Arithmetic & Comparison Operators", isImplemented: true },
      { slug: "07-user-input", title: "7. Interactive User Input with `ask`", isImplemented: true },
      { slug: "08-conditionals", title: "8. Conditions (`when`, `orwhen`, `otherwise`)", isImplemented: true },
      { slug: "09-pattern-matching", title: "9. Pattern Matching (`choose` / `case`)", isImplemented: true },
      { slug: "10-loops-range", title: "10. Counting Loops (`repeat i through A to B`)", isImplemented: true },
      { slug: "11-loops-conditional", title: "11. Conditional Loops (`during`) & Loop Control (`leave`/`skip`)", isImplemented: true },
      { slug: "12-beginner-practice", title: "12. Beginner Problem Solving & Mini Projects", isImplemented: true },
    ]
  },
  {
    id: "intermediate-module",
    title: "VSS Intermediate — Data Structures & Functions",
    level: "Intermediate",
    description: "Master first-class tasks, closures, lists, maps, sets, structs, enums, error trapping, and standard modules.",
    icon: "Code",
    lessons: [
      { slug: "13-tasks-functions", title: "13. Tasks (`task`), Arguments (`needs`), and Return (`send`)", isImplemented: true },
      { slug: "14-recursion-closures", title: "14. Recursion & Lexical Closures", isImplemented: true },
      { slug: "15-lists-collections", title: "15. Lists & Collection Iteration (`repeat item in list`)", isImplemented: true },
      { slug: "16-maps-dictionaries", title: "16. Key-Value Maps & Lookup Operations", isImplemented: true },
      { slug: "17-sets-unique", title: "17. Unique Sets & Collection Math", isImplemented: true },
      { slug: "18-string-manipulation", title: "18. String Operations & Formatting", isImplemented: true },
      { slug: "19-structs-records", title: "19. Custom Data Structs & Fields", isImplemented: true },
      { slug: "20-enums", title: "20. Enums & Type Disambiguation", isImplemented: true },
      { slug: "21-modules-include", title: "21. Modules & Code Reusability (`include`)", isImplemented: true },
      { slug: "22-error-handling", title: "22. Exception Trapping (`attempt` / `rescue`)", isImplemented: true },
      { slug: "23-intermediate-projects", title: "23. Intermediate Mini Projects & CLI Utilities", isImplemented: true },
    ]
  },
  {
    id: "advanced-module",
    title: "VSS Advanced — OOP, Databases, Web & Concurrency",
    level: "Advanced",
    description: "Deep dive into OOP shapes, filesystem I/O, SQLite database integration, HTTP web servers, and VSS 3.1 OS worker thread concurrency.",
    icon: "Cpu",
    lessons: [
      { slug: "24-oop-shapes", title: "24. Object-Oriented Programming (`shape`, `extends`, `implements`)", isImplemented: true },
      { slug: "25-filesystem-io", title: "25. Filesystem Operations (`filesystem.read_file`, `write_file`)", isImplemented: true },
      { slug: "26-json-parsing", title: "26. JSON Serialization & Parsing (`json.parse`, `stringify`)", isImplemented: true },
      { slug: "27-sqlite-databases", title: "27. Native SQLite 3 Database Queries & ORM", isImplemented: true },
      { slug: "28-http-client", title: "28. HTTP Client API Requests (`http.get`, `http.post`)", isImplemented: true },
      { slug: "29-web-server", title: "29. Multi-threaded HTTP Web Server (`web.route`, `web.serve`)", isImplemented: true },
      { slug: "30-rest-apis", title: "30. Building Production REST APIs with JSON & SQLite", isImplemented: true },
      { slug: "31-vss-31-concurrency", title: "31. VSS 3.1 Worker Threads (`start task`, `await`, `parallel`)", isImplemented: true },
      { slug: "32-channels-mutexes", title: "32. Thread Channels (`channel_create`) & Mutex Locks (`lock mtx`)", isImplemented: true },
      { slug: "33-atomics", title: "33. Lock-free Atomic Counters (`atomic_create`, `atomic_add`)", isImplemented: true },
    ]
  },
  {
    id: "professional-module",
    title: "VSS Professional — Full Application Architecture",
    level: "Professional",
    description: "Build production software applications, CLI tools, concurrent worker pipelines, and understand VSS compiler architecture.",
    icon: "Layers",
    lessons: [
      { slug: "34-build-cli-app", title: "34. Building CLI Command Line Applications", isImplemented: true },
      { slug: "35-build-web-app", title: "35. Building Web Applications with Native Webview GUI", isImplemented: true },
      { slug: "36-build-backend-api", title: "36. Building Production Microservices & Auth APIs", isImplemented: true },
      { slug: "37-compiler-vm-internals", title: "37. VSS Compiler Architecture, Bytecode & ARC VM", isImplemented: true },
      { slug: "38-ecosystem-publishing", title: "38. WinGet Package Publishing & VS Code Extension Tools", isImplemented: true },
    ]
  }
];

export const SAMPLE_BEGINNER_LESSONS: Record<string, Lesson> = {
  "01-what-is-vss": {
    id: "01-what-is-vss",
    slug: "01-what-is-vss",
    title: "1. What is VSS & Why Was It Created?",
    module: "VSS Beginner",
    level: "Beginner",
    version: "VSS 3.1",
    estimatedTime: "5 mins",
    summary: "Learn what VSS (Very Simple Syntax) is, why it was created by Vooka Sai Siddharth, and how it delivers C speed with English readability.",
    conceptExplanation: "Programming languages allow humans to instruct computers to perform calculations, automate tasks, and build software. Most traditional languages use obscure symbols like `{`, `}`, `void`, `fn`, `std::cout`, or `system.out.println`. VSS (Very Simple Syntax) was designed by Vooka Sai Siddharth to replace cryptic symbols with plain English verbs like `say`, `make`, `when`, `repeat`, and `task`.",
    whyItMatters: "Understanding the philosophy behind VSS gives you confidence that every keyword in VSS is designed to read like a natural sentence, while under the hood it compiles to pure ISO C with Automatic Reference Counting (ARC) memory management and native OS thread performance.",
    vssSyntax: "say \"Hello, World!\"",
    codeExample: `say "Welcome to VSS Programming Language!"
say "Created by Vooka Sai Siddharth"`,
    codeOutput: `Welcome to VSS Programming Language!
Created by Vooka Sai Siddharth`,
    lineByLineExplanation: [
      { line: 'say "Welcome..."', explanation: 'The `say` keyword prints the text enclosed in quotes directly to the terminal screen.' },
      { line: 'say "Created..."', explanation: 'Prints the second line of text immediately after the first.' }
    ],
    commonMistakes: [
      { wrong: 'print "Hello"', correct: 'say "Hello"', explanation: 'In VSS, output is performed using the verb `say`, not `print` or `printf`.' },
      { wrong: 'say Hello', correct: 'say "Hello"', explanation: 'Text strings must always be enclosed in double quotes.' }
    ],
    practiceQuestion: {
      question: "Which keyword is used in VSS to display text on the terminal screen?",
      hint: "Think of the English verb used to speak text out loud."
    },
    challenge: {
      title: "Print Your Name",
      description: "Write a VSS program that displays your name and your favorite programming goal.",
      hint: "Use two separate `say` statements.",
      solution: `say "My name is Vooka Sai Siddharth"
say "My goal is to master VSS 3.1 concurrency!"`
    },
    miniExercise: {
      prompt: "Write a statement that prints 'VSS is fast and simple'",
      expectedOutput: "VSS is fast and simple",
      hint: "Use `say \"...\"`",
      solution: `say "VSS is fast and simple"`
    },
    quiz: {
      question: "What language is the VSS compiler and Virtual Machine runtime written in?",
      options: ["Pure ISO C", "Python", "Java", "JavaScript"],
      correctIndex: 0,
      explanation: "The entire VSS compiler, stack-based bytecode virtual machine, and ARC runtime are written in pure ISO C for maximum speed and tiny memory footprint."
    },
    summaryPoints: [
      "VSS stands for Very Simple Syntax.",
      "Invented and engineered by Vooka Sai Siddharth.",
      "Uses plain English keywords like `say`, `make`, `when`, `task`.",
      "Compiled in pure C with ARC memory management."
    ],
    nextSlug: "02-installation"
  },
  "02-installation": {
    id: "02-installation",
    slug: "02-installation",
    title: "2. Installing VSS & Setting Up VS Code",
    module: "VSS Beginner",
    level: "Beginner",
    version: "VSS 3.1",
    estimatedTime: "5 mins",
    summary: "Learn how to install VSS on Windows using WinGet or compile from source, and install the official VS Code extension.",
    conceptExplanation: "To write and execute VSS code on your computer, you need the VSS Command Line Interface (CLI) tool named `vss` or `vss.exe`. On Windows, VSS is published to the official Microsoft WinGet repository as `VSS.VSS`.",
    whyItMatters: "Having the VSS CLI installed allows you to type `vss filename.vss` in your terminal to run any VSS program instantly.",
    vssSyntax: "# Windows PowerShell installation\nwinget install VSS.VSS",
    codeExample: `# Run VSS version check in terminal
vss --version`,
    codeOutput: `VSS Programming Language v3.1.0 (Concurrency & Worker-Thread Engine)`,
    lineByLineExplanation: [
      { line: 'winget install VSS.VSS', explanation: 'Downloads and installs the latest VSS compiler package from Microsoft WinGet repository.' },
      { line: 'vss --version', explanation: 'Verifies that the `vss` binary is correctly registered in your system PATH.' }
    ],
    commonMistakes: [
      { wrong: 'winget install vss', correct: 'winget install VSS.VSS', explanation: 'The official Microsoft WinGet package identifier is `VSS.VSS`.' }
    ],
    practiceQuestion: {
      question: "What command do you type in your terminal to run a file named app.vss?",
      hint: "The CLI executable name followed by the filename."
    },
    challenge: {
      title: "Verify CLI Installation",
      description: "Verify that VSS is installed on your machine and display version info.",
      hint: "Pass `--version` to the vss command.",
      solution: `vss --version`
    },
    miniExercise: {
      prompt: "What is the file extension for VSS source files?",
      expectedOutput: ".vss",
      hint: "Three letters starting with v.",
      solution: `.vss`
    },
    summaryPoints: [
      "VSS installs on Windows via `winget install VSS.VSS`.",
      "VSS source files end with the `.vss` file extension.",
      "Execute code via `vss program.vss`."
    ],
    prevSlug: "01-what-is-vss",
    nextSlug: "03-first-program"
  },
  "03-first-program": {
    id: "03-first-program",
    slug: "03-first-program",
    title: "3. Your First Program & The `say` Statement",
    module: "VSS Beginner",
    level: "Beginner",
    version: "VSS 3.1",
    estimatedTime: "7 mins",
    summary: "Write your first VSS program, understand statements, comments, strings, and the `say` output command.",
    conceptExplanation: "A computer program is a sequence of statements. In VSS, every output statement starts with the keyword `say`. You can print strings of text, numbers, calculations, or variables.",
    whyItMatters: "Output is how a computer program communicates results back to the user.",
    vssSyntax: "say \"Hello, World!\"",
    codeExample: `# This is a single-line comment in VSS
say "Hello World from VSS 3.1!"
say 42
say 10 + 20`,
    codeOutput: `Hello World from VSS 3.1!
42
30`,
    lineByLineExplanation: [
      { line: '# This is a comment', explanation: 'Lines starting with `#` are comments ignored by the compiler.' },
      { line: 'say "Hello..."', explanation: 'Prints the text string to console.' },
      { line: 'say 42', explanation: 'Prints the number 42.' },
      { line: 'say 10 + 20', explanation: 'Evaluates the expression 10 + 20 to 30 and prints 30.' }
    ],
    commonMistakes: [
      { wrong: 'SAY "Hello"', correct: 'say "Hello"', explanation: 'VSS keywords are lowercase. Use `say`, not `SAY`.' }
    ],
    practiceQuestion: {
      question: "How do you add a comment in VSS that the compiler ignores?",
      hint: "Use the hashtag or hash symbol `#`."
    },
    challenge: {
      title: "Three-line Profile Output",
      description: "Write a program that prints your name, your age, and your favorite language in 3 lines.",
      hint: "Use 3 separate `say` statements.",
      solution: `say "Name: Sai Siddharth"
say "Age: 22"
say "Language: VSS 3.1"`
    },
    miniExercise: {
      prompt: "Print the sum of 50 and 50 using `say`",
      expectedOutput: "100",
      hint: "Write `say 50 + 50`",
      solution: `say 50 + 50`
    },
    summaryPoints: [
      "Use `say` to print output.",
      "Comments start with `#`.",
      "Expressions like `10 + 20` evaluate automatically inside `say`."
    ],
    prevSlug: "02-installation",
    nextSlug: "04-variables-and-constants"
  },
  "04-variables-and-constants": {
    id: "04-variables-and-constants",
    slug: "04-variables-and-constants",
    title: "4. Variables (`make`) and Constants (`keep`)",
    module: "VSS Beginner",
    level: "Beginner",
    version: "VSS 3.1",
    estimatedTime: "10 mins",
    summary: "Learn how to store data in memory using mutable variables (`make`) and immutable constants (`keep`).",
    conceptExplanation: "A variable is a named storage container in computer memory. In VSS, when you want to create a variable that can change later, you use `make x becomes value`. When you want to create a constant value that can NEVER change, you use `keep y becomes value`.",
    whyItMatters: "Variables allow programs to store user input, track scores, compute values dynamically, and update application state.",
    vssSyntax: "make score becomes 100\nkeep MAX_SCORE becomes 500\nscore becomes score + 50",
    codeExample: `make score becomes 100
keep MAX_SCORE becomes 500

say "Initial Score: " + score

# Reassign variable
score becomes score + 50
say "Updated Score: " + score
say "Max Allowed: " + MAX_SCORE`,
    codeOutput: `Initial Score: 100
Updated Score: 150
Max Allowed: 500`,
    lineByLineExplanation: [
      { line: 'make score becomes 100', explanation: 'Creates a mutable variable named `score` and assigns initial integer value 100.' },
      { line: 'keep MAX_SCORE becomes 500', explanation: 'Creates an immutable constant named `MAX_SCORE` with value 500. Attempting to reassign it throws a compiler error.' },
      { line: 'score becomes score + 50', explanation: 'Updates `score` by adding 50 to its current value.' }
    ],
    commonMistakes: [
      { wrong: 'let score = 100', correct: 'make score becomes 100', explanation: 'VSS uses `make ... becomes`, not `let` or `=` for variable declaration.' },
      { wrong: 'const PI = 3.14', correct: 'keep PI becomes 3.14', explanation: 'VSS uses `keep` for constants, not `const`.' }
    ],
    practiceQuestion: {
      question: "Which keyword creates a mutable variable in VSS?",
      hint: "The English word meaning 'to create or produce'."
    },
    challenge: {
      title: "Bank Balance Tracker",
      description: "Create a variable `balance` with 500. Deposit 200, withdraw 50, and display the final balance.",
      hint: "Use `make balance becomes 500`, then reassign with `becomes`.",
      solution: `make balance becomes 500
balance becomes balance + 200
balance becomes balance - 50
say "Final Balance: $" + balance`
    },
    miniExercise: {
      prompt: "Declare a constant named `TAX_RATE` with value 0.15",
      expectedOutput: "keep TAX_RATE becomes 0.15",
      hint: "Use `keep ... becomes ...`",
      solution: `keep TAX_RATE becomes 0.15`
    },
    summaryPoints: [
      "`make name becomes val` creates a mutable variable.",
      "`keep name becomes val` creates an immutable constant.",
      "Use `becomes` for assignment and reassignment."
    ],
    prevSlug: "03-first-program",
    nextSlug: "05-data-types"
  }
};
