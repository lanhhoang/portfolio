import { motion } from "framer-motion";

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
          <div className="flex justify-center">
            <motion.div variants={itemVariants} className="w-full max-w-2xl">
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
          </div>
        </motion.div>
      </div>
    </section>
  );
}
