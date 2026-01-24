import { useThemeInitializer } from "@/lib/theme"

import { ThemeToggle } from "@/components/ThemeToggle"
import { CosmicBackground } from "@/components/CosmicBackground"

export function Home() {
  useThemeInitializer()

  return (
    <div className="relative min-h-screen bg-white dark:bg-slate-950 text-slate-900 dark:text-white overflow-x-hidden">
      {/* Theme Toggle */}
      <ThemeToggle />
      {/* Background Effects */}
      <CosmicBackground />
      {/* Navbar */}
      {/* Hero Section */}
      {/* About Section */}
      {/* Skills Section */}
      {/* Projects Section */}
      {/* Contact Section */}
      {/* Footer */}
    </div>
  );
}
