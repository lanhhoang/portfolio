import { motion } from "framer-motion";
import { ArrowRight } from "lucide-react";
import { socialLinks } from "@/lib/data";

export function Hero() {
  const containerVariants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: 0.2,
        delayChildren: 0.3,
      },
    },
  };

  const itemVariants = {
    hidden: { opacity: 0, y: 20 },
    visible: {
      opacity: 1,
      y: 0,
      transition: {
        duration: 0.8,
        ease: "easeOut" as const,
      },
    },
  };

  return (
    <section
      id="home"
      className="relative min-h-screen flex items-center justify-center px-4 sm:px-6 lg:px-8 pt-20"
    >
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        {/* Gradient orbs */}
        <div className="absolute top-20 left-10 w-80 h-80 bg-purple-500/20 dark:bg-purple-400/10 rounded-full filter blur-3xl animate-float" />
        <div className="absolute bottom-20 right-10 w-80 h-80 bg-purple-700/20 dark:bg-purple-600/10 rounded-full filter blur-3xl animate-float" />
      </div>

      <motion.div
        variants={containerVariants}
        initial="hidden"
        animate="visible"
        className="relative z-10 max-w-4xl text-center"
      >
        {/* Greeting */}
        <motion.div variants={itemVariants} className="mb-6">
          <span className="inline-block px-4 py-2 rounded-full bg-purple-100 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300 font-medium text-sm">
            Welcome to my portfolio
          </span>
        </motion.div>

        {/* Main Heading */}
        <motion.h1
          variants={itemVariants}
          className="text-5xl sm:text-7xl font-heading font-bold mb-6 bg-linear-to-r from-slate-900 via-purple-600 to-purple-900 dark:from-white dark:via-purple-400 dark:to-purple-300 bg-clip-text text-transparent"
        >
          Hello, I'm <strong>Anthony</strong>
        </motion.h1>

        {/* Subtitle */}
        <motion.p
          variants={itemVariants}
          className="text-lg sm:text-xl text-gray-600 dark:text-gray-400 mb-8 max-w-2xl mx-auto"
        >
          I'm a <strong>software engineer</strong> with over 4 years of experience in designing and developing web applications. My focus is <strong>Ruby on Rails</strong>, <strong>React</strong>, <strong>PostgreSQL</strong> and <strong>AWS</strong>.
        </motion.p>

        {/* CTA Buttons */}
        <motion.div
          variants={itemVariants}
          className="flex flex-col sm:flex-row gap-4 justify-center mb-12"
        >
          <a
            href="#projects"
            className="inline-flex items-center gap-2 px-8 py-3 rounded-lg bg-linear-to-r from-purple-600 to-purple-700 dark:from-purple-500 dark:to-purple-600 text-white font-medium hover:from-purple-700 hover:to-purple-800 dark:hover:from-purple-600 dark:hover:to-purple-700 transition-all duration-300 shadow-lg hover:shadow-purple-500/50 cursor-pointer group"
          >
            View My Work
            <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
          </a>
          <a
            href="#contact"
            className="inline-flex items-center gap-2 px-8 py-3 rounded-lg border-2 border-gray-300 dark:border-slate-600 text-gray-700 dark:text-gray-300 font-medium hover:border-purple-600 dark:hover:border-purple-400 hover:text-purple-600 dark:hover:text-purple-400 transition-all duration-300 cursor-pointer"
          >
            Get In Touch
          </a>
        </motion.div>

        {/* Social Links */}
        <motion.div
          variants={itemVariants}
          className="flex justify-center gap-6"
        >
          {socialLinks.map((link) => {
            const Icon = link.icon;
            return (
              <motion.a
                key={link.label}
                href={link.href}
                target="_blank"
                rel="noopener noreferrer"
                whileHover={{ scale: 1.1, y: -5 }}
                whileTap={{ scale: 0.95 }}
                className="w-12 h-12 rounded-full bg-gray-100 dark:bg-slate-800 hover:bg-purple-100 dark:hover:bg-purple-900/30 flex items-center justify-center text-gray-700 dark:text-gray-300 hover:text-purple-600 dark:hover:text-purple-400 transition-all duration-300 cursor-pointer"
              >
                <Icon className="w-6 h-6" />
              </motion.a>
            );
          })}
        </motion.div>
      </motion.div>

      {/* Scroll indicator */}
      <motion.div
        animate={{ y: [0, 10, 0] }}
        transition={{ duration: 2, repeat: Infinity }}
        className="absolute bottom-8 left-1/2 transform -translate-x-1/2 cursor-pointer"
      >
        <div className="w-6 h-10 border-2 border-purple-600 dark:border-purple-400 rounded-full flex justify-center">
          <motion.div
            animate={{ y: [0, 4, 0] }}
            transition={{ duration: 2, repeat: Infinity }}
            className="w-1 h-2 bg-purple-600 dark:bg-purple-400 rounded-full mt-2"
          />
        </div>
      </motion.div>
    </section>
  );
}
