import { useEffect, useRef } from "react";
import { useTheme } from "@/lib/theme";

// Configuration constants for easier tuning
const CONFIG = {
  DARK: {
    STAR_COUNT: 120,
    METEOR_COUNT: 3,
    BG_COLOR: "rgba(10, 10, 15, 0.1)",
    CANVAS_BG: "#0a0a0f",
    STAR_MIN_RADIUS: 0.5,
    STAR_MAX_EXTRA_RADIUS: 1.5,
    METEOR_COLOR: "rgba(168, 85, 247, 0.8)",
    LINE_WIDTH: 2,
  },
  LIGHT: {
    STAR_COUNT: 80,
    METEOR_COUNT: 4,
    BG_COLOR: "rgba(250, 245, 255, 0.15)",
    CANVAS_BG: "#faf5ff",
    STAR_MIN_RADIUS: 0.5,
    STAR_MAX_EXTRA_RADIUS: 2,
    METEOR_COLORS: ["rgba(124, 58, 237, 0.6)", "rgba(139, 92, 246, 0.4)"],
    LINE_WIDTH: 2.5,
  },
  STAR_COLORS: ["168, 85, 247", "139, 92, 246"],
  METEOR_MIN_LEN: 50,
  METEOR_LEN_VAR: 80,
  METEOR_MIN_SPEED: 2,
  METEOR_SPEED_VAR: 3,
};

interface Star {
  x: number;
  y: number;
  radius: number;
  opacity: number;
  twinkleSpeed: number;
  color: string;
}

interface Meteor {
  x: number;
  y: number;
  length: number;
  speed: number;
}

export function CosmicBackground() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const { isDark } = useTheme();

  // Persist state across theme changes
  const starsRef = useRef<Star[]>([]);
  const meteorsRef = useRef<Meteor[]>([]);
  const isDarkRef = useRef(isDark);

  // Sync ref with theme
  useEffect(() => {
    isDarkRef.current = isDark;
  }, [isDark]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const initCanvas = () => {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;

      const starCount = Math.max(CONFIG.DARK.STAR_COUNT, CONFIG.LIGHT.STAR_COUNT);

      // Initialize stars if not already done, or add more if resize expanded the area
      if (starsRef.current.length === 0) {
        for (let i = 0; i < starCount; i++) {
          starsRef.current.push(createStar(canvas.width, canvas.height));
        }
      } else {
        // Simple logic to reposition stars if they are out of bounds after resize
        starsRef.current.forEach(star => {
          if (star.x > canvas.width) star.x = Math.random() * canvas.width;
          if (star.y > canvas.height) star.y = Math.random() * canvas.height;
        });
      }

      if (meteorsRef.current.length === 0) {
        const meteorCount = Math.max(CONFIG.DARK.METEOR_COUNT, CONFIG.LIGHT.METEOR_COUNT);
        for (let i = 0; i < meteorCount; i++) {
          meteorsRef.current.push(createMeteor(canvas.width, canvas.height));
        }
      }
    };

    const createStar = (width: number, height: number): Star => ({
      x: Math.random() * width,
      y: Math.random() * height,
      radius: Math.random() * (isDark ? CONFIG.DARK.STAR_MAX_EXTRA_RADIUS : CONFIG.LIGHT.STAR_MAX_EXTRA_RADIUS) + CONFIG.DARK.STAR_MIN_RADIUS,
      opacity: Math.random() * 0.5 + 0.5,
      twinkleSpeed: Math.random() * 0.03 + 0.01,
      color: CONFIG.STAR_COLORS[Math.floor(Math.random() * CONFIG.STAR_COLORS.length)],
    });

    const createMeteor = (width: number, height: number): Meteor => ({
      x: Math.random() * width,
      y: Math.random() * height * 0.5,
      length: Math.random() * CONFIG.METEOR_LEN_VAR + CONFIG.METEOR_MIN_LEN,
      speed: Math.random() * CONFIG.METEOR_SPEED_VAR + CONFIG.METEOR_MIN_SPEED,
    });

    initCanvas();

    let animationFrameId: number;

    const animate = () => {
      const dark = isDarkRef.current;
      const config = dark ? CONFIG.DARK : CONFIG.LIGHT;

      // Clear canvas with trail effect
      ctx.fillStyle = config.BG_COLOR;
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      // Draw and update stars
      const starCount = dark ? CONFIG.DARK.STAR_COUNT : CONFIG.LIGHT.STAR_COUNT;
      for (let i = 0; i < starCount; i++) {
        const star = starsRef.current[i];
        if (!star) continue;

        star.opacity += star.twinkleSpeed;
        if (star.opacity >= 1 || star.opacity <= 0.3) {
          star.twinkleSpeed *= -1;
        }

        if (dark) {
          ctx.fillStyle = `rgba(255, 255, 255, ${star.opacity})`;
        } else {
          ctx.fillStyle = `rgba(${star.color}, ${star.opacity * 0.7})`;
        }

        ctx.beginPath();
        ctx.arc(star.x, star.y, star.radius, 0, Math.PI * 2);
        ctx.fill();
      }

      // Draw and update meteors
      const meteorCount = dark ? CONFIG.DARK.METEOR_COUNT : CONFIG.LIGHT.METEOR_COUNT;
      for (let i = 0; i < meteorCount; i++) {
        const meteor = meteorsRef.current[i];
        if (!meteor) continue;

        meteor.x += meteor.speed;
        meteor.y += meteor.speed * 0.5;

        const gradient = ctx.createLinearGradient(
          meteor.x,
          meteor.y,
          meteor.x - meteor.length,
          meteor.y - meteor.length * 0.5
        );

        if (dark) {
          gradient.addColorStop(0, CONFIG.DARK.METEOR_COLOR);
          gradient.addColorStop(1, "rgba(168, 85, 247, 0)");
        } else {
          gradient.addColorStop(0, CONFIG.LIGHT.METEOR_COLORS[0]);
          gradient.addColorStop(0.3, CONFIG.LIGHT.METEOR_COLORS[1]);
          gradient.addColorStop(1, "rgba(167, 139, 250, 0)");
        }

        ctx.strokeStyle = gradient;
        ctx.lineWidth = config.LINE_WIDTH;
        ctx.beginPath();
        ctx.moveTo(meteor.x, meteor.y);
        ctx.lineTo(meteor.x - meteor.length, meteor.y - meteor.length * 0.5);
        ctx.stroke();

        if (meteor.x > canvas.width + 100 || meteor.y > canvas.height + 100) {
          meteor.x = -100;
          meteor.y = Math.random() * canvas.height * 0.5;
        }
      }

      animationFrameId = requestAnimationFrame(animate);
    };

    animate();

    const handleResize = () => {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;

      // If expanding, add more stars or re-position ones that were off-screen
      starsRef.current.forEach(star => {
        if (star.x > canvas.width) star.x = Math.random() * canvas.width;
        if (star.y > canvas.height) star.y = Math.random() * canvas.height;
      });
    };

    window.addEventListener("resize", handleResize);

    return () => {
      cancelAnimationFrame(animationFrameId);
      window.removeEventListener("resize", handleResize);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []); // Only run once on mount

  return (
    <canvas
      ref={canvasRef}
      className="fixed inset-0 pointer-events-none transition-colors duration-500"
      style={{
        zIndex: 0,
        backgroundColor: isDark ? CONFIG.DARK.CANVAS_BG : CONFIG.LIGHT.CANVAS_BG,
      }}
    />
  );
}

