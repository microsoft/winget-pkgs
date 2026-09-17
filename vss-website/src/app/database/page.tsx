import React from "react";
import Link from "next/link";
import { Database, Terminal, Code } from "lucide-react";
import { CodeBlock } from "@/components/ui/CodeBlock";
import { JsonLd } from "@/components/seo/JsonLd";

export const metadata = {
  title: "VSS Database Programming Course — SQLite 3 & CRUD",
  description: "Learn database programming in VSS: native SQLite 3 integration, table creation, SQL queries, parameterized statements, and fluent ORM QueryBuilder.",
};

export default function DatabaseCoursePage() {
  return (
    <div className="container mx-auto px-4 py-12 max-w-5xl space-y-12 font-sans">
      <JsonLd />

      <div className="space-y-4 text-center max-w-3xl mx-auto">
        <div className="inline-flex items-center gap-2 px-3.5 py-1 text-xs font-semibold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
          <Database className="w-3.5 h-3.5" /> VSS Database Programming
        </div>
        <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight text-slate-100">
          Database Integration & SQLite in VSS
        </h1>
        <p className="text-slate-400 text-lg leading-relaxed">
          Master SQLite 3 database connections, SQL query execution, parameterized statements, and ORM query builders in VSS.
        </p>
      </div>

      <div className="bg-slate-900/80 border border-slate-800 rounded-3xl p-8 space-y-4 shadow-xl">
        <h2 className="text-2xl font-bold text-slate-100">SQLite CRUD Operations</h2>
        <CodeBlock
          filename="database_demo.vss"
          code={`include "database"

make db becomes database.open("store.db")
db.execute("CREATE TABLE IF NOT EXISTS inventory (id INT PRIMARY KEY, item TEXT, price REAL)")

# Insert Record
db.execute("INSERT INTO inventory VALUES (1, 'VSS Pro Compiler', 29.99)")

# Select Records
make items becomes db.query("SELECT * FROM inventory")
repeat item in items
  say "Item: " + item.item + " -> $" + item.price
finish`}
          output={`Item: VSS Pro Compiler -> $29.99`}
        />
      </div>
    </div>
  );
}
