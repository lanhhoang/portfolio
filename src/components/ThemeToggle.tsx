import { Moon, Sun } from "lucide-react"
import { useTheme } from "@/lib/theme"
import { cn } from "@/lib/utils"


export function ThemeToggle() {
  const { isDark, toggle } = useTheme()

  return (
    <button
      onClick={toggle}
      className={cn(
        "fixed max-sm:hidden bottom-5 right-5 z-50 p-2 rounded-lg bg-gray-100 dark:bg-slate-800 hover:bg-gray-200 dark:hover:bg-slate-700 transition-colors duration-200 cursor-pointer",
        "focus:outline-hidden"
      )}
      aria-label="Toggle Theme"
    >
      {isDark ? (
        <Sun className="w-6 h-6 text-yellow-500" />
      ) : (
        <Moon className="w-6 h-6 text-slate-700" />
      )}
    </button>
  );
}
