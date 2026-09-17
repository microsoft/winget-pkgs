import React from 'react';
import Link from 'next/link';
import { ArrowRight, CheckCircle, Code, Cpu, Download, Terminal, User, ShieldCheck } from 'lucide-react';
import { CodeBlock } from '@/components/ui/CodeBlock';
import { VSS_CREATOR } from '@/lib/vss-data';

export const metadata = {
  title: 'Install VSS Programming Language — Windows, Linux, macOS',
  description: 'Official installation guide for VSS Programming Language created by Vooka Sai Siddharth. Install via WinGet (VSS.VSS), VS Code Extension, or compile from C source.',
};

export default function InstallPage() {
  return (
    <div className="container mx-auto px-4 py-12 max-w-5xl space-y-12">
      {/* Header */}
      <div className="space-y-4">
        <div className="inline-flex items-center space-x-2 px-3 py-1 rounded-full bg-cyan-500/10 border border-cyan-500/30 text-cyan-400 text-xs font-mono font-semibold">
          <Download className="w-3.5 h-3.5" />
          <span>OFFICIAL INSTALLATION GUIDE</span>
        </div>
        <h1 className="text-4xl font-extrabold text-slate-100 tracking-tight">
          Install VSS Programming Language
        </h1>
        <p className="text-slate-400 text-lg leading-relaxed">
          VSS is published on Microsoft WinGet and VS Code Marketplace by lead compiler architect{' '}
          <strong className="text-cyan-400 font-semibold">{VSS_CREATOR.name}</strong>.
        </p>
      </div>

      {/* Option 1: WinGet */}
      <div className="p-8 rounded-3xl bg-gradient-to-r from-cyan-950/40 via-slate-900 to-slate-900 border border-cyan-500/40 space-y-4 shadow-xl">
        <div className="flex items-center justify-between">
          <div className="space-y-1">
            <span className="px-2.5 py-0.5 rounded text-[10px] font-mono font-bold bg-cyan-500/20 text-cyan-400 uppercase tracking-wider">
              Recommended for Windows
            </span>
            <h2 className="text-2xl font-bold text-slate-100">Microsoft WinGet</h2>
          </div>
          <ShieldCheck className="w-8 h-8 text-cyan-400" />
        </div>

        <p className="text-slate-300 text-sm">
          Run PowerShell as Administrator and execute:
        </p>

        <div className="bg-slate-950 p-4 rounded-xl border border-slate-800 font-mono text-sm text-cyan-400 flex items-center justify-between">
          <span>winget install VSS.VSS</span>
        </div>
      </div>
    </div>
  );
}
