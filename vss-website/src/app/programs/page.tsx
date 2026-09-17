import React from "react";
import Link from "next/link";
import { Terminal, Code, BookOpen } from "lucide-react";
import { VSS_PROGRAMS } from "@/lib/vss-dsa-programs";
import { CodeBlock } from "@/components/ui/CodeBlock";
import { JsonLd } from "@/components/seo/JsonLd";

export const metadata = {
  title: "VSS Programs Library — Tutorial Examples & Code Snippets",
  description: "Browse VSS code tutorials and program snippets: numbers, strings, arrays, searching, sorting, files, JSON, SQLite databases, and HTTP web servers.",
};

export default function ProgramsLibraryPage() {
  return (
    <div className="container mx-auto px-4 py-12 max-w-5xl space-y-12 font-sans">
      <JsonLd />

      <div className="space-y-4 text-center max-w-3xl mx-auto">
        <div className="inline-flex items-center gap-2 px-3.5 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
          <Terminal className="w-3.5 h-3.5" /> Program Library
        </div>
        <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight text-slate-100">
          VSS Programs & Problem Library
        </h1>
        <p className="text-slate-400 text-lg leading-relaxed">
          Runnable VSS code snippets complete with problem statement, approach, code, line-by-line breakdown, and output.
        </p>
      </div>

      <div className="space-y-8">
        {VSS_PROGRAMS.map((p) => (
          <div key={p.id} className="bg-slate-900/80 border border-slate-800 rounded-3xl p-8 space-y-4 shadow-xl">
            <div className="flex justify-between items-center">
              <h2 className="text-xl font-bold text-slate-100">{p.title}</h2>
              <span className="px-2.5 py-1 text-xs font-mono font-bold rounded-full bg-cyan-500/20 text-cyan-400 border border-cyan-500/30">
                {p.category}
              </span>
            </div>
            <p className="text-slate-300 text-sm">{p.problem}</p>
            <CodeBlock filename="program.vss" code={p.vssCode} output={p.vssOutput} />
          </div>
        ))}
      </div>
    </div>
  );
}
