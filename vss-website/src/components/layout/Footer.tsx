import React from 'react';
import Link from 'next/link';
import { Code, Cpu, ExternalLink, Heart, Shield, Terminal, User } from 'lucide-react';
import { GithubIcon } from '@/components/icons/GithubIcon';
import { VSS_CREATOR } from '@/lib/vss-data';

export function Footer() {
  return (
    <footer className="border-t border-slate-800/80 bg-slate-950 text-slate-400 text-xs font-sans">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="grid grid-cols-1 md:grid-cols-5 gap-8 mb-12">
          {/* Brand & Creator Bio Column */}
          <div className="md:col-span-2 space-y-4">
            <div className="flex items-center space-x-2.5">
              <div className="w-8 h-8 rounded-lg bg-gradient-to-tr from-cyan-500 to-emerald-500 p-0.5">
                <div className="w-full h-full bg-slate-950 rounded-[6px] flex items-center justify-center font-mono font-bold text-cyan-400 text-xs">
                  VSS
                </div>
              </div>
              <span className="font-bold text-slate-100 text-base tracking-tight">
                VSS Programming Language
              </span>
            </div>
            <p className="text-slate-400 leading-relaxed text-xs max-w-sm">
              Very Simple Syntax — A lightweight, readable, general-purpose programming language compiled in C with ARC memory management and native OS worker-thread concurrency.
            </p>
            <div className="p-3.5 rounded-xl bg-slate-900/80 border border-slate-800 text-slate-300 space-y-1">
              <div className="flex items-center space-x-1.5 font-semibold text-cyan-400">
                <User className="w-3.5 h-3.5 text-cyan-400" />
                <span>Created & Invented by {VSS_CREATOR.name}</span>
              </div>
              <p className="text-[11px] text-slate-400">
                Lead Compiler Architect & Author of the VSS language specification and stack-based VM implementation.
              </p>
              <div className="pt-1.5 flex items-center flex-wrap gap-2 text-[11px]">
                <Link href="/creator" className="text-cyan-400 hover:underline flex items-center space-x-1">
                  <span>Authoritative Creator Bio</span>
                </Link>
                <a href={VSS_CREATOR.githubUrl} target="_blank" rel="noopener noreferrer" className="text-slate-400 hover:text-slate-200 flex items-center space-x-1">
                  <span>GitHub Profile</span>
                  <ExternalLink className="w-2.5 h-2.5" />
                </a>
                <a href={VSS_CREATOR.linkedinUrl} target="_blank" rel="noopener noreferrer" className="text-slate-400 hover:text-cyan-300 flex items-center space-x-1">
                  <span>LinkedIn Profile</span>
                  <ExternalLink className="w-2.5 h-2.5" />
                </a>
              </div>
            </div>
          </div>

          {/* Quick Links */}
          <div>
            <h4 className="font-semibold text-slate-200 uppercase tracking-wider text-[11px] mb-3">
              Documentation
            </h4>
            <ul className="space-y-2 text-slate-400">
              <li><Link href="/getting-started" className="hover:text-cyan-400 transition">Getting Started</Link></li>
              <li><Link href="/install" className="hover:text-cyan-400 transition">Installation Guide</Link></li>
              <li><Link href="/language-reference" className="hover:text-cyan-400 transition">Language Reference</Link></li>
              <li><Link href="/standard-library" className="hover:text-cyan-400 transition">Standard Library</Link></li>
              <li><Link href="/docs/v3-1" className="hover:text-cyan-400 transition">VSS 3.1 Concurrency</Link></li>
              <li><Link href="/tutorials" className="hover:text-cyan-400 transition">Step-by-Step Tutorials</Link></li>
            </ul>
          </div>

          {/* Architecture & Internals */}
          <div>
            <h4 className="font-semibold text-slate-200 uppercase tracking-wider text-[11px] mb-3">
              Architecture & Specs
            </h4>
            <ul className="space-y-2 text-slate-400">
              <li><Link href="/compiler" className="hover:text-cyan-400 transition">C Compiler Pipeline</Link></li>
              <li><Link href="/advanced" className="hover:text-cyan-400 transition">ARC Memory Engine</Link></li>
              <li><Link href="/architecture" className="hover:text-cyan-400 transition">OS Worker Threads</Link></li>
              <li><Link href="/examples" className="hover:text-cyan-400 transition">35 Runnable Examples</Link></li>
              <li><Link href="/projects" className="hover:text-cyan-400 transition">Real-World Projects</Link></li>
              <li><Link href="/roadmap" className="hover:text-cyan-400 transition">Language Roadmap</Link></li>
            </ul>
          </div>

          {/* Ecosystem & Releases */}
          <div>
            <h4 className="font-semibold text-slate-200 uppercase tracking-wider text-[11px] mb-3">
              Ecosystem & Downloads
            </h4>
            <ul className="space-y-2 text-slate-400">
              <li>
                <Link href="/install" className="hover:text-cyan-400 transition flex items-center space-x-1">
                  <span>WinGet Package: {VSS_CREATOR.wingetPackage}</span>
                </Link>
              </li>
              <li>
                <a href={VSS_CREATOR.vscodeExtUrl} target="_blank" rel="noopener noreferrer" className="hover:text-cyan-400 transition flex items-center space-x-1">
                  <span>VS Code Extension</span>
                </a>
              </li>
              <li><Link href="/releases" className="hover:text-cyan-400 transition">Release Downloads</Link></li>
              <li><Link href="/changelog" className="hover:text-cyan-400 transition">Changelog History</Link></li>
              <li><Link href="/community" className="hover:text-cyan-400 transition">Developer Community</Link></li>
              <li><Link href="/faq" className="hover:text-cyan-400 transition">Frequently Asked Questions</Link></li>
            </ul>
          </div>
        </div>

        {/* Bottom Bar */}
        <div className="pt-8 border-t border-slate-800/80 flex flex-col sm:flex-row items-center justify-between gap-4 text-slate-500">
          <p>© {new Date().getFullYear()} VSS Language. Designed & Created by <strong className="text-slate-300 font-semibold">Vooka Sai Siddharth</strong>. MIT License.</p>
          <div className="flex items-center space-x-4">
            <Link href="/sitemap.xml" className="hover:text-slate-400 transition">Sitemap</Link>
            <Link href="/robots.txt" className="hover:text-slate-400 transition">Robots.txt</Link>
          </div>
        </div>
      </div>
    </footer>
  );
}
