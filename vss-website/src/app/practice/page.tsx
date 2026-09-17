import React from "react";
import Link from "next/link";
import { Terminal, Code, CheckCircle2, Sparkles } from "lucide-react";
import { CodeBlock } from "@/components/ui/CodeBlock";
import { JsonLd } from "@/components/seo/JsonLd";

export const metadata = {
  title: "VSS Practice Problems — Algorithmic & Coding Exercises",
  description: "Practice VSS coding problems categorized by difficulty: Easy, Medium, Hard. Includes problem statements, constraints, hints, and VSS solutions.",
};

const PRACTICE_PROBLEMS = [
  {
    id: "p1",
    title: "1. Reverse a String",
    difficulty: "Easy",
    category: "Strings",
    statement: "Write a VSS task `reverse_string(str)` that returns the reversed string.",
    input: `"VSS"`,
    output: `"SSV"`,
    solution: `task reverse_string needs input_str
  make result becomes ""
  make len becomes input_str.length
  repeat i through len - 1 to 0 step -1
    result becomes result + input_str[i]
  finish
  send result
finish`
  },
  {
    id: "p2",
    title: "2. Find Maximum in Array",
    difficulty: "Easy",
    category: "Arrays",
    statement: "Write a VSS task `find_max(items)` that returns the maximum value in a list of numbers.",
    input: `[45, 12, 89, 33]`,
    output: `89`,
    solution: `task find_max needs items
  make max_val becomes items[0]
  repeat item in items
    when item > max_val
      max_val becomes item
    finish
  finish
  send max_val
finish`
  }
];

export default function PracticePage() {
  return (
    <div className="container mx-auto px-4 py-12 max-w-5xl space-y-12 font-sans">
      <JsonLd />

      <div className="space-y-4 text-center max-w-3xl mx-auto">
        <div className="inline-flex items-center gap-2 px-3.5 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
          <Terminal className="w-3.5 h-3.5" /> Practice Problem Library
        </div>
        <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight text-slate-100">
          VSS Practice & Coding Exercises
        </h1>
        <p className="text-slate-400 text-lg leading-relaxed">
          Test your VSS skills with algorithm challenges and practice problems.
        </p>
      </div>

      <div className="space-y-8">
        {PRACTICE_PROBLEMS.map((prob) => (
          <div key={prob.id} className="bg-slate-900/80 border border-slate-800 rounded-3xl p-8 space-y-4 shadow-xl">
            <div className="flex justify-between items-center">
              <h2 className="text-2xl font-bold text-slate-100">{prob.title}</h2>
              <span className="px-3 py-1 text-xs font-mono font-bold rounded-full bg-cyan-500/20 text-cyan-400 border border-cyan-500/30">
                {prob.difficulty}
              </span>
            </div>

            <p className="text-slate-300 text-sm">{prob.statement}</p>

            <div className="bg-slate-950 p-4 rounded-xl border border-slate-800 font-mono text-xs text-cyan-300">
              <div>Sample Input: {prob.input}</div>
              <div>Expected Output: {prob.output}</div>
            </div>

            <details className="group pt-2">
              <summary className="cursor-pointer text-xs font-bold text-cyan-400 hover:underline select-none">
                View VSS Solution Code
              </summary>
              <div className="mt-3">
                <CodeBlock filename="solution.vss" code={prob.solution} />
              </div>
            </details>
          </div>
        ))}
      </div>
    </div>
  );
}
