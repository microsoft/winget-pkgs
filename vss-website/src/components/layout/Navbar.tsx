"use client";

import React, { useState, useRef, useEffect } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { ChevronDown, Code, Cpu, Database, Globe, Menu, Rocket, Search, Sparkles, Terminal, X, Zap, BookOpen, Layers, CheckSquare, FileText } from 'lucide-react';
import { GithubIcon } from '@/components/icons/GithubIcon';
import { SearchModal } from '@/components/search/SearchModal';
import { VSS_VERSIONS } from '@/lib/vss-data';

export function Navbar() {
  const pathname = usePathname();
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
  const [isVersionDropdownOpen, setIsVersionDropdownOpen] = useState(false);
  const [isTopicsDropdownOpen, setIsTopicsDropdownOpen] = useState(false);

  const topicsRef = useRef<HTMLDivElement>(null);
  const versionRef = useRef<HTMLDivElement>(null);

  const activeVersion = VSS_VERSIONS.find((v) => v.status === 'Latest') || VSS_VERSIONS[0];

  // Close dropdowns when clicking outside
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (topicsRef.current && !topicsRef.current.contains(event.target as Node)) {
        setIsTopicsDropdownOpen(false);
      }
      if (versionRef.current && !versionRef.current.contains(event.target as Node)) {
        setIsVersionDropdownOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const topicLinks = [
    { name: 'Programs & Code', href: '/programs', icon: Code, desc: '35+ runnable VSS code examples' },
    { name: 'Data Structures & Algorithms', href: '/dsa', icon: Cpu, desc: 'Trees, Graphs, Sorting in VSS' },
    { name: 'Web Development', href: '/web-development', icon: Globe, desc: 'HTTP servers, REST APIs & Webviews' },
    { name: 'Database & SQL', href: '/database', icon: Database, desc: 'SQLite ORM & persistent storage' },
    { name: 'Concurrency Engine', href: '/concurrency', icon: Zap, desc: 'OS worker threads, channels & mutexes' },
    { name: 'Practice Problems', href: '/practice', icon: CheckSquare, desc: 'Interactive coding challenges' },
    { name: '30-Min Cheat Sheet', href: '/cheatsheet', icon: FileText, desc: 'Fast-track syntax reference' },
  ];

  return (
    <>
      <header className="sticky top-0 z-40 w-full border-b border-slate-800/80 bg-slate-950/90 backdrop-blur-md">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between gap-4">
          
          {/* LEFT: Logo & Version Selector */}
          <div className="flex items-center space-x-3 shrink-0">
            <Link href="/" className="flex items-center space-x-2.5 group">
              <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-cyan-500 via-sky-400 to-indigo-500 p-0.5 shadow-lg shadow-cyan-500/20 group-hover:scale-105 transition-transform">
                <div className="w-full h-full bg-slate-950 rounded-[10px] flex items-center justify-center font-mono font-bold text-cyan-400 text-sm">
                  VSS
                </div>
              </div>
              <div className="flex flex-col">
                <span className="font-extrabold text-slate-100 text-base tracking-tight leading-none group-hover:text-cyan-400 transition">
                  VSS Language
                </span>
                <span className="text-[10px] text-slate-400 font-mono tracking-wide mt-0.5 hidden sm:inline">
                  Very Simple Syntax
                </span>
              </div>
            </Link>

            {/* Version Selector Dropdown */}
            <div className="relative hidden md:block" ref={versionRef}>
              <button
                onClick={() => setIsVersionDropdownOpen(!isVersionDropdownOpen)}
                className="flex items-center space-x-1.5 px-2.5 py-1 rounded-lg bg-slate-900 border border-slate-800 hover:border-slate-700 text-xs font-mono text-cyan-400 transition"
              >
                <span>{activeVersion.version}</span>
                <span className="px-1 py-0.2 rounded text-[9px] font-bold bg-cyan-500/20 text-cyan-300 border border-cyan-500/30 uppercase">
                  {activeVersion.status}
                </span>
                <ChevronDown className="w-3 h-3 text-slate-400" />
              </button>

              {isVersionDropdownOpen && (
                <div className="absolute top-full left-0 mt-2 w-56 rounded-xl bg-slate-900 border border-slate-800 shadow-xl p-1.5 z-50 font-sans text-xs">
                  <div className="px-2 py-1 text-[10px] font-mono text-slate-400 uppercase font-bold">
                    VSS Releases
                  </div>
                  {VSS_VERSIONS.map((v) => (
                    <Link
                      key={v.version}
                      href={v.docUrl}
                      onClick={() => setIsVersionDropdownOpen(false)}
                      className="flex items-center justify-between px-2.5 py-1.5 rounded-lg hover:bg-slate-800 transition"
                    >
                      <span className="font-mono text-slate-200 font-semibold">{v.name}</span>
                      <span className="text-[10px] text-cyan-400">{v.status}</span>
                    </Link>
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* CENTER: Navigation Links */}
          <nav className="hidden lg:flex items-center space-x-1 font-sans">
            {/* Featured Learn Button */}
            <Link
              href="/learn"
              className="px-3 py-1.5 rounded-xl text-xs font-extrabold bg-gradient-to-r from-cyan-500 to-sky-400 hover:from-cyan-400 hover:to-sky-300 text-slate-950 transition shadow-md shadow-cyan-500/20 flex items-center gap-1.5 mr-1"
            >
              <Sparkles className="w-3.5 h-3.5" />
              <span>LEARN VSS</span>
            </Link>

            {/* Cloud IDE & Free Deploy Button */}
            <Link
              href="/deploy"
              className={`px-3 py-1.5 rounded-lg text-xs font-bold tracking-wide transition flex items-center gap-1.5 ${
                pathname === '/deploy'
                  ? 'bg-cyan-500/20 text-cyan-300 border border-cyan-500/40'
                  : 'text-cyan-400 hover:text-cyan-300 hover:bg-slate-900 border border-cyan-500/20'
              }`}
            >
              <Rocket className="w-3.5 h-3.5" />
              <span>IDE & DEPLOY</span>
            </Link>

            <Link
              href="/language"
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold tracking-wide transition ${
                pathname === '/language'
                  ? 'bg-cyan-500/10 text-cyan-400 border border-cyan-500/20'
                  : 'text-slate-300 hover:text-white hover:bg-slate-900'
              }`}
            >
              LANGUAGE
            </Link>

            <Link
              href="/what-can-i-build"
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold tracking-wide transition ${
                pathname === '/what-can-i-build'
                  ? 'bg-cyan-500/10 text-cyan-400 border border-cyan-500/20'
                  : 'text-slate-300 hover:text-white hover:bg-slate-900'
              }`}
            >
              WHAT CAN I BUILD?
            </Link>

            {/* Topics Megamenu Dropdown */}
            <div className="relative" ref={topicsRef}>
              <button
                onClick={() => setIsTopicsDropdownOpen(!isTopicsDropdownOpen)}
                className={`flex items-center space-x-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold tracking-wide transition ${
                  isTopicsDropdownOpen || topicLinks.some(t => pathname === t.href)
                    ? 'bg-cyan-500/10 text-cyan-400 border border-cyan-500/20'
                    : 'text-slate-300 hover:text-white hover:bg-slate-900'
                }`}
              >
                <span>TOPICS</span>
                <ChevronDown className={`w-3.5 h-3.5 text-slate-400 transition-transform ${isTopicsDropdownOpen ? 'rotate-180 text-cyan-400' : ''}`} />
              </button>

              {isTopicsDropdownOpen && (
                <div className="absolute top-full left-1/2 -translate-x-1/2 mt-2 w-80 rounded-2xl bg-slate-900 border border-slate-800 shadow-2xl p-2 z-50 font-sans">
                  <div className="px-3 py-1.5 text-[10px] font-mono text-cyan-400 uppercase font-bold border-b border-slate-800/80 mb-1">
                    VSS Learning Modules
                  </div>
                  <div className="space-y-0.5">
                    {topicLinks.map((topic) => {
                      const Icon = topic.icon;
                      const isTopicActive = pathname === topic.href;
                      return (
                        <Link
                          key={topic.name}
                          href={topic.href}
                          onClick={() => setIsTopicsDropdownOpen(false)}
                          className={`flex items-start space-x-3 p-2.5 rounded-xl transition ${
                            isTopicActive ? 'bg-cyan-500/10 border border-cyan-500/30' : 'hover:bg-slate-800/70'
                          }`}
                        >
                          <div className="p-1.5 rounded-lg bg-slate-800 text-cyan-400 shrink-0 mt-0.5">
                            <Icon className="w-4 h-4" />
                          </div>
                          <div>
                            <div className="text-xs font-bold text-slate-100 flex items-center justify-between">
                              <span>{topic.name}</span>
                            </div>
                            <p className="text-[11px] text-slate-400 mt-0.5 leading-snug">
                              {topic.desc}
                            </p>
                          </div>
                        </Link>
                      );
                    })}
                  </div>
                </div>
              )}
            </div>
          </nav>

          {/* RIGHT: Search Bar & Social Profiles */}
          <div className="flex items-center space-x-2 shrink-0">
            {/* Search Trigger */}
            <button
              onClick={() => setIsSearchOpen(true)}
              className="flex items-center space-x-2 px-3 py-1.5 rounded-xl bg-slate-900 border border-slate-800 hover:border-slate-700 text-slate-400 hover:text-slate-200 text-xs transition font-sans"
            >
              <Search className="w-3.5 h-3.5 text-cyan-400" />
              <span className="hidden sm:inline text-slate-300">Search VSS...</span>
              <kbd className="hidden sm:inline-block px-1.5 py-0.5 text-[10px] font-mono bg-slate-800 rounded border border-slate-700 text-slate-400">
                Cmd+K
              </kbd>
            </button>

            {/* GitHub Profile */}
            <a
              href="https://github.com/siddharth-1118"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center space-x-1.5 px-3 py-1.5 rounded-xl bg-slate-900 border border-slate-800 hover:border-slate-700 text-slate-300 hover:text-white transition text-xs"
              title="Vooka Sai Siddharth GitHub Profile"
            >
              <GithubIcon className="w-4 h-4 text-slate-200" />
              <span className="hidden md:inline font-mono text-xs text-slate-300">GitHub</span>
            </a>

            {/* LinkedIn Profile */}
            <a
              href="https://www.linkedin.com/in/vooka-sai-siddharth"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center space-x-1.5 px-3 py-1.5 rounded-xl bg-slate-900 border border-slate-800 hover:border-slate-700 text-slate-300 hover:text-cyan-400 transition text-xs"
              title="Vooka Sai Siddharth LinkedIn Profile"
            >
              <span className="font-mono font-bold text-xs text-cyan-400">in</span>
              <span className="hidden md:inline font-mono text-xs text-slate-300">LinkedIn</span>
            </a>

            {/* Mobile Menu Toggle */}
            <button
              onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
              className="lg:hidden p-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-400 hover:text-slate-200"
            >
              {isMobileMenuOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
            </button>
          </div>
        </div>

        {/* Mobile Dropdown Menu */}
        {isMobileMenuOpen && (
          <div className="lg:hidden bg-slate-950 border-b border-slate-800 p-4 space-y-2 max-h-96 overflow-y-auto font-sans">
            <Link
              href="/learn"
              onClick={() => setIsMobileMenuOpen(false)}
              className="block px-3 py-2 rounded-xl text-xs font-bold bg-gradient-to-r from-cyan-500 to-sky-400 text-slate-950"
            >
              LEARN VSS
            </Link>
            <Link
              href="/language"
              onClick={() => setIsMobileMenuOpen(false)}
              className="block px-3 py-2 rounded-lg text-xs font-semibold text-slate-300 hover:bg-slate-900 hover:text-cyan-400"
            >
              LANGUAGE SPECIFICATION
            </Link>
            <Link
              href="/what-can-i-build"
              onClick={() => setIsMobileMenuOpen(false)}
              className="block px-3 py-2 rounded-lg text-xs font-semibold text-slate-300 hover:bg-slate-900 hover:text-cyan-400"
            >
              WHAT CAN I BUILD?
            </Link>
            
            <div className="pt-2 border-t border-slate-800 text-[10px] font-mono text-slate-400 uppercase font-bold px-3">
              Explore Modules
            </div>
            {topicLinks.map((topic) => (
              <Link
                key={topic.name}
                href={topic.href}
                onClick={() => setIsMobileMenuOpen(false)}
                className="block px-3 py-2 rounded-lg text-xs font-semibold text-slate-300 hover:bg-slate-900 hover:text-cyan-400"
              >
                {topic.name}
              </Link>
            ))}
          </div>
        )}
      </header>

      {/* Cmd+K Search Modal */}
      <SearchModal isOpen={isSearchOpen} onClose={() => setIsSearchOpen(false)} />
    </>
  );
}
