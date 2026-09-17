import React from "react";
import Link from "next/link";
import { Globe, Terminal } from "lucide-react";
import { CodeBlock } from "@/components/ui/CodeBlock";
import { JsonLd } from "@/components/seo/JsonLd";

export const metadata = {
  title: "VSS Networking & HTTP Course — Clients & REST APIs",
  description: "Learn networking in VSS: HTTP GET, POST, PUT, DELETE requests, custom headers, JSON payload processing, and API integration.",
};

export default function NetworkingCoursePage() {
  return (
    <div className="container mx-auto px-4 py-12 max-w-5xl space-y-12 font-sans">
      <JsonLd />

      <div className="space-y-4 text-center max-w-3xl mx-auto">
        <div className="inline-flex items-center gap-2 px-3.5 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
          <Globe className="w-3.5 h-3.5" /> VSS Networking
        </div>
        <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight text-slate-100">
          Networking & HTTP Client Programming
        </h1>
        <p className="text-slate-400 text-lg leading-relaxed">
          Perform HTTP requests, process JSON payloads, and integrate third-party REST APIs using VSS standard library modules (`http`).
        </p>
      </div>

      <div className="bg-slate-900/80 border border-slate-800 rounded-3xl p-8 space-y-4 shadow-xl">
        <h2 className="text-2xl font-bold text-slate-100">HTTP Client Request</h2>
        <CodeBlock
          filename="http_client.vss"
          code={`include "http"
include "json"

make response becomes http.get("https://api.github.com/repos/siddharth-1118/vss-language")
make repo_info becomes json.parse(response.body)

say "VSS Repository Stars: " + repo_info.stargazers_count`}
          output={`VSS Repository Stars: 1250`}
        />
      </div>
    </div>
  );
}
