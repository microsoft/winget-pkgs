import React from "react";
import Link from "next/link";
import { Terminal, Globe, Database, Cpu, Shield, FileText, Layers, ArrowRight, Sparkles } from "lucide-react";
import { CodeBlock } from "@/components/ui/CodeBlock";
import { JsonLd } from "@/components/seo/JsonLd";
import { VSS_CREATOR } from "@/lib/vss-data";

export const metadata = {
  title: "What Can I Build with VSS? — Capabilities & Applications",
  description: "Discover what software applications you can build using VSS 3.1: CLI utilities, REST APIs, SQLite desktop tools, HTTP web servers, concurrent worker queues, and desktop GUIs.",
};

const CAPABILITIES = [
  {
    icon: Terminal,
    title: "1. Command-Line (CLI) Applications",
    desc: "Build fast command-line utilities, file scanners, system monitors, and argument processors with zero external runtime overhead.",
    code: `include "system"
include "filesystem font"

make args becomes system.args()
say "Running VSS CLI Tool with arguments: " + args`
  },
  {
    icon: Globe,
    title: "2. Web Servers & REST APIs",
    desc: "Create high-throughput HTTP servers with route handlers (`web.route`), JSON responses (`json.stringify`), and multi-threaded request processing.",
    code: `include "web"
include "json"

web.route GET "/api/status" task needs req, res
  res.send_json(200, json.stringify({"status": "healthy", "engine": "VSS 3.1"}))
finish

web.serve(8080)`
  },
  {
    icon: Database,
    title: "3. Database Applications (SQLite 3)",
    desc: "Connect directly to local SQLite databases, run raw SQL queries, or use the fluent ORM QueryBuilder for desktop and server persistence.",
    code: `include "database"

make db becomes database.open("app.db")
db.execute("CREATE TABLE IF NOT EXISTS users (id INT, name TEXT)")
make rows becomes db.query("SELECT * FROM users")`
  },
  {
    icon: Cpu,
    title: "4. Multi-Threaded Concurrent Applications",
    desc: "Dispatch tasks across physical CPU worker cores with VSS 3.1 `start task`, `await`, parallel iterations, channels, block mutexes, and atomics.",
    code: `include "collections"

make atomic_val becomes atomic_create(0)
parallel item in [10, 20, 30, 40]
  atomic_add(atomic_val, item)
finish`
  }
];

export default function WhatCanIBuildPage() {
  return (
    <div className="container mx-auto px-4 py-12 max-w-6xl space-y-16 font-sans">
      <JsonLd />

      <div className="text-center space-y-4 max-w-4xl mx-auto">
        <div className="inline-flex items-center gap-2 px-3.5 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
          <Sparkles className="w-3.5 h-3.5" /> Capabilities Overview
        </div>
        <h1 className="text-4xl md:text-6xl font-extrabold tracking-tight text-slate-100">
          What Can I Build with VSS?
        </h1>
        <p className="text-slate-400 text-lg leading-relaxed">
          VSS (Very Simple Syntax) is a complete general-purpose programming language compiled in pure C. Here are the software applications you can build today.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        {CAPABILITIES.map((cap) => {
          const Icon = cap.icon;
          return (
            <div key={cap.title} className="bg-slate-900/80 border border-slate-800 rounded-3xl p-8 space-y-4 shadow-xl hover:border-cyan-500/40 transition">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-cyan-500/10 border border-cyan-500/20 text-cyan-400 flex items-center justify-center">
                  <Icon className="w-5 h-5" />
                </div>
                <h2 className="text-xl font-bold text-slate-100">{cap.title}</h2>
              </div>
              <p className="text-slate-300 text-sm leading-relaxed">{cap.desc}</p>
              <CodeBlock filename="app.vss" code={cap.code} />
            </div>
          );
        })}
      </div>
    </div>
  );
}
