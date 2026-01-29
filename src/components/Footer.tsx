import { motion } from "framer-motion";
import { Heart, Github, Linkedin } from "lucide-react";

export function Footer() {
  const currentYear = new Date().getFullYear();

  const containerVariants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: 0.1,
      },
    },
  };

  const itemVariants = {
    hidden: { opacity: 0, y: 10 },
    visible: {
      opacity: 1,
      y: 0,
      transition: { duration: 0.4 },
    },
  };

  const socialLinks = [
    { icon: Github, href: "https://github.com/lanhhoang", label: "GitHub" },
    { icon: Linkedin, href: "https://linkedin.com/in/lanh", label: "LinkedIn" },
  ];

  return (
    <footer className="relative border-t border-gray-200 dark:border-slate-800 bg-white/50 dark:bg-slate-900/50 backdrop-blur">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <motion.div
          variants={containerVariants}
          initial="hidden"
          animate="visible"
        >
          <div className="grid md:grid-cols-4 gap-8 mb-8">
            {/* Brand */}
            <motion.div variants={itemVariants}>
              <h2 className="text-2xl font-heading font-bold bg-gradient-to-r from-purple-600 to-purple-800 dark:from-purple-400 dark:to-purple-600 bg-clip-text text-transparent mb-2">
                Portfolio
              </h2>
              <p className="text-gray-600 dark:text-gray-400 text-sm">
                Full-stack engineer crafting beautiful digital experiences.
              </p>
            </motion.div>

            {/* Navigation */}
            <motion.div variants={itemVariants}>
              <h3 className="font-heading font-semibold text-slate-900 dark:text-white mb-4">
                Navigation
              </h3>
              <ul className="space-y-2 text-sm text-gray-600 dark:text-gray-400">
                <li>
                  <a
                    href="#home"
                    className="hover:text-purple-600 dark:hover:text-purple-400 transition-colors cursor-pointer"
                  >
                    Home
                  </a>
                </li>
                <li>
                  <a
                    href="#about"
                    className="hover:text-purple-600 dark:hover:text-purple-400 transition-colors cursor-pointer"
                  >
                    About
                  </a>
                </li>
                <li>
                  <a
                    href="#projects"
                    className="hover:text-purple-600 dark:hover:text-purple-400 transition-colors cursor-pointer"
                  >
                    Projects
                  </a>
                </li>
                <li>
                  <a
                    href="#contact"
                    className="hover:text-purple-600 dark:hover:text-purple-400 transition-colors cursor-pointer"
                  >
                    Contact
                  </a>
                </li>
              </ul>
            </motion.div>

            {/* Resources */}
            <motion.div variants={itemVariants}>
              <h3 className="font-heading font-semibold text-slate-900 dark:text-white mb-4">
                Resources
              </h3>
              <ul className="space-y-2 text-sm text-gray-600 dark:text-gray-400">
                <li>
                  <a
                    href="#"
                    className="hover:text-purple-600 dark:hover:text-purple-400 transition-colors cursor-pointer"
                  >
                    Blog
                  </a>
                </li>
                <li>
                  <a
                    href="#"
                    className="hover:text-purple-600 dark:hover:text-purple-400 transition-colors cursor-pointer"
                  >
                    Documentation
                  </a>
                </li>
                <li>
                  <a
                    href="#"
                    className="hover:text-purple-600 dark:hover:text-purple-400 transition-colors cursor-pointer"
                  >
                    Resume
                  </a>
                </li>
                <li>
                  <a
                    href="#"
                    className="hover:text-purple-600 dark:hover:text-purple-400 transition-colors cursor-pointer"
                  >
                    Privacy
                  </a>
                </li>
              </ul>
            </motion.div>

            {/* Social */}
            <motion.div variants={itemVariants}>
              <h3 className="font-heading font-semibold text-slate-900 dark:text-white mb-4">
                Follow
              </h3>
              <div className="flex gap-3">
                {socialLinks.map((link) => {
                  const Icon = link.icon;
                  return (
                    <motion.a
                      key={link.label}
                      href={link.href}
                      target="_blank"
                      rel="noopener noreferrer"
                      whileHover={{ scale: 1.1, y: -3 }}
                      whileTap={{ scale: 0.95 }}
                      className="w-10 h-10 rounded-lg bg-gray-100 dark:bg-slate-800 hover:bg-purple-600 dark:hover:bg-purple-600 flex items-center justify-center text-gray-700 dark:text-gray-400 hover:text-white transition-all duration-300 cursor-pointer"
                      title={link.label}
                    >
                      <Icon className="w-5 h-5" />
                    </motion.a>
                  );
                })}
              </div>
            </motion.div>
          </div>

          {/* Divider */}
          <div className="border-t border-gray-200 dark:border-slate-800 my-8" />

          {/* Copyright */}
          <motion.div
            variants={itemVariants}
            className="flex flex-col sm:flex-row justify-between items-center text-sm text-gray-600 dark:text-gray-400"
          >
            <p className="flex items-center gap-2 mb-4 sm:mb-0">
              © {currentYear} Portfolio. Made with
              <Heart className="w-4 h-4 text-purple-600 dark:text-purple-400 fill-current" />
              by Anthony Hoang
            </p>
            <p>All rights reserved.</p>
          </motion.div>
        </motion.div>
      </div>
    </footer>
  );
}
