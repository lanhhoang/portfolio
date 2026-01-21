import { create } from "zustand"
import { useEffect } from "react"

interface ThemeStore {
  isDark: boolean
  toggle: () => void
  setTheme: (dark: boolean) => void
}

export const useTheme = create<ThemeStore>((set) => ({
  isDark: localStorage.getItem("theme") === "dark",
  toggle: () =>
    set((state) => {
      const newDark = !state.isDark
      localStorage.setItem("theme", newDark ? "dark" : "light")
      document.documentElement.classList.toggle("dark", newDark)
      return { isDark: newDark }
    }),
  setTheme: (dark: boolean) => {
    localStorage.setItem("theme", dark ? "dark" : "light")
    document.documentElement.classList.toggle("dark", dark)
    set({ isDark: dark })
  },
}))

export function useThemeInitializer() {
  useEffect(() => {
    const isDark = localStorage.getItem("theme") === "dark"
    document.documentElement.classList.toggle("dark", isDark)
  }, [])
}
