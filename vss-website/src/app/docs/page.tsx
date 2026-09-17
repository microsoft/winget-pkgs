import React from "react";
import Link from "next/link";
import { BookOpen, Zap, Layers, Code2, Terminal, ArrowRight, Cpu } from "lucide-react";
import { VSS_VERSIONS, VSS_CREATOR } from "@/lib/vss-data";
import { JsonLd } from "@/components/seo/JsonLd";

export const metadata = {
  title: "VSS Documentation Portal — Versions, Specs & Architecture",
  description: "Official documentation hub for VSS (Very Simple Syntax) language created by Vooka Sai Siddharth. Guides for VSS 3.1, VSS 3.0, Standard Library, and VM architecture.",
};

export default function DocsPortalPage() {
  return (
    <div className="container mx-auto px-4 py-12 max-w-6xl space-y-12">
      <JsonLd />

      {/* Header */}
      <div className="text-center space-y-4 max-w-3xl mx-auto">
        <div className="inline-flex items-center gap-2 px-3 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
          <BookOpen className="w-3.5 h-3.5" /> Documentation Hub
        </div>
        <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight text-slate-100">
          VSS Documentation & Guides
        </h1>
        <p className="text-slate-400 text-lg leading-relaxed">
          Comprehensive technical documentation, version release specs, standard library references, and compiler architecture guides for VSS, designed by{" "}
          <strong className="text-cyan-400">{VSS_CREATOR.name}</strong>.
        </p>
      </div>

      {/* Primary Version Specs */}
      <div className="space-y-6">
        <h2 className="text-2xl font-bold text-slate-100">Language Versions</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* VSS 3.1 Featured Card */}
          <div className="bg-gradient-to-br from-slate-900 via-slate-900 to-cyan-950/40 border-2 border-cyan-500/40 rounded-2xl p-8 space-y-6 relative overflow-hidden shadow-2xl">
            <div className="flex justify-between items-start">
              <div>
                <span className="px-3 py-1 text-xs font-bold rounded-full bg-cyan-500/20 text-cyan-400 border border-cyan-500/30">
                  LATEST RELEASE
                </span>
                <h3 className="text-2xl font-extrabold text-slate-100 mt-3">VSS 3.1.0 Specs</h3>
                <p className="text-xs text-slate-400 font-mono mt-1">Concurrency & Worker-Thread Engine</p>
              </div>
              <Zap className="w-8 h-8 text-cyan-400" />
            </div>

            <p className="text-slate-300 text-sm leading-relaxed">
              Native OS thread pool dispatching, <code className="text-cyan-300 font-mono">start task</code>, <code className="text-cyan-300 font-mono">await</code>, thread-safe channels, mutexes, atomics, and parallel iterations.
            </p>

            <Link
              href="/docs/v3-1"
              className="inline-flex items-center justify-center w-full px-4 py-3 rounded-xl bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold text-sm transition-colors shadow-lg shadow-cyan-500/20"
            >
              Read VSS 3.1 Concurrency Specs <ArrowRight className="w-4 h-4 ml-2" />
            </Link>
          </div>

          {/* VSS 3.0 Card */}
          <div className="bg-slate-900/80 border border-slate-800 rounded-2xl p-8 space-y-6 flex flex-col justify-between">
            <div className="space-y-4">
              <div className="flex justify-between items-start">
                <div>
                  <span className="px-3 py-1 text-xs font-bold rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                    STABLE RELEASE
                  </span>
                  <h3 className="text-2xl font-extrabold text-slate-100 mt-3">VSS 3.0.0 Specs</h3>
                  <p className="text-xs text-slate-400 font-mono mt-1">General-Purpose Language Core</p>
                </div>
                <Cpu className="w-8 h-8 text-emerald-400" />
              </div>

              <p className="text-slate-300 text-sm leading-relaxed">
                General-purpose capabilities: 35 standard modules, native SQLite, web server, REST API, GUI webview, and interactive input.
              </p>
            </div>

            <Link
              href="/docs/v3"
              className="inline-flex items-center justify-center w-full px-4 py-3 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 font-bold text-sm transition-colors"
            >
              Read VSS 3.0 General Specs <ArrowRight className="w-4 h-4 ml-2" />
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
