import React from "react";
import Link from "next/link";
import { Globe, Terminal, Code, ArrowRight } from "lucide-react";
import { CodeBlock } from "@/components/ui/CodeBlock";
import { JsonLd } from "@/components/seo/JsonLd";

export const metadata = {
  title: "VSS Web Development Course — HTTP Web Servers & REST APIs",
  description: "Learn web development in VSS: create HTTP web servers, HTTP routes, JSON API handlers, SQLite database backends, and multi-threaded request processing.",
};

export default function WebDevelopmentPage() {
  return (
    <div className="container mx-auto px-4 py-12 max-w-5xl space-y-12 font-sans">
      <JsonLd />

      <div className="space-y-4 text-center max-w-3xl mx-auto">
        <div className="inline-flex items-center gap-2 px-3.5 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
          <Globe className="w-3.5 h-3.5" /> VSS Web Development
        </div>
        <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight text-slate-100">
          Backend Web Development in VSS
        </h1>
        <p className="text-slate-400 text-lg leading-relaxed">
          Learn how to build production HTTP web servers, JSON REST APIs, and database-backed microservices with zero external web framework dependencies.
        </p>
      </div>

      <div className="space-y-8">
        <div className="bg-slate-900/80 border border-slate-800 rounded-3xl p-8 space-y-4 shadow-xl">
          <h2 className="text-2xl font-bold text-slate-100">1. Creating an HTTP Web Server</h2>
          <p className="text-slate-300 text-sm">
            VSS includes a built-in multi-threaded C web server module (`web`). Define routes with `web.route` and start the server with `web.serve(port)`.
          </p>
          <CodeBlock
            filename="web_server.vss"
            code={`include "web"
include "json"

web.route GET "/" task needs req, res
  res.send_html(200, "<h1>Welcome to VSS Web Server</h1>")
finish

web.route GET "/api/health" task needs req, res
  res.send_json(200, json.stringify({"status": "ok", "uptime": "99.9%"}))
finish

say "Server running on http://localhost:8080"
web.serve(8080)`}
            output={`Server running on http://localhost:8080`}
          />
        </div>
      </div>
    </div>
  );
}
