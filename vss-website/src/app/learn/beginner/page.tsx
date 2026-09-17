import React from "react";
import Link from "next/link";
import { BookOpen, CheckCircle2, ArrowRight, Sparkles } from "lucide-react";
import { COURSE_MODULES } from "@/lib/vss-courses";
import { JsonLd } from "@/components/seo/JsonLd";

export const metadata = {
  title: "VSS Beginner Course — Programming Fundamentals from Absolute Zero",
  description: "Comprehensive step-by-step VSS beginner course for learners with zero prior coding experience.",
};

export default function BeginnerCoursePage() {
  const beginnerModule = COURSE_MODULES[0];

  return (
    <div className="container mx-auto px-4 py-12 max-w-5xl space-y-12">
      <JsonLd />

      <div className="space-y-4 text-center max-w-3xl mx-auto">
        <div className="inline-flex items-center gap-2 px-3.5 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
          <BookOpen className="w-3.5 h-3.5" /> Level 1: Absolute Beginner Course
        </div>
        <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight text-slate-100">
          VSS Beginner Course
        </h1>
        <p className="text-slate-400 text-lg leading-relaxed">
          Designed for learners who have never programmed before. Every lesson explains concepts, why they matter, line-by-line code breakdowns, common mistakes, and interactive exercises.
        </p>
      </div>

      <div className="space-y-4">
        <h2 className="text-2xl font-bold text-slate-100">Course Curriculum ({beginnerModule.lessons.length} Lessons)</h2>
        <div className="grid grid-cols-1 gap-4 font-sans">
          {beginnerModule.lessons.map((les, idx) => (
            <Link
              key={les.slug}
              href={`/learn/beginner/${les.slug}`}
              className="bg-slate-900/80 border border-slate-800 hover:border-cyan-500/50 rounded-2xl p-6 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 transition group shadow-lg"
            >
              <div className="space-y-1">
                <div className="flex items-center gap-2 text-xs font-mono text-cyan-400 font-bold">
                  <span>LESSON {idx + 1}</span>
                  <span className="text-slate-600">•</span>
                  <span className="text-slate-400 font-normal">Est. 7 mins</span>
                </div>
                <h3 className="text-lg font-bold text-slate-100 group-hover:text-cyan-400 transition">
                  {les.title}
                </h3>
              </div>
              <div className="flex items-center gap-2 text-xs font-bold text-cyan-400 group-hover:translate-x-1 transition-transform shrink-0">
                <span>Start Lesson</span>
                <ArrowRight className="w-4 h-4" />
              </div>
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
}
