import React from 'react';
import Link from 'next/link';
import { ArrowRight, BookOpen, CheckCircle, Code, Cpu, Download, ExternalLink, FastForward, Layers, Lock, ShieldCheck, Sparkles, Terminal, User, Zap } from 'lucide-react';
import { GithubIcon } from '@/components/icons/GithubIcon';
import { CodeBlock } from '@/components/ui/CodeBlock';
import { VSS_CREATOR, VSS_VERSIONS } from '@/lib/vss-data';

export default function HomePage() {
  const latestVersion = VSS_VERSIONS[0];

  const quickStartCode = `note Hello World in VSS (Very Simple Syntax)
include "collections"

say "=== VSS 3.1 Concurrency System ==="

make tasks_count becomes 5
make counter becomes atomic_create(0)

# Run OS worker thread parallel iteration
parallel i in [1, 2, 3, 4, 5]
  atomic_add(counter, 1)
  say "Thread worker processed item #" + i
finish

say "Completed execution on " + atomic_get(counter) + " workers!"`;

  return (
    <div className="space-y-24 pb-20">
      {/* Hero Section */}
      <section className="relative pt-12 md:pt-20 pb-16 overflow-hidden">
        <div className="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[300px] bg-gradient-to-tr from-cyan-500/20 via-sky-500/10 to-indigo-500/20 blur-3xl pointer-events-none rounded-full" />

        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
          <div className="text-center space-y-6 max-w-4xl mx-auto">
            {/* Version Badge */}
            <div className="inline-flex items-center space-x-2 px-3.5 py-1 rounded-full bg-cyan-500/10 border border-cyan-500/20 text-cyan-400 text-xs font-mono">
              <Sparkles className="w-3.5 h-3.5" />
              <span>VSS 3.1.0 Released — Native OS Worker-Thread Concurrency</span>
              <ArrowRight className="w-3 h-3" />
            </div>

            {/* Main Headline */}
            <h1 className="text-4xl sm:text-6xl lg:text-7xl font-extrabold tracking-tight text-slate-100 leading-tight">
              The Power of C with the{' '}
              <span className="bg-gradient-to-r from-cyan-400 via-sky-300 to-indigo-400 bg-clip-text text-transparent">
                Simplicity of English
              </span>
            </h1>

            {/* Subtitle */}
            <p className="text-slate-400 text-base sm:text-lg max-w-2xl mx-auto leading-relaxed">
              VSS (Very Simple Syntax) is a high-performance general-purpose programming language invented by{' '}
              <strong className="text-cyan-400 font-semibold">{VSS_CREATOR.name}</strong>. Built in pure C with ARC memory management and native multi-threading.
            </p>

            {/* Call to Actions - Requirement #24 */}
            <div className="flex flex-col sm:flex-row items-center justify-center gap-4 pt-4">
              <Link
                href="/learn"
                className="w-full sm:w-auto px-7 py-3.5 rounded-xl bg-gradient-to-r from-cyan-500 to-sky-400 hover:from-cyan-400 hover:to-sky-300 text-slate-950 font-bold text-sm transition shadow-lg shadow-cyan-500/25 flex items-center justify-center space-x-2"
              >
                <Sparkles className="w-4 h-4" />
                <span>Start Learning VSS</span>
                <ArrowRight className="w-4 h-4" />
              </Link>

              <Link
                href="/cheatsheet"
                className="w-full sm:w-auto px-6 py-3.5 rounded-xl bg-slate-900 hover:bg-slate-800 border border-slate-800 hover:border-slate-700 text-slate-200 font-semibold text-sm transition flex items-center justify-center space-x-2 font-mono"
              >
                <Zap className="w-4 h-4 text-cyan-400" />
                <span>I Already Know Programming</span>
              </Link>

              <a
                href={VSS_CREATOR.githubUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="px-6 py-3.5 rounded-xl bg-slate-900 hover:bg-slate-800 border border-slate-800 hover:border-slate-700 text-slate-200 font-semibold text-sm flex items-center space-x-2 transition"
              >
                <GithubIcon className="w-4 h-4 text-slate-300" />
                <span>GitHub Repository</span>
                <ExternalLink className="w-3 h-3 text-slate-500" />
              </a>
            </div>
          </div>

          {/* Interactive Code Preview */}
          <div className="mt-14 max-w-4xl mx-auto">
            <CodeBlock
              filename="concurrency_demo.vss"
              code={quickStartCode}
              output={`=== VSS 3.1 Concurrency System ===
Thread worker processed item #1
Thread worker processed item #2
Thread worker processed item #3
Thread worker processed item #4
Thread worker processed item #5
Completed execution on 5 workers!`}
            />
          </div>
        </div>
      </section>

      {/* Requirement #36: Learn VSS from Zero Major Homepage Section */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="bg-gradient-to-r from-cyan-950/40 via-slate-900 to-indigo-950/40 border border-cyan-500/30 rounded-3xl p-8 sm:p-12 shadow-2xl relative overflow-hidden">
          <div className="flex flex-col md:flex-row items-center justify-between gap-8 relative z-10">
            <div className="space-y-4 max-w-2xl">
              <div className="inline-flex items-center gap-2 px-3 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
                <BookOpen className="w-3.5 h-3.5" /> VSS ACADEMY
              </div>
              <h2 className="text-3xl sm:text-4xl font-extrabold text-slate-100 tracking-tight">
                Learn VSS from Zero
              </h2>
              <p className="text-slate-300 text-base leading-relaxed">
                Never programmed before? We take you step-by-step from absolute zero knowledge to building complete concurrent applications. No complex jargon, zero assumptions.
              </p>
            </div>

            <div className="flex flex-col sm:flex-row gap-3 w-full md:w-auto shrink-0">
              <Link
                href="/learn/from-scratch"
                className="px-6 py-3.5 rounded-xl bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold text-sm transition shadow-lg shadow-cyan-500/20 flex items-center justify-center space-x-2"
              >
                <span>Start from Zero</span>
                <ArrowRight className="w-4 h-4" />
              </Link>
              <Link
                href="/cheatsheet"
                className="px-6 py-3.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 font-semibold text-sm transition flex items-center justify-center space-x-2"
              >
                <span>Experienced Developer</span>
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* Feature Grid */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center space-y-3 mb-16">
          <h2 className="text-3xl font-extrabold text-slate-100">Why Developers Choose VSS</h2>
          <p className="text-slate-400 text-sm max-w-xl mx-auto">
            Clean English keywords combined with C compilation performance.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 space-y-3">
            <div className="w-10 h-10 rounded-xl bg-cyan-500/10 text-cyan-400 flex items-center justify-center border border-cyan-500/20">
              <Zap className="w-5 h-5" />
            </div>
            <h3 className="text-lg font-bold text-slate-100">OS Worker Threads</h3>
            <p className="text-slate-400 text-sm leading-relaxed">
              VSS 3.1 dispatches tasks directly across physical CPU cores via <code className="text-cyan-300 font-mono">start task</code>, thread-safe channels, mutexes, and atomics.
            </p>
          </div>

          <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 space-y-3">
            <div className="w-10 h-10 rounded-xl bg-emerald-500/10 text-emerald-400 flex items-center justify-center border border-emerald-500/20">
              <ShieldCheck className="w-5 h-5" />
            </div>
            <h3 className="text-lg font-bold text-slate-100">ARC Memory Management</h3>
            <p className="text-slate-400 text-sm leading-relaxed">
              Automatic Reference Counting (ARC) reclaims memory instantly upon scope exit without stop-the-world Garbage Collection pauses.
            </p>
          </div>

          <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 space-y-3">
            <div className="w-10 h-10 rounded-xl bg-indigo-500/10 text-indigo-400 flex items-center justify-center border border-indigo-500/20">
              <Cpu className="w-5 h-5" />
            </div>
            <h3 className="text-lg font-bold text-slate-100">Pure C Stack VM</h3>
            <p className="text-slate-400 text-sm leading-relaxed">
              The entire compiler, bytecode emitter, and VM are written in pure C, guaranteeing tiny binary size and instant execution speed.
            </p>
          </div>
        </div>
      </section>
    </div>
  );
}
