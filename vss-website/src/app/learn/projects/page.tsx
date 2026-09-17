import React from "react";
import Link from "next/link";
import { Layers, Terminal, Globe, Database, Shield, Cpu, ArrowRight } from "lucide-react";
import { CodeBlock } from "@/components/ui/CodeBlock";
import { JsonLd } from "@/components/seo/JsonLd";
import { VSS_CREATOR } from "@/lib/vss-data";

export const metadata = {
  title: "Build Real Software with VSS — Guided Application Projects",
  description: "Build 10 real-world guided software projects in VSS: CLI utilities, SQLite CRUD desktop apps, REST APIs, HTTP web servers, and concurrent scrapers.",
};

const GUIDED_PROJECTS = [
  {
    id: "proj-1",
    title: "Project 1: Command-Line File Scanner CLI",
    level: "Beginner / Intermediate",
    desc: "Scan directories concurrently, read file stats, and compute SHA256 checksums.",
    architecture: ["Requirements: Scan folder, calculate hashes", "VSS Modules: `filesystem`, `crypto`, `system`", "Execution: Multi-threaded background tasks"],
    code: `include "filesystem"
include "crypto"
include "system"

make files becomes filesystem.list_dir(".")
say "Scanning " + files.length + " files..."

repeat file in files
  make content becomes filesystem.read_file(file)
  make hash becomes crypto.sha256(content)
  say "File: " + file + " -> SHA256: " + hash
finish`
  },
  {
    id: "proj-2",
    title: "Project 2: REST API Server with SQLite Persistence",
    level: "Advanced",
    desc: "Build a multi-threaded HTTP web server connected to a local SQLite database.",
    architecture: ["Requirements: GET /users, POST /users", "VSS Modules: `web`, `database`, `json`"],
    code: `include "web"
include "database"
include "json"

make db becomes database.open("app.db")
db.execute("CREATE TABLE IF NOT EXISTS users (id INT, name TEXT)")

web.route GET "/api/users" task needs req, res
  make rows becomes db.query("SELECT * FROM users")
  res.send_json(200, json.stringify(rows))
finish

say "Starting server on port 8080..."
web.serve(8080)`
  }
];

export default function ProjectsGuidedPage() {
  return (
    <div className="container mx-auto px-4 py-12 max-w-5xl space-y-12 font-sans">
      <JsonLd />

      <div className="space-y-4 text-center max-w-3xl mx-auto">
        <div className="inline-flex items-center gap-2 px-3.5 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
          <Layers className="w-3.5 h-3.5" /> Guided Project Path
        </div>
        <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight text-slate-100">
          Build Real Software with VSS
        </h1>
        <p className="text-slate-400 text-lg leading-relaxed">
          Step-by-step application tutorials created by lead architect <strong className="text-cyan-400">{VSS_CREATOR.name}</strong> to master real software architecture in VSS.
        </p>
      </div>

      <div className="space-y-8">
        {GUIDED_PROJECTS.map((p) => (
          <div key={p.id} className="bg-slate-900/70 border border-slate-800 rounded-3xl p-8 space-y-6 shadow-xl">
            <div className="flex justify-between items-start">
              <div>
                <span className="text-xs font-mono text-cyan-400 font-bold uppercase">{p.level}</span>
                <h2 className="text-2xl font-bold text-slate-100 mt-1">{p.title}</h2>
              </div>
              <span className="px-3 py-1 text-xs font-bold rounded-full bg-cyan-500/20 text-cyan-400 border border-cyan-500/30">
                Verified VSS 3.1
              </span>
            </div>

            <p className="text-slate-300 text-sm leading-relaxed">{p.desc}</p>

            <div className="bg-slate-950 p-4 rounded-xl border border-slate-800 space-y-1 font-mono text-xs text-slate-300">
              <div className="text-cyan-400 font-bold uppercase text-[10px] tracking-wider mb-2">Architecture Blueprint</div>
              {p.architecture.map((item, i) => (
                <div key={i} className="flex items-center gap-2">
                  <span className="text-emerald-400">✓</span> {item}
                </div>
              ))}
            </div>

            <CodeBlock filename="main.vss" code={p.code} />
          </div>
        ))}
      </div>
    </div>
  );
}
