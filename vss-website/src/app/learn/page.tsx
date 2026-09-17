import React from "react";
import Link from "next/link";
import { BookOpen, Code, Cpu, Layers, ArrowRight, Sparkles, CheckCircle2, Play, HelpCircle, Terminal } from "lucide-react";
import { COURSE_MODULES } from "@/lib/vss-courses";
import { CourseProgressBar } from "@/components/learn/ProgressTracker";
import { JsonLd } from "@/components/seo/JsonLd";
import { VSS_CREATOR } from "@/lib/vss-data";

export const metadata = {
  title: "Learn VSS Programming Language — Zero to Hero Academy",
  description: "Learn VSS Programming Language from absolute zero knowledge to building real software. Complete visual roadmap, beginner lessons, challenges, and guided project paths.",
};

export default function LearnMainPage() {
  return (
    <div className="container mx-auto px-4 py-12 max-w-6xl space-y-16">
      <JsonLd />

      {/* Main Header */}
      <div className="text-center space-y-4 max-w-4xl mx-auto">
        <div className="inline-flex items-center gap-2 px-3.5 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
          <Sparkles className="w-3.5 h-3.5" /> VSS Academy & Guided Learning Platform
        </div>
        <h1 className="text-4xl md:text-6xl font-extrabold tracking-tight text-slate-100">
          Learn VSS Programming Language
        </h1>
        <p className="text-slate-400 text-lg md:text-xl leading-relaxed">
          Learn VSS from your first line of code to building complete concurrent applications. Designed for absolute beginners and experienced engineers alike.
        </p>
      </div>

      {/* Entry Point Decision Buttons */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 max-w-4xl mx-auto">
        <div className="bg-gradient-to-br from-slate-900 via-slate-900 to-cyan-950/40 border-2 border-cyan-500/40 rounded-2xl p-8 space-y-4 shadow-2xl relative overflow-hidden flex flex-col justify-between">
          <div className="space-y-3">
            <span className="px-3 py-1 text-xs font-bold rounded-full bg-cyan-500/20 text-cyan-400 border border-cyan-500/30">
              ABSOLUTE BEGINNER PATH
            </span>
            <h2 className="text-2xl font-bold text-slate-100">I&apos;ve Never Programmed Before</h2>
            <p className="text-slate-300 text-sm leading-relaxed">
              No prior coding experience required. We explain what programming is, what code does, how memory works, and guide you step-by-step.
            </p>
          </div>
          <Link
            href="/learn/from-scratch"
            className="inline-flex items-center justify-center w-full px-5 py-3.5 rounded-xl bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold text-sm transition shadow-lg shadow-cyan-500/20"
          >
            Start from Zero <ArrowRight className="w-4 h-4 ml-2" />
          </Link>
        </div>

        <div className="bg-slate-900/80 border border-slate-800 rounded-2xl p-8 space-y-4 flex flex-col justify-between shadow-xl">
          <div className="space-y-3">
            <span className="px-3 py-1 text-xs font-bold rounded-full bg-indigo-500/20 text-indigo-400 border border-indigo-500/30">
              EXPERIENCED DEVELOPER PATH
            </span>
            <h2 className="text-2xl font-bold text-slate-100">I Already Know Programming</h2>
            <p className="text-slate-300 text-sm leading-relaxed">
              Coming from Python, C, Go, Java, or Rust? Learn VSS syntax, tasks, ARC memory engine, and VSS 3.1 worker-thread concurrency in 30 minutes.
            </p>
          </div>
          <Link
            href="/cheatsheet"
            className="inline-flex items-center justify-center w-full px-5 py-3.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 font-bold text-sm transition"
          >
            VSS Syntax Cheat Sheet (30 Mins) <ArrowRight className="w-4 h-4 ml-2" />
          </Link>
        </div>
      </div>

      {/* Progress Tracker Card */}
      <div className="max-w-4xl mx-auto">
        <CourseProgressBar total={38} label="VSS Academy Global Completion Progress" />
      </div>

      {/* Visual Learning Roadmap Graph */}
      <div className="bg-slate-900/60 border border-slate-800 rounded-3xl p-8 md:p-12 space-y-8 shadow-2xl">
        <div className="text-center space-y-2">
          <h2 className="text-3xl font-extrabold text-slate-100">Visual VSS Learning Roadmap</h2>
          <p className="text-slate-400 text-sm">Clear progression from zero knowledge to professional software architect</p>
        </div>

        {/* Roadmap Diagram Nodes */}
        <div className="space-y-6 max-w-3xl mx-auto">
          {COURSE_MODULES.map((mod, idx) => (
            <div key={mod.id} className="relative">
              {idx > 0 && (
                <div className="w-0.5 h-6 bg-gradient-to-b from-cyan-500 to-indigo-500 mx-auto -mt-6 mb-2" />
              )}

              <div className="bg-slate-950 border border-slate-800 rounded-2xl p-6 space-y-4 hover:border-cyan-500/40 transition">
                <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-2">
                  <div className="flex items-center gap-3">
                    <span className="w-8 h-8 rounded-full bg-cyan-500/10 border border-cyan-500/30 flex items-center justify-center font-mono text-cyan-400 text-sm font-bold">
                      {idx + 1}
                    </span>
                    <div>
                      <h3 className="text-xl font-bold text-slate-100">{mod.title}</h3>
                      <span className="text-xs text-slate-400 font-mono">{mod.lessons.length} Verified Lessons</span>
                    </div>
                  </div>
                  <span className="px-3 py-1 text-xs font-bold rounded-full bg-slate-800 text-cyan-300 border border-slate-700">
                    {mod.level}
                  </span>
                </div>

                <p className="text-slate-300 text-sm leading-relaxed">{mod.description}</p>

                {/* Lesson Links Grid */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs font-mono pt-2">
                  {mod.lessons.map((les) => (
                    <Link
                      key={les.slug}
                      href={mod.level === "Beginner" ? `/learn/beginner/${les.slug}` : `/learn`}
                      className="p-2.5 rounded-lg bg-slate-900/80 hover:bg-slate-800 text-slate-300 hover:text-cyan-300 border border-slate-800 flex justify-between items-center transition"
                    >
                      <span className="truncate">{les.title}</span>
                      {les.isImplemented ? (
                        <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400 shrink-0 ml-1" />
                      ) : (
                        <span className="text-[10px] text-amber-400 bg-amber-500/10 px-1.5 py-0.5 rounded border border-amber-500/20">Coming Soon</span>
                      )}
                    </Link>
                  ))}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
