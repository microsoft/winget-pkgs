export interface SearchItem {
  id: string;
  title: string;
  category: 'Docs' | 'Standard Library' | 'Examples' | 'Projects' | 'Compiler' | 'Version' | 'General' | 'Learn';
  url: string;
  description: string;
  keywords: string[];
}

export interface VersionInfo {
  version: string;
  name: string;
  status: 'Latest' | 'Stable' | 'Legacy';
  releaseDate: string;
  highlights: string[];
  docUrl: string;
}

export interface CreatorProfile {
  name: string;
  handle: string;
  role: string;
  bio: string;
  githubUrl: string;
  linkedinUrl: string;
  vscodeExtUrl: string;
  wingetPackage: string;
  milestones: { year: string; event: string }[];
}

export const VSS_CREATOR: CreatorProfile = {
  name: "Vooka Sai Siddharth",
  handle: "siddharth-1118",
  role: "Creator, Inventor & Lead Compiler Architect of VSS",
  bio: "Vooka Sai Siddharth created the VSS (Very Simple Syntax) Programming Language to provide a readable, beginner-friendly yet highly powerful general-purpose programming language compiled in pure C with Automatic Reference Counting (ARC) and zero-cost multithreaded concurrency.",
  githubUrl: "https://github.com/siddharth-1118",
  linkedinUrl: "https://www.linkedin.com/in/vooka-sai-siddharth",
  vscodeExtUrl: "https://marketplace.visualstudio.com/items?itemName=saisiddharth.vss-language",
  wingetPackage: "VSS.VSS",
  milestones: [
    { year: "2024", event: "Designed the initial VSS language spec & baseline C interpreter." },
    { year: "2025", event: "Released VSS 2.2.2 with WinGet package (VSS.VSS) and official VS Code extension." },
    { year: "2026 (Q1)", event: "Engineered VSS 3.0.0 — complete general-purpose language expansion (35 standard modules, SQLite ORM, HTTP server/client, Webview GUI)." },
    { year: "2026 (Q3)", event: "Engineered VSS 3.1.0 — native OS worker-thread concurrency system (tasks, await, channels, mutexes, parallel each, lock-free atomics)." }
  ]
};

export const VSS_VERSIONS: VersionInfo[] = [
  {
    version: "v3.1",
    name: "VSS 3.1.0 (Concurrency & Parallel Engine)",
    status: "Latest",
    releaseDate: "September 2026",
    docUrl: "/docs/v3-1",
    highlights: [
      "OS Worker Thread Pool & `start task(...)` / `await` execution",
      "Parallel Iteration: `parallel each item in list`",
      "Message Passing Channels: `channel_create`, `channel_send`, `channel_recv`",
      "Block-scoped Mutexes: `lock mtx ... finish`",
      "Lock-free Atomic Primitives: `atomic_create`, `atomic_add`, `atomic_get`",
      "Concurrent Collections: `collections.ConcurrentMap()`, `collections.ConcurrentQueue()`"
    ]
  },
  {
    version: "v3.0",
    name: "VSS 3.0.0 (General-Purpose Language)",
    status: "Stable",
    releaseDate: "March 2026",
    docUrl: "/docs/v3",
    highlights: [
      "Complete General-Purpose capability parity with C, Python, Go, Java, Rust",
      "Interactive Stdin (`ask <var>`) with dynamic type casting",
      "Exception Trapping (`attempt ... rescue ... finish`)",
      "Native SQLite 3 Integration & ORM QueryBuilder",
      "HTTP Client & Builtin Web Server (`web.route`, `web.serve`)",
      "Native Desktop WebView GUI (`gui.create_window`)"
    ]
  },
  {
    version: "v2.2.2",
    name: "VSS 2.2.2 (Ecosystem Release)",
    status: "Legacy",
    releaseDate: "2025",
    docUrl: "/docs/v2-2-2",
    highlights: [
      "Official VS Code Syntax & IntelliSense extension",
      "WinGet Package distribution (`winget install VSS.VSS`)",
      "Basic OOP Shapes, Blueprints & Pattern Matching (`choose`)",
      "Standard Library expansion (math, string, file, json)"
    ]
  },
  {
    version: "v2.0",
    name: "VSS 2.0",
    status: "Legacy",
    releaseDate: "2025",
    docUrl: "/docs/v2",
    highlights: [
      "Stack-based Bytecode Virtual Machine compiled in pure C",
      "Automatic Reference Counting (ARC) memory manager",
      "Lexical Closures and Lambda functions"
    ]
  },
  {
    version: "v1.0",
    name: "VSS 1.0 (Initial Spec)",
    status: "Legacy",
    releaseDate: "2024",
    docUrl: "/docs/v1",
    highlights: [
      "Original VSS English-like syntax spec",
      "Tree-walk interpreter prototype",
      "Basic primitives (`say`, `make`, `when`, `repeat`)"
    ]
  }
];

