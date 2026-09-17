import React from "react";
import Link from "next/link";
import { CheckCircle2, Cpu, Sparkles, Code2, ArrowRight, ShieldCheck, Zap, Layers } from "lucide-react";
import { CodeBlock } from "@/components/ui/CodeBlock";
import { JsonLd } from "@/components/seo/JsonLd";
import { VSS_CREATOR } from "@/lib/vss-data";

export const metadata = {
  title: "About VSS Programming Language — Vision, Architecture & Creator",
  description: "Learn about the VSS (Very Simple Syntax) programming language created by Vooka Sai Siddharth. C-compiled performance, ARC memory, and OS worker-thread concurrency.",
};

export default function AboutPage() {
  return (
    <div className="container mx-auto px-4 py-12 max-w-6xl space-y-16">
      <JsonLd />

      {/* Hero Section */}
      <div className="text-center space-y-4 mb-16">
        <div className="inline-flex items-center gap-2 px-3 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
          <Sparkles className="w-3.5 h-3.5" /> About VSS Language
        </div>
        <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight bg-gradient-to-r from-cyan-400 via-sky-300 to-indigo-400 bg-clip-text text-transparent">
          The Power of C with the Simplicity of English
        </h1>
        <p className="text-slate-400 text-lg max-w-3xl mx-auto leading-relaxed">
          VSS (Very Simple Syntax) is a high-performance general-purpose programming language invented by{" "}
          <strong className="text-cyan-400 font-semibold">{VSS_CREATOR.name}</strong>. It combines plain-English keywords, Automatic Reference Counting (ARC), a stack-based Bytecode Virtual Machine, and native OS worker-thread concurrency.
        </p>
      </div>

      {/* Creator Attribution Box */}
      <div className="bg-slate-900/80 border border-slate-800 rounded-2xl p-8 mb-16 shadow-xl relative overflow-hidden">
        <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-6 relative z-10">
          <div className="space-y-3">
            <div className="flex items-center gap-2 text-sm text-cyan-400 font-mono">
              <span>DESIGNER & LEAD ARCHITECT</span>
            </div>
            <h2 className="text-2xl font-bold text-slate-100">{VSS_CREATOR.name}</h2>
            <p className="text-slate-300 max-w-2xl text-sm leading-relaxed">
              {VSS_CREATOR.bio}
            </p>
          </div>
          <div className="flex flex-wrap gap-3 w-full md:w-auto shrink-0">
            <a
              href={VSS_CREATOR.githubUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center justify-center px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 text-sm font-semibold transition-colors"
            >
              GitHub Profile
            </a>
            <a
              href={VSS_CREATOR.linkedinUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center justify-center px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-cyan-300 border border-slate-700 text-sm font-semibold transition-colors"
            >
              LinkedIn Profile
            </a>
            <Link
              href="/creator"
              className="inline-flex items-center justify-center px-4 py-2.5 rounded-xl bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold text-sm transition-colors shadow-lg shadow-cyan-500/20"
            >
              Full Creator Profile <ArrowRight className="w-4 h-4 ml-2" />
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
