import React from "react";
import Link from "next/link";
import { Zap, Cpu, Layers } from "lucide-react";
import { CodeBlock } from "@/components/ui/CodeBlock";
import { JsonLd } from "@/components/seo/JsonLd";
import { VSS_CREATOR } from "@/lib/vss-data";

export const metadata = {
  title: "VSS 3.1 Concurrency Course — OS Worker Threads & Parallel Engine",
  description: "Complete course on VSS 3.1 native OS worker-thread concurrency: tasks, await, parallel loops, worker pools, channels, mutexes, and atomics.",
};

export default function ConcurrencyCoursePage() {
  return (
    <div className="container mx-auto px-4 py-12 max-w-5xl space-y-12 font-sans">
      <JsonLd />

      <div className="space-y-4 text-center max-w-3xl mx-auto">
        <div className="inline-flex items-center gap-2 px-3.5 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
          <Zap className="w-3.5 h-3.5" /> VSS 3.1 Concurrency System
        </div>
        <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight text-slate-100">
          VSS 3.1 Concurrency & Parallel Programming
        </h1>
        <p className="text-slate-400 text-lg leading-relaxed">
          Designed by <strong className="text-cyan-400">{VSS_CREATOR.name}</strong>, VSS 3.1 introduces real native OS worker-thread parallelism into the VSS C stack-VM runtime.
        </p>
      </div>

      <div className="space-y-8">
        {/* Worker Threads & Await */}
        <div className="bg-slate-900/80 border border-slate-800 rounded-3xl p-8 space-y-4 shadow-xl">
          <h2 className="text-2xl font-bold text-slate-100">1. Spawning Tasks on OS Worker Threads</h2>
          <CodeBlock
            filename="async_task.vss"
            code={`task compute_payload needs id
  make result becomes id * 100
  send result
finish

make handle becomes start compute_payload(42)
make output becomes await handle
say "Task Result: " + output`}
            output={`Task Result: 4200`}
          />
        </div>

        {/* Parallel Loop Iterations */}
        <div className="bg-slate-900/80 border border-slate-800 rounded-3xl p-8 space-y-4 shadow-xl">
          <h2 className="text-2xl font-bold text-slate-100">2. Parallel Iterations (`parallel`)</h2>
          <CodeBlock
            filename="parallel_loop.vss"
            code={`include "collections"

make counter becomes atomic_create(0)

parallel item in [1, 2, 3, 4, 5]
  atomic_add(counter, 1)
  say "Thread worker processed item: " + item
finish

say "Total Processed Items: " + atomic_get(counter)`}
            output={`Thread worker processed item: 1
Thread worker processed item: 2
Thread worker processed item: 3
Thread worker processed item: 4
Thread worker processed item: 5
Total Processed Items: 5`}
          />
        </div>
      </div>
    </div>
  );
}
