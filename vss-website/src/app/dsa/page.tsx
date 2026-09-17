import React from "react";
import Link from "next/link";
import { Cpu, Terminal, BookOpen, Layers, Sparkles } from "lucide-react";
import { DSA_TOPICS } from "@/lib/vss-dsa-programs";
import { CodeBlock } from "@/components/ui/CodeBlock";
import { JsonLd } from "@/components/seo/JsonLd";

export const metadata = {
  title: "Data Structures & Algorithms in VSS (DSA Course)",
  description: "Learn arrays, strings, searching, sorting, recursion, stacks, queues, hash maps, and dynamic programming implemented in VSS.",
};

export default function DsaPage() {
  return (
    <div className="container mx-auto px-4 py-12 max-w-5xl space-y-12 font-sans">
      <JsonLd />

      <div className="space-y-4 text-center max-w-3xl mx-auto">
        <div className="inline-flex items-center gap-2 px-3.5 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
          <Cpu className="w-3.5 h-3.5" /> DSA in VSS
        </div>
        <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight text-slate-100">
          Data Structures & Algorithms in VSS
        </h1>
        <p className="text-slate-400 text-lg leading-relaxed">
          Master computer science fundamentals and algorithmic problem solving using VSS.
        </p>
      </div>

      <div className="space-y-8">
        {DSA_TOPICS.map((t) => (
          <div key={t.id} className="bg-slate-900/80 border border-slate-800 rounded-3xl p-8 space-y-4 shadow-xl">
            <div className="flex justify-between items-center">
              <h2 className="text-2xl font-bold text-slate-100">{t.title}</h2>
              <span className="px-3 py-1 text-xs font-mono font-bold rounded-full bg-cyan-500/20 text-cyan-400 border border-cyan-500/30">
                {t.difficulty}
              </span>
            </div>

            <p className="text-slate-300 text-sm leading-relaxed">{t.concept}</p>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 font-mono text-xs text-slate-300">
              <div className="p-4 rounded-xl bg-slate-950 border border-slate-800 space-y-1">
                <div className="text-cyan-400 font-bold">Time Complexity</div>
                <div>{t.timeComplexity}</div>
              </div>
              <div className="p-4 rounded-xl bg-slate-950 border border-slate-800 space-y-1">
                <div className="text-emerald-400 font-bold">Space Complexity</div>
                <div>{t.spaceComplexity}</div>
              </div>
            </div>

            <CodeBlock filename={`${t.slug}.vss`} code={t.vssCode} output={t.vssOutput} />
          </div>
        ))}
      </div>
    </div>
  );
}
