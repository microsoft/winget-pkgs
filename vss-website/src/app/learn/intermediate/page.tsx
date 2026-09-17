import React from "react";
import Link from "next/link";
import { Code, CheckCircle2, ArrowRight } from "lucide-react";
import { COURSE_MODULES } from "@/lib/vss-courses";
import { JsonLd } from "@/components/seo/JsonLd";

export const metadata = {
  title: "VSS Intermediate Course — Data Structures & Functions",
  description: "Master VSS tasks, closures, recursion, lists, maps, sets, structs, enums, modules, and error trapping.",
};

export default function IntermediateCoursePage() {
  const intermediateModule = COURSE_MODULES[1];

  return (
    <div className="container mx-auto px-4 py-12 max-w-5xl space-y-12 font-sans">
      <JsonLd />

      <div className="space-y-4 text-center max-w-3xl mx-auto">
        <div className="inline-flex items-center gap-2 px-3.5 py-1 text-xs font-semibold rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
          <Code className="w-3.5 h-3.5" /> Level 2: Intermediate Course
        </div>
        <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight text-slate-100">
          VSS Intermediate Course
        </h1>
        <p className="text-slate-400 text-lg leading-relaxed">
          Master functions, closures, list/map data structures, modules, and error handling in VSS.
        </p>
      </div>

      <div className="space-y-4">
        <h2 className="text-2xl font-bold text-slate-100">Curriculum ({intermediateModule.lessons.length} Lessons)</h2>
        <div className="grid grid-cols-1 gap-4 font-sans">
          {intermediateModule.lessons.map((les, idx) => (
            <div
              key={les.slug}
              className="bg-slate-900/80 border border-slate-800 rounded-2xl p-6 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 shadow-lg"
            >
              <div className="space-y-1">
                <div className="flex items-center gap-2 text-xs font-mono text-emerald-400 font-bold">
                  <span>LESSON {idx + 13}</span>
                  <span className="text-slate-600">•</span>
                  <span className="text-slate-400 font-normal">VSS 3.0 Verified</span>
                </div>
                <h3 className="text-lg font-bold text-slate-100">
                  {les.title}
                </h3>
              </div>
              <span className="text-xs font-mono text-cyan-400">Verified Specification ✓</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
