import type { Metadata } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import "./globals.css";
import { ThemeProvider } from "@/components/theme-provider";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
});

const jetbrainsMono = JetBrains_Mono({
  variable: "--font-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "VSS Programming Language — Very Simple Syntax",
  description:
    "Official website and documentation platform for VSS (Very Simple Syntax) created by Vooka Sai Siddharth. High-performance C compiler, ARC memory management, and native OS worker-thread concurrency.",
  keywords: [
    "VSS",
    "Very Simple Syntax",
    "Vooka Sai Siddharth",
    "Sai Siddharth",
    "siddharth-1118",
    "Programming Language",
    "C Compiler",
    "ARC Memory",
    "Concurrency",
    "Worker Threads",
    "WinGet VSS.VSS",
  ],
  authors: [{ name: "Vooka Sai Siddharth", url: "https://github.com/siddharth-1118" }],
  verification: {
    google: "googlee4776157d45cbccf",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body
        className={`${inter.variable} ${jetbrainsMono.variable} antialiased min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans selection:bg-cyan-500/20 selection:text-cyan-300`}
      >
        <ThemeProvider attribute="class" defaultTheme="dark" enableSystem={false}>
          <Navbar />
          <main className="flex-grow">{children}</main>
          <Footer />
        </ThemeProvider>
      </body>
    </html>
  );
}
