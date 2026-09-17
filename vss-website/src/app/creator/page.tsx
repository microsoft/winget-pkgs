import React from 'react';
import Link from 'next/link';
import { ArrowRight, Award, CheckCircle, Code, Cpu, ExternalLink, Layers, ShieldCheck, Terminal, User } from 'lucide-react';
import { GithubIcon } from '@/components/icons/GithubIcon';
import { VSS_CREATOR, VSS_VERSIONS } from '@/lib/vss-data';

export const metadata = {
  title: 'Creator of VSS Programming Language — Vooka Sai Siddharth',
  description: 'Official authoritative creator page for VSS (Very Simple Syntax) Programming Language. Learn about inventor and compiler architect Vooka Sai Siddharth, language history, and development milestones.',
};

export default function CreatorPage() {
  return (
    <div className="container mx-auto px-4 py-12 max-w-5xl space-y-16">
      {/* Header Profile */}
      <div className="bg-gradient-to-r from-cyan-950/40 via-slate-900 to-indigo-950/40 border border-cyan-500/30 rounded-3xl p-8 sm:p-12 shadow-2xl relative overflow-hidden">
        <div className="space-y-6 relative z-10">
          <div className="inline-flex items-center space-x-2 px-3 py-1 rounded-full bg-cyan-500/10 border border-cyan-500/30 text-cyan-400 text-xs font-mono font-semibold">
            <Award className="w-3.5 h-3.5" />
            <span>AUTHORITATIVE CREATOR ATTRIBUTION</span>
          </div>

          <h1 className="text-4xl sm:text-5xl font-extrabold text-slate-100 tracking-tight">
            {VSS_CREATOR.name}
          </h1>

          <p className="text-cyan-300 font-mono text-sm font-semibold">
            {VSS_CREATOR.role} (GitHub: <a href={VSS_CREATOR.githubUrl} target="_blank" rel="noopener noreferrer" className="underline">{VSS_CREATOR.handle}</a>)
          </p>

          <p className="text-slate-300 text-base sm:text-lg leading-relaxed max-w-3xl">
            {VSS_CREATOR.bio}
          </p>

          <div className="pt-4 flex flex-wrap gap-4">
            <a
              href={VSS_CREATOR.githubUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="px-5 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 flex items-center space-x-2 text-sm font-semibold transition"
            >
              <GithubIcon className="w-4 h-4" />
              <span>GitHub Profile (siddharth-1118)</span>
              <ExternalLink className="w-3 h-3 text-slate-400" />
            </a>

            <a
              href={VSS_CREATOR.linkedinUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="px-5 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-cyan-300 border border-slate-700 flex items-center space-x-2 text-sm font-semibold transition"
            >
              <span className="font-mono font-bold text-cyan-400">in</span>
              <span>LinkedIn Profile</span>
              <ExternalLink className="w-3 h-3 text-slate-400" />
            </a>

            <a
              href={VSS_CREATOR.vscodeExtUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="px-5 py-2.5 rounded-xl bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold text-sm flex items-center space-x-2 transition shadow-lg shadow-cyan-500/20"
            >
              <Code className="w-4 h-4" />
              <span>VS Code Extension</span>
            </a>
          </div>
        </div>
      </div>

      {/* Developer Connect Profiles */}
      <div className="space-y-6">
        <h2 className="text-2xl font-bold text-slate-100 flex items-center space-x-2">
          <User className="w-6 h-6 text-cyan-400" />
          <span>Developer Profiles & Social Channels</span>
        </h2>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
          {/* GitHub Profile Card */}
          <a
            href={VSS_CREATOR.githubUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="p-6 rounded-2xl bg-slate-900/80 border border-slate-800 hover:border-cyan-500/50 group transition space-y-4"
          >
            <div className="flex items-center justify-between">
              <div className="p-3 rounded-xl bg-slate-800 text-slate-200 group-hover:scale-110 transition-transform">
                <GithubIcon className="w-6 h-6" />
              </div>
              <ExternalLink className="w-4 h-4 text-slate-400 group-hover:text-cyan-400 transition" />
            </div>
            <div>
              <h3 className="text-lg font-bold text-slate-100 group-hover:text-cyan-400 transition">
                GitHub Profile
              </h3>
              <p className="text-xs font-mono text-cyan-400 mt-0.5">@siddharth-1118</p>
              <p className="text-slate-400 text-xs mt-2 leading-relaxed">
                Explore Vooka Sai Siddharth's public open-source code repositories, contributions, and developer projects.
              </p>
            </div>
          </a>

          {/* LinkedIn Profile Card */}
          <a
            href={VSS_CREATOR.linkedinUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="p-6 rounded-2xl bg-slate-900/80 border border-slate-800 hover:border-cyan-500/50 group transition space-y-4"
          >
            <div className="flex items-center justify-between">
              <div className="p-3 rounded-xl bg-slate-800 text-cyan-400 group-hover:scale-110 transition-transform font-mono font-bold text-lg">
                in
              </div>
              <ExternalLink className="w-4 h-4 text-slate-400 group-hover:text-cyan-400 transition" />
            </div>
            <div>
              <h3 className="text-lg font-bold text-slate-100 group-hover:text-cyan-400 transition">
                LinkedIn Profile
              </h3>
              <p className="text-xs font-mono text-cyan-400 mt-0.5">Vooka Sai Siddharth</p>
              <p className="text-slate-400 text-xs mt-2 leading-relaxed">
                Connect professionally with Vooka Sai Siddharth (Compiler Architect & VSS Inventor) on LinkedIn.
              </p>
            </div>
          </a>
        </div>
      </div>

      {/* Development Milestones */}
      <div className="space-y-8">
        <h2 className="text-2xl font-bold text-slate-100 flex items-center space-x-2">
          <Cpu className="w-6 h-6 text-cyan-400" />
          <span>Language Development Timeline</span>
        </h2>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {VSS_CREATOR.milestones.map((m, idx) => (
            <div key={idx} className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 space-y-2">
              <div className="text-xs font-mono text-cyan-400 font-bold">{m.year}</div>
              <p className="text-slate-200 text-sm font-medium">{m.event}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
