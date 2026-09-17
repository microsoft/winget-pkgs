"use client";

import React, { useState } from "react";
import { CheckCircle2, XCircle, HelpCircle, Sparkles } from "lucide-react";

interface QuizProps {
  question: string;
  options: string[];
  correctIndex: number;
  explanation: string;
}

export function QuizComponent({
  question,
  options,
  correctIndex,
  explanation,
}: QuizProps) {
  const [selectedIndex, setSelectedIndex] = useState<number | null>(null);
  const [submitted, setSubmitted] = useState(false);

  const isCorrect = selectedIndex === correctIndex;

  return (
    <div className="bg-slate-900/80 border border-slate-800 rounded-2xl p-6 space-y-4 font-sans shadow-xl my-6">
      <div className="flex items-center gap-2 text-xs font-mono text-cyan-400 font-bold">
        <HelpCircle className="w-4 h-4" /> Lesson Quiz & Concept Check
      </div>

      <h3 className="text-base font-bold text-slate-100">{question}</h3>

      <div className="space-y-2">
        {options.map((opt, idx) => {
          let btnStyle = "bg-slate-950 border-slate-800 text-slate-300 hover:border-slate-700";
          if (submitted) {
            if (idx === correctIndex) {
              btnStyle = "bg-emerald-500/20 border-emerald-500/50 text-emerald-300 font-bold";
            } else if (idx === selectedIndex) {
              btnStyle = "bg-rose-500/20 border-rose-500/50 text-rose-300";
            }
          } else if (idx === selectedIndex) {
            btnStyle = "bg-cyan-500/10 border-cyan-500/40 text-cyan-300 font-semibold";
          }

          return (
            <button
              key={idx}
              onClick={() => !submitted && setSelectedIndex(idx)}
              className={`w-full text-left p-3.5 rounded-xl border text-xs transition-all flex items-center justify-between ${btnStyle}`}
            >
              <span>{opt}</span>
              {submitted && idx === correctIndex && <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" />}
              {submitted && idx === selectedIndex && idx !== correctIndex && <XCircle className="w-4 h-4 text-rose-400 shrink-0" />}
            </button>
          );
        })}
      </div>

      {!submitted ? (
        <button
          onClick={() => selectedIndex !== null && setSubmitted(true)}
          disabled={selectedIndex === null}
          className="px-4 py-2 rounded-xl bg-cyan-500 hover:bg-cyan-400 disabled:opacity-50 text-slate-950 font-bold text-xs transition shadow-md"
        >
          Check Answer
        </button>
      ) : (
        <div className={`p-4 rounded-xl text-xs space-y-1 ${isCorrect ? 'bg-emerald-500/10 border border-emerald-500/20 text-emerald-300' : 'bg-rose-500/10 border border-rose-500/20 text-rose-300'}`}>
          <div className="font-bold flex items-center gap-1.5">
            {isCorrect ? <CheckCircle2 className="w-4 h-4" /> : <XCircle className="w-4 h-4" />}
            {isCorrect ? "Correct!" : "Incorrect"}
          </div>
          <p className="text-slate-300">{explanation}</p>
        </div>
      )}
    </div>
  );
}
