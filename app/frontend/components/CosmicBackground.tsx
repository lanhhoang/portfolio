import { useEffect, useRef } from "react";
import { useTheme } from "@/lib/theme";

interface Star {
  x: number;
  y: number;
  radius: number;
  opacity: number;
  twinkleSpeed: number;
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

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    // Set canvas size
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;

    const stars: Star[] = [];
    const meteors: Meteor[] = [];

    // Create stars - more stars for dark mode, fewer for light
    const starCount = isDark ? 120 : 80;
    for (let i = 0; i < starCount; i++) {
      stars.push({
        x: Math.random() * canvas.width,
        y: Math.random() * canvas.height,
        radius: Math.random() * (isDark ? 1.5 : 2) + 0.5,
        opacity: Math.random() * 0.5 + 0.5,
        twinkleSpeed: Math.random() * 0.03 + 0.01,
      });
    }

    // Create meteors
    const meteorCount = isDark ? 3 : 4;
    for (let i = 0; i < meteorCount; i++) {
      meteors.push({
        x: Math.random() * canvas.width,
        y: Math.random() * canvas.height * 0.5,
        length: Math.random() * 80 + 50,
        speed: Math.random() * 3 + 2,
      });
    }

    let animationFrameId: number;

    const animate = () => {
      // Clear canvas with theme-appropriate background
      if (isDark) {
        ctx.fillStyle = "rgba(10, 10, 15, 0.1)";
      } else {
        // Light mode: soft light purple/lavender background
        ctx.fillStyle = "rgba(250, 245, 255, 0.15)";
      }
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      // Draw and update stars
      stars.forEach((star) => {
        star.opacity += star.twinkleSpeed;
        if (star.opacity >= 1 || star.opacity <= 0.3) {
          star.twinkleSpeed *= -1;
        }

        if (isDark) {
          // Dark mode: white/light purple stars
          ctx.fillStyle = `rgba(255, 255, 255, ${star.opacity})`;
        } else {
          // Light mode: purple/violet stars with subtle glow
          const purpleShade =
            Math.random() > 0.5 ? "168, 85, 247" : "139, 92, 246";
          ctx.fillStyle = `rgba(${purpleShade}, ${star.opacity * 0.7})`;
        }
        ctx.beginPath();
        ctx.arc(star.x, star.y, star.radius, 0, Math.PI * 2);
        ctx.fill();

        // Add subtle glow for light mode
        if (!isDark) {
          ctx.shadowBlur = 3;
          ctx.shadowColor = "rgba(139, 92, 246, 0.3)";
        } else {
          ctx.shadowBlur = 0;
        }
      });

      // Reset shadow
      ctx.shadowBlur = 0;

      // Draw and update meteors
      meteors.forEach((meteor) => {
        meteor.x += meteor.speed;
        meteor.y += meteor.speed * 0.5;

        // Create gradient for meteor
        const gradient = ctx.createLinearGradient(
          meteor.x,
          meteor.y,
          meteor.x - meteor.length,
          meteor.y - meteor.length * 0.5
        );

        if (isDark) {
          // Dark mode: bright purple meteors
          gradient.addColorStop(0, "rgba(168, 85, 247, 0.8)");
          gradient.addColorStop(1, "rgba(168, 85, 247, 0)");
        } else {
          // Light mode: deeper purple/violet meteors
          gradient.addColorStop(0, "rgba(124, 58, 237, 0.6)");
          gradient.addColorStop(0.3, "rgba(139, 92, 246, 0.4)");
          gradient.addColorStop(1, "rgba(167, 139, 250, 0)");
        }

        ctx.strokeStyle = gradient;
        ctx.lineWidth = isDark ? 2 : 2.5;
        ctx.beginPath();
        ctx.moveTo(meteor.x, meteor.y);
        ctx.lineTo(meteor.x - meteor.length, meteor.y - meteor.length * 0.5);
        ctx.stroke();

        // Reset meteor position
        if (meteor.x > canvas.width + 100 || meteor.y > canvas.height + 100) {
          meteor.x = -100;
          meteor.y = Math.random() * canvas.height * 0.5;
        }
      });

      animationFrameId = requestAnimationFrame(animate);
    };

    animate();

    // Handle window resize
    const handleResize = () => {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
    };

    window.addEventListener("resize", handleResize);

    return () => {
      cancelAnimationFrame(animationFrameId);
      window.removeEventListener("resize", handleResize);
    };
  }, [isDark]);

  return (
    <canvas
      ref={canvasRef}
      className="fixed inset-0 pointer-events-none"
      style={{
        zIndex: 0,
        backgroundColor: isDark ? "#0a0a0f" : "#faf5ff",
      }}
    />
  );
}
