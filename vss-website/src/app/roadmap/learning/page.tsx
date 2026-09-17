import React from "react";
import Link from "next/link";
import { Sparkles, ArrowRight, CheckCircle2 } from "lucide-react";
import { JsonLd } from "@/components/seo/JsonLd";
import { VSS_CREATOR } from "@/lib/vss-data";

export const metadata = {
  title: "VSS Developer Learning Roadmap — Step-by-Step Trajectory",
  description: "Complete progression path from VSS Beginner to Software Architect.",
};

const STAGES = [
  { step: "1", title: "VSS Beginner", desc: "Language syntax, variables, conditions, loops, and basic problem solving." },
  { step: "2", title: "Programming Fundamentals", desc: "Data structures, lists, maps, structs, enums, and functions." },
  { step: "3", title: "Algorithms & DSA", desc: "Searching, sorting, recursion, and space-time complexity analysis in VSS." },
  { step: "4", title: "VSS Intermediate", desc: "Exception trapping, custom modules, JSON parsing, and filesystem operations." },
  { step: "5", title: "Application Development", desc: "CLI tools, desktop GUIs, and file utility scripts." },
  { step: "6", title: "Web & Database Programming", desc: "Multi-threaded HTTP web servers, JSON REST APIs, and SQLite database persistence." },
  { step: "7", title: "VSS 3.1 Concurrency", desc: "OS worker thread pools, async tasks, channels, mutexes, and atomics." },
  { step: "8", title: "Professional VSS Architect", desc: "Full application architecture, compiler internals, and ecosystem publishing." }
];

export default function DeveloperRoadmapPage() {
  return (
    <div className="container mx-auto px-4 py-12 max-w-5xl space-y-12 font-sans">
      <JsonLd />

      <div className="space-y-4 text-center max-w-3xl mx-auto">
        <div className="inline-flex items-center gap-2 px-3.5 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
          <Sparkles className="w-3.5 h-3.5" /> Learning Trajectory
        </div>
        <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight text-slate-100">
          VSS Developer Learning Roadmap
        </h1>
        <p className="text-slate-400 text-lg leading-relaxed">
          The step-by-step path designed by creator <strong className="text-cyan-400">{VSS_CREATOR.name}</strong> to master software development with VSS.
        </p>
      </div>

      <div className="space-y-6 max-w-3xl mx-auto">
        {STAGES.map((s) => (
          <div key={s.step} className="bg-slate-900/80 border border-slate-800 rounded-2xl p-6 flex items-start gap-4 shadow-lg">
            <span className="w-8 h-8 rounded-full bg-cyan-500/10 border border-cyan-500/30 flex items-center justify-center font-mono text-cyan-400 font-bold shrink-0">
              {s.step}
            </span>
            <div className="space-y-1">
              <h2 className="text-xl font-bold text-slate-100">{s.title}</h2>
              <p className="text-slate-300 text-sm">{s.desc}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
