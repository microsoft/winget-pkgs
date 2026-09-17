"use client";

import React, { useState } from 'react';
import { Check, Copy, Play, Terminal } from 'lucide-react';

interface CodeBlockProps {
  code: string;
  language?: string;
  filename?: string;
  output?: string;
  showOutput?: boolean;
}

export function CodeBlock({
  code,
  language = 'vss',
  filename,
  output,
  showOutput = true,
}: CodeBlockProps) {
  const [copied, setCopied] = useState(false);
  const [isExecuting, setIsExecuting] = useState(false);
  const [hasExecuted, setHasExecuted] = useState(false);

  const handleCopy = () => {
    navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleRun = () => {
    setIsExecuting(true);
    setTimeout(() => {
      setIsExecuting(false);
      setHasExecuted(true);
    }, 400);
  };

  return (
    <div className="rounded-xl border border-slate-800 bg-slate-950 overflow-hidden font-mono text-sm shadow-xl my-4">
      {/* Header bar */}
      <div className="flex items-center justify-between px-4 py-2 bg-slate-900 border-b border-slate-800/80 text-xs text-slate-400">
        <div className="flex items-center space-x-2">
          <div className="flex space-x-1.5">
            <div className="w-2.5 h-2.5 rounded-full bg-rose-500/80" />
            <div className="w-2.5 h-2.5 rounded-full bg-amber-500/80" />
            <div className="w-2.5 h-2.5 rounded-full bg-emerald-500/80" />
          </div>
          {filename && (
            <span className="font-sans font-medium text-slate-300 ml-2">
              {filename}
            </span>
          )}
          <span className="px-1.5 py-0.5 rounded text-[10px] uppercase font-semibold bg-slate-800 text-cyan-400 border border-slate-700">
            {language}
          </span>
        </div>

        <div className="flex items-center space-x-2">
          {output && (
            <button
              onClick={handleRun}
              disabled={isExecuting}
              className="flex items-center space-x-1 px-2.5 py-1 rounded bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-400 border border-cyan-500/30 transition text-[11px] font-sans font-semibold disabled:opacity-50"
              title="Run VSS script output simulator"
            >
              <Play className={`w-3 h-3 ${isExecuting ? 'animate-spin' : ''}`} />
              <span>{isExecuting ? 'Running...' : 'Simulate Run'}</span>
            </button>
          )}

          <button
            onClick={handleCopy}
            className="flex items-center space-x-1 px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-300 transition text-[11px] font-sans"
            title="Copy code"
          >
            {copied ? (
              <>
                <Check className="w-3 h-3 text-emerald-400" />
                <span className="text-emerald-400 font-semibold">Copied!</span>
              </>
            ) : (
              <>
                <Copy className="w-3 h-3" />
                <span>Copy</span>
              </>
            )}
          </button>
        </div>
      </div>

      {/* Code body */}
      <div className="p-4 overflow-x-auto text-slate-200 text-xs leading-relaxed">
        <pre className="font-mono">
          <code>
            {code.split('\n').map((line, idx) => (
              <div key={idx} className="table-row">
                <span className="table-cell pr-4 text-slate-600 select-none text-right w-8">
                  {idx + 1}
                </span>
                <span className="table-cell">{line}</span>
              </div>
            ))}
          </code>
        </pre>
      </div>

      {/* Simulated Execution Output */}
      {showOutput && output && (hasExecuted || true) && (
        <div className="border-t border-slate-800/80 bg-slate-900/60 p-3.5 text-xs">
          <div className="flex items-center space-x-2 text-slate-400 mb-1.5 text-[11px] font-sans font-semibold">
            <Terminal className="w-3.5 h-3.5 text-emerald-400" />
            <span>Output Window:</span>
          </div>
          <pre className="text-emerald-400 font-mono text-xs whitespace-pre-wrap bg-slate-950 p-2.5 rounded border border-slate-800">
            {output}
          </pre>
        </div>
      )}
    </div>
  );
}
