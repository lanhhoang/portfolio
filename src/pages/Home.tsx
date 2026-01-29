import { useThemeInitializer } from "@/lib/theme"

import { ThemeToggle } from "@/components/ThemeToggle"
import { CosmicBackground } from "@/components/CosmicBackground"

import { Navbar } from "@/components/Navbar"
import { Footer } from "@/components/Footer"

export function Home() {
  useThemeInitializer()

  return (
    <div className="relative min-h-screen bg-white dark:bg-slate-950 text-slate-900 dark:text-white overflow-x-hidden">
      {/* Theme Toggle */}
      <ThemeToggle />
      {/* Background Effects */}
      <CosmicBackground />

      <div className="relative z-10">
        {/* Navbar */}
        <Navbar />

        {/* Sections */}
        <main>
          {/* Hero Section */}
          {/* About Section */}
          {/* Skills Section */}
          {/* Projects Section */}
          {/* Contact Section */}
        </main>

        {/* Footer */}
        <Footer />
      </div>
    </div>
  );
}
