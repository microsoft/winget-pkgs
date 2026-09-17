import React from "react";
import Link from "next/link";
import { ArrowRight, BookOpen, Terminal, CheckCircle2, Play, Code2, Sparkles } from "lucide-react";
import { CodeBlock } from "@/components/ui/CodeBlock";
import { JsonLd } from "@/components/seo/JsonLd";

export const metadata = {
  title: "Getting Started with VSS 3.1 — Beginner Guide & Tutorial",
  description: "Learn how to write, compile, and execute your first VSS programming language application in 5 minutes.",
};

export default function GettingStartedPage() {
  return (
    <div className="container mx-auto px-4 py-12 max-w-5xl space-y-12">
      <JsonLd />

      {/* Header */}
      <div className="space-y-4">
        <div className="inline-flex items-center gap-2 px-3 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
          <BookOpen className="w-3.5 h-3.5" /> Quickstart Guide
        </div>
        <h1 className="text-4xl font-extrabold tracking-tight text-slate-100">
          Getting Started with VSS 3.1
        </h1>
        <p className="text-slate-400 text-lg leading-relaxed">
          Welcome to VSS (Very Simple Syntax)! This guide will take you from zero to running your first VSS program, working with variables, control flow, modules, and native OS worker-thread concurrency.
        </p>
      </div>

      {/* Step 1: Install VSS */}
      <div className="bg-slate-900/60 border border-slate-800 rounded-2xl p-6 md:p-8 space-y-4">
        <div className="flex items-center gap-3 text-cyan-400 font-bold text-xl">
          <div className="w-8 h-8 rounded-full bg-cyan-500/10 border border-cyan-500/30 flex items-center justify-center text-sm font-mono">1</div>
          Step 1: Install VSS CLI
        </div>
        <p className="text-slate-300 text-sm">
          On Windows, install VSS using Microsoft WinGet via PowerShell:
        </p>
        <div className="bg-slate-950 p-4 rounded-xl border border-slate-800 font-mono text-cyan-400 text-sm flex justify-between items-center">
          <span>winget install VSS.VSS</span>
        </div>
        <p className="text-xs text-slate-400">
          For Linux, macOS, or building from C source, see the full <Link href="/install" className="text-cyan-400 hover:underline">Installation Guide</Link>.
        </p>
      </div>

      {/* Step 2: Hello World */}
      <div className="bg-slate-900/60 border border-slate-800 rounded-2xl p-6 md:p-8 space-y-4">
        <div className="flex items-center gap-3 text-cyan-400 font-bold text-xl">
          <div className="w-8 h-8 rounded-full bg-cyan-500/10 border border-cyan-500/30 flex items-center justify-center text-sm font-mono">2</div>
          Step 2: Write "Hello, World!"
        </div>
        <p className="text-slate-300 text-sm">
          Create a file named <code className="text-cyan-300 font-mono">hello.vss</code> using your favorite code editor:
        </p>
        <CodeBlock
          filename="hello.vss"
          code={`say "Hello, VSS 3.1 World!"`}
          output={`Hello, VSS 3.1 World!`}
        />
        <p className="text-slate-300 text-sm">
          Run your VSS program from the terminal:
        </p>
        <div className="bg-slate-950 p-4 rounded-xl border border-slate-800 font-mono text-cyan-400 text-sm">
          vss hello.vss
        </div>
      </div>
    </div>
  );
}
