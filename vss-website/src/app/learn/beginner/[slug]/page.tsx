import React from "react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { BookOpen, CheckCircle2, ArrowRight, ArrowLeft, HelpCircle, Code2, AlertTriangle, Sparkles, Terminal } from "lucide-react";
import { SAMPLE_BEGINNER_LESSONS, COURSE_MODULES } from "@/lib/vss-courses";
import { CodeBlock } from "@/components/ui/CodeBlock";
import { ProgressTracker } from "@/components/learn/ProgressTracker";
import { QuizComponent } from "@/components/learn/QuizComponent";
import { JsonLd } from "@/components/seo/JsonLd";

export async function generateStaticParams() {
  return Object.keys(SAMPLE_BEGINNER_LESSONS).map((slug) => ({ slug }));
}

export default async function BeginnerLessonPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const lesson = SAMPLE_BEGINNER_LESSONS[slug];

  if (!lesson) {
    // Render fallback lesson layout if slug isn't pre-rendered
    return (
      <div className="container mx-auto px-4 py-12 max-w-4xl text-center space-y-6 font-sans">
        <h1 className="text-3xl font-bold text-slate-100">Lesson Coming Soon</h1>
        <p className="text-slate-400">This lesson is part of the VSS Academy curriculum and is currently being updated for VSS 3.1.0.</p>
        <Link href="/learn/beginner" className="inline-flex items-center text-cyan-400 font-bold text-sm hover:underline">
          <ArrowLeft className="w-4 h-4 mr-1" /> Back to Beginner Course
        </Link>
      </div>
    );
  }

  const beginnerLessons = COURSE_MODULES[0].lessons;
  const currentIndex = beginnerLessons.findIndex((l) => l.slug === lesson.slug);
  const prevLesson = currentIndex > 0 ? beginnerLessons[currentIndex - 1] : null;
  const nextLesson = currentIndex < beginnerLessons.length - 1 ? beginnerLessons[currentIndex + 1] : null;

  return (
    <div className="container mx-auto px-4 py-12 max-w-6xl font-sans space-y-12">
      <JsonLd />

      {/* Top Header & Breadcrumb */}
      <div className="space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-4 border-b border-slate-800 pb-4">
          <div className="flex items-center gap-2 text-xs font-mono text-cyan-400 font-bold">
            <Link href="/learn" className="hover:underline">VSS Academy</Link>
            <span>/</span>
            <Link href="/learn/beginner" className="hover:underline">Beginner Course</Link>
            <span>/</span>
            <span className="text-slate-300">Lesson {currentIndex + 1} of {beginnerLessons.length}</span>
          </div>

          <ProgressTracker lessonSlug={lesson.slug} />
        </div>

        <h1 className="text-3xl md:text-4xl font-extrabold text-slate-100 tracking-tight">
          {lesson.title}
        </h1>
        <p className="text-slate-400 text-base md:text-lg leading-relaxed max-w-3xl">
          {lesson.summary}
        </p>
      </div>

      {/* Layout Grid: Content + Sidebar */}
      <div className="grid grid-cols-1 lg:grid-cols-4 gap-8">
        {/* Main Lesson Body */}
        <div className="lg:col-span-3 space-y-12">
          {/* Section 1: Concept Explanation */}
          <section className="bg-slate-900/60 border border-slate-800 rounded-2xl p-6 md:p-8 space-y-4 shadow-lg">
            <h2 className="text-2xl font-bold text-slate-100 flex items-center gap-2">
              <BookOpen className="w-6 h-6 text-cyan-400" /> 1. Concept Explanation
            </h2>
            <p className="text-slate-300 text-sm leading-relaxed whitespace-pre-line">
              {lesson.conceptExplanation}
            </p>
          </section>

          {/* Section 2: Why This Concept Matters */}
          <section className="bg-slate-900/60 border border-slate-800 rounded-2xl p-6 md:p-8 space-y-4 shadow-lg">
            <h2 className="text-2xl font-bold text-slate-100 flex items-center gap-2">
              <Sparkles className="w-6 h-6 text-emerald-400" /> 2. Why This Concept Matters
            </h2>
            <p className="text-slate-300 text-sm leading-relaxed">
              {lesson.whyItMatters}
            </p>
          </section>

          {/* Section 3: VSS Syntax & Code Example */}
          <section className="space-y-4">
            <h2 className="text-2xl font-bold text-slate-100 flex items-center gap-2">
              <Code2 className="w-6 h-6 text-cyan-400" /> 3. VSS Syntax & Interactive Code Example
            </h2>
            <p className="text-slate-300 text-sm">
              Notice how clean VSS syntax reads like plain English:
            </p>
            <CodeBlock
              filename={`${lesson.slug}.vss`}
              code={lesson.codeExample}
              output={lesson.codeOutput}
            />
          </section>

          {/* Section 4: Line-by-Line Breakdown */}
          <section className="bg-slate-900/60 border border-slate-800 rounded-2xl p-6 md:p-8 space-y-4 shadow-lg">
            <h2 className="text-2xl font-bold text-slate-100 flex items-center gap-2">
              <Terminal className="w-6 h-6 text-indigo-400" /> 4. Line-by-Line Code Breakdown
            </h2>
            <div className="space-y-3 font-mono text-xs">
              {lesson.lineByLineExplanation.map((item, idx) => (
                <div key={idx} className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                  <span className="text-cyan-300 font-bold shrink-0">{item.line}</span>
                  <span className="text-slate-400 font-sans text-xs">{item.explanation}</span>
                </div>
              ))}
            </div>
          </section>

          {/* Section 5: Common Mistakes */}
          <section className="bg-slate-900/60 border border-slate-800 rounded-2xl p-6 md:p-8 space-y-4 shadow-lg">
            <h2 className="text-2xl font-bold text-slate-100 flex items-center gap-2 text-rose-400">
              <AlertTriangle className="w-6 h-6 text-rose-400" /> 5. Common Beginner Mistakes
            </h2>
            <div className="space-y-4">
              {lesson.commonMistakes.map((m, idx) => (
                <div key={idx} className="bg-slate-950 border border-slate-850 p-4 rounded-xl space-y-2 text-xs">
                  <div className="flex flex-col sm:flex-row gap-4 font-mono">
                    <div className="text-rose-400">❌ Incorrect: <code className="bg-rose-500/10 px-2 py-0.5 rounded">{m.wrong}</code></div>
                    <div className="text-emerald-400">✓ Correct: <code className="bg-emerald-500/10 px-2 py-0.5 rounded">{m.correct}</code></div>
                  </div>
                  <p className="text-slate-400 font-sans">{m.explanation}</p>
                </div>
              ))}
            </div>
          </section>

          {/* Section 6: Quiz Check */}
          {lesson.quiz && (
            <QuizComponent
              question={lesson.quiz.question}
              options={lesson.quiz.options}
              correctIndex={lesson.quiz.correctIndex}
              explanation={lesson.quiz.explanation}
            />
          )}

          {/* Section 7: Challenge with Solution */}
          <section className="bg-gradient-to-r from-slate-900 via-slate-900 to-indigo-950/40 border border-indigo-500/30 rounded-2xl p-6 md:p-8 space-y-4 shadow-xl">
            <h2 className="text-2xl font-bold text-slate-100 flex items-center gap-2">
              <Sparkles className="w-6 h-6 text-indigo-400" /> 6. Interactive Challenge: {lesson.challenge.title}
            </h2>
            <p className="text-slate-300 text-sm leading-relaxed">
              {lesson.challenge.description}
            </p>

            <details className="group pt-2">
              <summary className="cursor-pointer text-xs font-bold text-cyan-400 hover:underline inline-flex items-center gap-1 select-none">
                <span>View Solution Code</span>
              </summary>
              <div className="mt-3">
                <CodeBlock filename="challenge_solution.vss" code={lesson.challenge.solution} />
              </div>
            </details>
          </section>

          {/* Navigation Bar: Prev & Next Lesson */}
          <div className="flex flex-col sm:flex-row justify-between items-center gap-4 pt-6 border-t border-slate-800">
            {prevLesson ? (
              <Link
                href={`/learn/beginner/${prevLesson.slug}`}
                className="w-full sm:w-auto px-5 py-3 rounded-xl bg-slate-900 hover:bg-slate-800 border border-slate-800 text-slate-200 text-xs font-bold transition flex items-center justify-center gap-2"
              >
                <ArrowLeft className="w-4 h-4" />
                <span>Previous: {prevLesson.title}</span>
              </Link>
            ) : <div />}

            {nextLesson ? (
              <Link
                href={`/learn/beginner/${nextLesson.slug}`}
                className="w-full sm:w-auto px-6 py-3 rounded-xl bg-cyan-500 hover:bg-cyan-400 text-slate-950 text-xs font-bold transition shadow-lg shadow-cyan-500/20 flex items-center justify-center gap-2"
              >
                <span>Next: {nextLesson.title}</span>
                <ArrowRight className="w-4 h-4" />
              </Link>
            ) : (
              <Link
                href="/learn/intermediate"
                className="w-full sm:w-auto px-6 py-3 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 text-xs font-bold transition shadow-lg flex items-center justify-center gap-2"
              >
                <span>Proceed to Intermediate Course</span>
                <ArrowRight className="w-4 h-4" />
              </Link>
            )}
          </div>
        </div>

        {/* Course Sidebar Navigation */}
        <div className="space-y-6">
          <div className="bg-slate-900/80 border border-slate-800 rounded-2xl p-5 space-y-4 sticky top-24 shadow-xl">
            <h3 className="text-sm font-bold text-slate-100 font-mono uppercase tracking-wider">
              Beginner Course Outline
            </h3>
            <div className="space-y-1.5 text-xs">
              {beginnerLessons.map((l, i) => {
                const isActive = l.slug === lesson.slug;
                return (
                  <Link
                    key={l.slug}
                    href={`/learn/beginner/${l.slug}`}
                    className={`block px-3 py-2 rounded-xl transition line-clamp-1 ${
                      isActive
                        ? "bg-cyan-500/10 text-cyan-300 font-bold border border-cyan-500/30"
                        : "text-slate-400 hover:text-slate-200 hover:bg-slate-950"
                    }`}
                  >
                    {l.title}
                  </Link>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
