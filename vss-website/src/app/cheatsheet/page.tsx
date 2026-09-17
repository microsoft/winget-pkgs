import React from "react";
import Link from "next/link";
import { Code2, Terminal, Zap, BookOpen, Layers } from "lucide-react";
import { CodeBlock } from "@/components/ui/CodeBlock";
import { JsonLd } from "@/components/seo/JsonLd";

export const metadata = {
  title: "VSS Syntax Cheat Sheet (30 Minutes for Developers)",
  description: "Fast-track VSS 3.1 syntax cheat sheet for experienced software engineers transitioning from Python, C, Go, Java, or Rust.",
};

export default function CheatSheetPage() {
  return (
    <div className="container mx-auto px-4 py-12 max-w-5xl space-y-12 font-sans">
      <JsonLd />

      <div className="space-y-4 text-center max-w-3xl mx-auto">
        <div className="inline-flex items-center gap-2 px-3.5 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
          <Zap className="w-3.5 h-3.5" /> Experienced Developer Fast-Track
        </div>
        <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight text-slate-100">
          VSS 3.1 Syntax Cheat Sheet
        </h1>
        <p className="text-slate-400 text-lg leading-relaxed">
          Master VSS keywords, control flow, functions, OOP shapes, error trapping, and OS worker thread concurrency in 30 minutes.
        </p>
      </div>

      <div className="space-y-8">
        {/* Variables & Mutability */}
        <div className="bg-slate-900/70 border border-slate-800 rounded-2xl p-6 md:p-8 space-y-4 shadow-lg">
          <h2 className="text-xl font-bold text-slate-100">1. Variables & Mutability</h2>
          <CodeBlock
            filename="variables_cheatsheet.vss"
            code={`make x becomes 42        # Mutable variable
keep MAX_VAL becomes 100 # Immutable constant
x becomes x + 10`}
          />
        </div>

        {/* Conditionals & Matching */}
        <div className="bg-slate-900/70 border border-slate-800 rounded-2xl p-6 md:p-8 space-y-4 shadow-lg">
          <h2 className="text-xl font-bold text-slate-100">2. Conditionals & Pattern Matching</h2>
          <CodeBlock
            filename="conditionals_cheatsheet.vss"
            code={`when age >= 18
  say "Adult"
orwhen age >= 13
  say "Teen"
otherwise
  say "Child"
finish

choose status_code
  case 200
    say "OK"
  case 404
    say "Not Found"
  otherwise
    say "Unknown"
finish`}
          />
        </div>

        {/* Loops */}
        <div className="bg-slate-900/70 border border-slate-800 rounded-2xl p-6 md:p-8 space-y-4 shadow-lg">
          <h2 className="text-xl font-bold text-slate-100">3. Loops & Iterations</h2>
          <CodeBlock
            filename="loops_cheatsheet.vss"
            code={`# Range loop
repeat i through 1 to 5
  say "Count: " + i
finish

# List iteration
make items becomes ["A", "B", "C"]
repeat item in items
  say item
finish`}
          />
        </div>

        {/* Functions & OOP */}
        <div className="bg-slate-900/70 border border-slate-800 rounded-2xl p-6 md:p-8 space-y-4 shadow-lg">
          <h2 className="text-xl font-bold text-slate-100">4. Tasks & OOP Shapes</h2>
          <CodeBlock
            filename="tasks_oop_cheatsheet.vss"
            code={`task add needs a, b
  send a + b
finish

shape User
  make name
  task construct needs u_name
    mine.name becomes u_name
  finish
finish

make user becomes new User("Sai Siddharth")`}
          />
        </div>

        {/* VSS 3.1 Concurrency */}
        <div className="bg-slate-900/70 border border-slate-800 rounded-2xl p-6 md:p-8 space-y-4 shadow-lg">
          <h2 className="text-xl font-bold text-slate-100">5. VSS 3.1 Concurrency</h2>
          <CodeBlock
            filename="concurrency_cheatsheet.vss"
            code={`make handle becomes start task_name(args)
make result becomes await handle

parallel item in collection
  # Process concurrently across CPU cores
finish`}
          />
        </div>
      </div>
    </div>
  );
}