export const SEARCH_INDEX: SearchItem[] = [
  {
    id: "learn-vss-academy",
    title: "Learn VSS Programming Language — Zero to Hero Academy",
    category: "Learn",
    url: "/learn",
    description: "Complete structured learning roadmap from absolute zero programming knowledge to building real software in VSS.",
    keywords: ["learn", "academy", "course", "tutorial", "zero", "roadmap", "how to program"]
  },
  {
    id: "learn-beginner-variables",
    title: "Lesson: How to Create Variables (`make` & `keep`)",
    category: "Learn",
    url: "/learn/beginner/04-variables-and-constants",
    description: "Step-by-step beginner lesson explaining what variables are and how to create them in VSS.",
    keywords: ["how to create a variable", "variables", "make", "keep", "becomes", "store data", "beginner"]
  },
  {
    id: "learn-from-scratch",
    title: "I've Never Programmed Before — Absolute Beginner Path",
    category: "Learn",
    url: "/learn/from-scratch",
    description: "Explains code, compilers, variables, loops, and functions in ultra-simple English before introducing VSS.",
    keywords: ["never programmed before", "what is code", "what is variable", "beginner", "from zero"]
  },
  {
    id: "vss-cheatsheet",
    title: "VSS Syntax Cheat Sheet",
    category: "Learn",
    url: "/cheatsheet",
    description: "Concise 30-minute syntax cheat sheet for experienced developers transitioning to VSS.",
    keywords: ["cheatsheet", "cheat sheet", "syntax", "quickstart", "fast", "30 minutes"]
  },
  {
    id: "getting-started",
    title: "Getting Started with VSS",
    category: "Docs",
    url: "/getting-started",
    description: "Learn how to write, compile, and run your first VSS program.",
    keywords: ["getting started", "tutorial", "hello world", "installation", "quickstart"]
  },
  {
    id: "install-guide",
    title: "VSS Installation Guide",
    category: "Docs",
    url: "/install",
    description: "Install VSS on Windows (WinGet / PowerShell), Linux, and macOS.",
    keywords: ["install", "winget", "windows", "linux", "macos", "download", "path"]
  },
  {
    id: "vss-3-1-concurrency",
    title: "VSS 3.1 Concurrency & Parallel System",
    category: "Docs",
    url: "/docs/v3-1",
    description: "Master background tasks, worker thread pools, channels, mutexes, atomics, and parallel each loops in VSS 3.1.",
    keywords: ["concurrency", "tasks", "start task", "await", "channel", "mutex", "lock", "atomic", "parallel each", "worker thread"]
  },
  {
    id: "creator-vooka-sai-siddharth",
    title: "Creator of VSS — Vooka Sai Siddharth",
    category: "General",
    url: "/creator",
    description: "Official bio, history, and development vision of VSS creator Vooka Sai Siddharth.",
    keywords: ["creator", "inventor", "author", "vooka", "sai", "siddharth", "who created vss", "who invented vss"]
  }
];
