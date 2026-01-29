import { motion } from "framer-motion";
import { Code2, Palette, Zap } from "lucide-react";

export function About() {
  const containerVariants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: 0.2,
      },
    },
  };

  const itemVariants = {
    hidden: { opacity: 0, y: 20 },
    visible: {
      opacity: 1,
      y: 0,
      transition: { duration: 0.8 },
    },
  };

  const features = [
    {
      icon: Code2,
      title: "Clean Code",
      description: "Writing maintainable, scalable code with best practices",
    },
    {
      icon: Zap,
      title: "Performance",
      description: "Optimizing applications for speed and efficiency",
    },
    {
      icon: Palette,
      title: "UI/UX Design",
      description: "Creating beautiful, intuitive user experiences",
    },
  ];

  return (
    <section id="about" className="relative py-20 px-4 sm:px-6 lg:px-8">
      <div className="max-w-6xl mx-auto">
        <motion.div
          variants={containerVariants}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, margin: "-100px" }}
        >
          {/* Section Title */}
          <motion.div variants={itemVariants} className="text-center mb-16">
            <h2 className="text-4xl sm:text-5xl font-heading font-bold mb-4 text-slate-900 dark:text-white">
              About Me
            </h2>
            <div className="w-24 h-1 bg-linear-to-r from-purple-600 to-purple-800 dark:from-purple-400 dark:to-purple-600 mx-auto" />
          </motion.div>

          {/* Content Grid */}
          <div className="grid md:grid-cols-3 gap-8">
            <motion.div variants={itemVariants} className="md:col-span-2">
              <div className="space-y-4 text-gray-600 dark:text-gray-400 text-lg leading-relaxed">
                <p>
                  After graduating with a degree in Electronics Engineering, I decided to pursue my passion for programming. I enrolled in a coding bootcamp and learned full-stack web development using Ruby on Rails. My favorite part of programming is the problem-solving aspect. I love the feeling of finally figuring out a solution to a problem.
                </p>
                <p>
                  My core stack is Ruby on Rails, React, PostgreSQL, and AWS. I am also familiar with Python, TypeScript, and Go. I am always looking to learn new technologies.
                </p>
                <p>
                  When I'm not coding, I enjoy going to the gym, meditating, and reading books on my Kindle. I also enjoy learning new things. I'm currently learning French.
                </p>
              </div>
            </motion.div>

            {/* Features */}
            <motion.div variants={containerVariants} className="space-y-4">
              {features.map((feature) => {
                const Icon = feature.icon;
                return (
                  <motion.div
                    key={feature.title}
                    variants={itemVariants}
                    className="p-4 rounded-lg bg-white/50 dark:bg-slate-800/50 backdrop-blur border border-gray-200 dark:border-slate-700 hover:border-purple-400 dark:hover:border-purple-600 transition-all duration-300 cursor-pointer"
                  >
                    <Icon className="w-6 h-6 text-purple-600 dark:text-purple-400 mb-2" />
                    <h3 className="font-heading font-semibold text-slate-900 dark:text-white mb-1">
                      {feature.title}
                    </h3>
                    <p className="text-sm text-gray-600 dark:text-gray-400">
                      {feature.description}
                    </p>
                  </motion.div>
                );
              })}
            </motion.div>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
