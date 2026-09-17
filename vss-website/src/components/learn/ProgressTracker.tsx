"use client";

import React, { useState, useEffect } from "react";
import { CheckCircle2, Circle, Award, Sparkles } from "lucide-react";

interface ProgressTrackerProps {
  lessonSlug?: string;
  totalLessons?: number;
  completedLessonsCount?: number;
}

export function ProgressTracker({ lessonSlug }: ProgressTrackerProps) {
  const [completed, setCompleted] = useState<string[]>([]);

  useEffect(() => {
    try {
      const saved = localStorage.getItem("vss_completed_lessons");
      if (saved) {
        setCompleted(JSON.parse(saved));
      }
    } catch {
      // localStorage fallback
    }
  }, []);

  const toggleLesson = (slug: string) => {
    let updated: string[];
    if (completed.includes(slug)) {
      updated = completed.filter((s) => s !== slug);
    } else {
      updated = [...completed, slug];
    }
    setCompleted(updated);
    try {
      localStorage.setItem("vss_completed_lessons", JSON.stringify(updated));
    } catch {
      // localStorage fallback
    }
  };

  const isCompleted = lessonSlug ? completed.includes(lessonSlug) : false;

  return (
    <div className="space-y-4 font-sans">
      {lessonSlug && (
        <button
          onClick={() => toggleLesson(lessonSlug)}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition-all shadow-md ${
            isCompleted
              ? "bg-emerald-500/20 text-emerald-300 border border-emerald-500/40 hover:bg-emerald-500/30"
              : "bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700"
          }`}
        >
          {isCompleted ? (
            <>
              <CheckCircle2 className="w-4 h-4 text-emerald-400" />
              <span>Lesson Completed ✓</span>
            </>
          ) : (
            <>
              <Circle className="w-4 h-4 text-slate-400" />
              <span>Mark Lesson as Completed</span>
            </>
          )}
        </button>
      )}
    </div>
  );
}

export function CourseProgressBar({
  total = 38,
  completedCount = 0,
  label = "Overall Academy Progress",
}: {
  total?: number;
  completedCount?: number;
  label?: string;
}) {
  const [completed, setCompleted] = useState<number>(completedCount);

  useEffect(() => {
    try {
      const saved = localStorage.getItem("vss_completed_lessons");
      if (saved) {
        const parsed = JSON.parse(saved);
        setCompleted(parsed.length);
      }
    } catch {
      // fallback
    }
  }, []);

  const percentage = Math.min(100, Math.round((completed / total) * 100));

  // ASCII bar representation (e.g. ████░░░░░░)
  const blocksCount = 10;
  const filledBlocks = Math.round((percentage / 100) * blocksCount);
  const asciiBar = "█".repeat(filledBlocks) + "░".repeat(blocksCount - filledBlocks);

  return (
    <div className="bg-slate-900/80 border border-slate-800 rounded-2xl p-6 space-y-3 font-sans shadow-lg">
      <div className="flex justify-between items-center text-xs">
        <span className="font-mono text-cyan-400 font-bold uppercase tracking-wider">{label}</span>
        <span className="font-mono text-slate-300 font-semibold">{percentage}% ({completed}/{total} lessons)</span>
      </div>

      <div className="w-full bg-slate-950 h-3 rounded-full overflow-hidden border border-slate-800 p-0.5">
        <div
          className="bg-gradient-to-r from-cyan-500 via-sky-400 to-indigo-500 h-full rounded-full transition-all duration-500"
          style={{ width: `${percentage}%` }}
        />
      </div>

      <div className="flex justify-between items-center text-[11px] text-slate-400 font-mono">
        <span>Progression: <code className="text-cyan-300 font-bold">{asciiBar}</code></span>
        {percentage === 100 && (
          <span className="text-emerald-400 font-bold flex items-center gap-1">
            <Award className="w-3.5 h-3.5" /> VSS Master Achieved!
          </span>
        )}
      </div>
    </div>
  );
}
