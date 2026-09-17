import React from "react";
import Link from "next/link";
import { Cpu, CheckCircle2, Zap } from "lucide-react";
import { COURSE_MODULES } from "@/lib/vss-courses";
import { JsonLd } from "@/components/seo/JsonLd";

export const metadata = {
  title: "VSS Advanced Course — OOP, Databases, Web & Concurrency",
  description: "Deep technical guide on VSS OOP shapes, filesystem I/O, SQLite ORM, HTTP web servers, and VSS 3.1 worker-thread concurrency.",
};

export default function AdvancedCoursePage() {
  const advancedModule = COURSE_MODULES[2];

  return (
    <div className="container mx-auto px-4 py-12 max-w-5xl space-y-12 font-sans">
      <JsonLd />

      <div className="space-y-4 text-center max-w-3xl mx-auto">
        <div className="inline-flex items-center gap-2 px-3.5 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
          <Cpu className="w-3.5 h-3.5" /> Level 3: Advanced Course
        </div>
        <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight text-slate-100">
          VSS Advanced & Concurrency Engine
        </h1>
        <p className="text-slate-400 text-lg leading-relaxed">
          Master real multi-threading, background worker pools, channels, mutexes, SQLite databases, and REST APIs.
        </p>
      </div>

      <div className="space-y-4">
        <h2 className="text-2xl font-bold text-slate-100">Curriculum ({advancedModule.lessons.length} Lessons)</h2>
        <div className="grid grid-cols-1 gap-4 font-sans">
          {advancedModule.lessons.map((les, idx) => (
            <div
              key={les.slug}
              className="bg-slate-900/80 border border-slate-800 rounded-2xl p-6 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 shadow-lg"
            >
              <div className="space-y-1">
                <div className="flex items-center gap-2 text-xs font-mono text-cyan-400 font-bold">
                  <span>LESSON {idx + 24}</span>
                  <span className="text-slate-600">•</span>
                  <span className="text-slate-400 font-normal">VSS 3.1 Concurrency Spec</span>
                </div>
                <h3 className="text-lg font-bold text-slate-100">
                  {les.title}
                </h3>
              </div>
              <span className="text-xs font-mono text-cyan-400 font-bold">VSS 3.1 OS Workers ✓</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
