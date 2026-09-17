import React from "react";
import Link from "next/link";
import { Zap, Cpu, Layers, CheckCircle2, ShieldCheck, ArrowRight } from "lucide-react";
import { CodeBlock } from "@/components/ui/CodeBlock";
import { JsonLd } from "@/components/seo/JsonLd";
import { VSS_CREATOR } from "@/lib/vss-data";

export const metadata = {
  title: "VSS 3.1 Concurrency & Parallel Engine Specification",
  description: "Detailed technical documentation for VSS 3.1 native OS worker-thread concurrency, background tasks, channels, mutexes, and atomics.",
};

export default function Vss31DocsPage() {
  return (
    <div className="container mx-auto px-4 py-12 max-w-5xl space-y-12">
      <JsonLd />

      {/* Header */}
      <div className="space-y-4">
        <div className="inline-flex items-center gap-2 px-3 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
          <Zap className="w-3.5 h-3.5" /> VSS 3.1.0 Specification
        </div>
        <h1 className="text-4xl font-extrabold tracking-tight text-slate-100">
          VSS 3.1 Concurrency & Parallel Programming Engine
        </h1>
        <p className="text-slate-400 text-lg leading-relaxed">
          Engineered by <strong className="text-cyan-400">{VSS_CREATOR.name}</strong>, VSS 3.1 introduces real native OS worker-thread concurrency into the VSS C stack-VM runtime without sacrificing simple English syntax.
        </p>
      </div>

      {/* Feature 1: Asynchronous Tasks & Await */}
      <div className="space-y-4">
        <h2 className="text-2xl font-bold text-slate-100">1. Spawning Worker Tasks (<code className="text-cyan-300 font-mono">start task</code> / <code className="text-cyan-300 font-mono">await</code>)</h2>
        <p className="text-slate-300 text-sm leading-relaxed">
          Use the <code className="text-cyan-300 font-mono">start</code> keyword before calling a task to run it asynchronously on an OS thread worker. The returned task handle can be awaited later.
        </p>
        <CodeBlock
          filename="async_task_demo.vss"
          code={`task fetch_data needs id
  say "Fetching payload for ID: " + id
  make result becomes id * 100
  send result
finish

say "Main thread launching async task..."
make handle becomes start fetch_data(42)

make output becomes await handle
say "Awaited task output: " + output`}
          output={`Main thread launching async task...
Fetching payload for ID: 42
Awaited task output: 4200`}
        />
      </div>
    </div>
  );
}
