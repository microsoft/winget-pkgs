import React from "react";
import Link from "next/link";
import { BookOpen, Sparkles, ArrowRight, CheckCircle2, HelpCircle } from "lucide-react";
import { JsonLd } from "@/components/seo/JsonLd";

export const metadata = {
  title: "I've Never Programmed Before — Absolute Beginner Concepts",
  description: "Learn what programming is, what code does, how variables store values, and how computers execute commands before writing your first VSS code.",
};

const CONCEPTS = [
  {
    title: "1. What is Code?",
    desc: "Code is a written set of instructions humans give to computers to perform tasks like calculating math, showing graphics, or building software."
  },
  {
    title: "2. What is a Programming Language?",
    desc: "Computers only understand 0s and 1s (binary). A programming language like VSS lets humans write instructions in simple English words, which the VSS compiler converts into fast machine code."
  },
  {
    title: "3. What is a Variable?",
    desc: "A variable is like a labeled storage box in computer memory. You give it a name (e.g. `age`) and store a value inside it (e.g. `20`). In VSS, you create one using `make age becomes 20`."
  },
  {
    title: "4. What is a Condition?",
    desc: "A condition lets a computer make decisions. For example: 'IF user is 18 or older, allow access; OTHERWISE deny access.' In VSS, this is written using `when age >= 18 ... otherwise ... finish`."
  },
  {
    title: "5. What is a Loop?",
    desc: "A loop repeats an action multiple times automatically without you having to retype the code. In VSS, you write `repeat i through 1 to 5 ... finish`."
  }
];

export default function FromScratchPage() {
  return (
    <div className="container mx-auto px-4 py-12 max-w-4xl space-y-12 font-sans">
      <JsonLd />

      <div className="space-y-4 text-center">
        <div className="inline-flex items-center gap-2 px-3.5 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
          <BookOpen className="w-3.5 h-3.5" /> Absolute Zero Entry Path
        </div>
        <h1 className="text-4xl font-extrabold tracking-tight text-slate-100">
          I&apos;ve Never Programmed Before
        </h1>
        <p className="text-slate-400 text-lg leading-relaxed">
          Welcome! Before writing any VSS code, let&apos;s understand basic programming concepts in ultra-simple English.
        </p>
      </div>

      <div className="space-y-6">
        {CONCEPTS.map((c, idx) => (
          <div key={idx} className="bg-slate-900/70 border border-slate-800 rounded-2xl p-6 md:p-8 space-y-2 shadow-lg">
            <h2 className="text-xl font-bold text-slate-100">{c.title}</h2>
            <p className="text-slate-300 text-sm leading-relaxed">{c.desc}</p>
          </div>
        ))}
      </div>

      <div className="bg-gradient-to-r from-cyan-950/40 via-slate-900 to-indigo-950/40 border border-cyan-500/30 rounded-2xl p-8 text-center space-y-4">
        <h2 className="text-2xl font-bold text-slate-100">Ready to Write Your First Line of VSS Code?</h2>
        <p className="text-slate-400 text-sm">Now that you understand the concepts, let&apos;s start Lesson 1!</p>
        <Link
          href="/learn/beginner/01-what-is-vss"
          className="inline-flex items-center justify-center px-6 py-3 rounded-xl bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold text-sm transition shadow-lg shadow-cyan-500/20"
        >
          Start Lesson 1: What is VSS? <ArrowRight className="w-4 h-4 ml-2" />
        </Link>
      </div>
    </div>
  );
}
