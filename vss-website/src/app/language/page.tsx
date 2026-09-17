import React from "react";
import Link from "next/link";
import { Code2, BookOpen, Layers, Zap } from "lucide-react";
import { CodeBlock } from "@/components/ui/CodeBlock";
import { JsonLd } from "@/components/seo/JsonLd";
import { VSS_CREATOR } from "@/lib/vss-data";

export const metadata = {
  title: "VSS Language Manual — Grammar, Keywords & Syntax Spec",
  description: "Formal language specification for VSS 3.1: keywords, types, control flow statements, functions, OOP shapes, exception trapping, and concurrency opcodes.",
};

export default function LanguageSpecPage() {
  return (
    <div className="container mx-auto px-4 py-12 max-w-6xl space-y-16 font-sans">
      <JsonLd />

      <div className="space-y-4 text-center max-w-3xl mx-auto">
        <div className="inline-flex items-center gap-2 px-3.5 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
          <Code2 className="w-3.5 h-3.5" /> Formal Specification
        </div>
        <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight text-slate-100">
          VSS 3.1 Language Grammar Specification
        </h1>
        <p className="text-slate-400 text-lg leading-relaxed">
          The technical grammar manual for VSS 3.1, engineered by <strong className="text-cyan-400">{VSS_CREATOR.name}</strong>.
        </p>
      </div>

      <div className="bg-slate-900/80 border border-slate-800 rounded-3xl p-8 space-y-6 shadow-xl">
        <h2 className="text-2xl font-bold text-slate-100">Syntax Grammar Summary</h2>
        <div className="bg-slate-950 p-6 rounded-2xl border border-slate-800 font-mono text-xs text-cyan-300 space-y-2">
          <div>declaration := &quot;make&quot; IDENTIFIER &quot;becomes&quot; expression | &quot;keep&quot; IDENTIFIER &quot;becomes&quot; expression</div>
          <div>output_stmt := &quot;say&quot; expression</div>
          <div>condition   := &quot;when&quot; expr block (&quot;orwhen&quot; expr block)* (&quot;otherwise&quot; block)? &quot;finish&quot;</div>
          <div>matching    := &quot;choose&quot; expr (&quot;case&quot; expr block)* (&quot;otherwise&quot; block)? &quot;finish&quot;</div>
          <div>range_loop  := &quot;repeat&quot; IDENTIFIER &quot;through&quot; expr &quot;to&quot; expr block &quot;finish&quot;</div>
          <div>task_decl   := &quot;task&quot; IDENTIFIER (&quot;needs&quot; params)? block &quot;finish&quot;</div>
          <div>concurrency := &quot;start&quot; task_call | &quot;await&quot; task_handle | &quot;parallel&quot; IDENTIFIER &quot;in&quot; expr block &quot;finish&quot;</div>
        </div>
      </div>
    </div>
  );
}
