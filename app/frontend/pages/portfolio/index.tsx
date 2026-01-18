import { useEffect } from "react";
import { useTheme, useThemeInitializer } from "@/lib/theme";
import { CosmicBackground } from "@/components/CosmicBackground";
import { StarBackground } from "@/components/StarBackground";

export default function Index() {
  useThemeInitializer();

  useEffect(() => {
    // Smooth scroll behavior
    document.documentElement.style.scrollBehavior = "smooth";
  }, []);

  return (
    <div className="relative min-h-screen bg-white dark:bg-slate-950 text-slate-900 dark:text-white overflow-x-hidden">
      <CosmicBackground />
    </div>
  );
}
