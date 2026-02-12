import { motion } from "framer-motion";
import { skills } from "@/lib/data";

export function Skills() {
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
    hidden: { opacity: 0, scale: 0.8 },
    visible: {
      opacity: 1,
      scale: 1,
      transition: { duration: 0.5 },
    },
  };

  return (
    <section id="skills" className="relative py-20 px-4 sm:px-6 lg:px-8">
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
              Skills & Technologies
            </h2>
            <div className="w-24 h-1 bg-linear-to-r from-purple-600 to-purple-800 dark:from-purple-400 dark:to-purple-600 mx-auto" />
          </motion.div>

          {/* Skills Grid */}
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
            {skills.map((skill) => (
              <motion.div
                key={skill.name}
                variants={itemVariants}
                whileHover={{ scale: 1.05 }}
                className="p-6 bg-white/60 dark:bg-slate-800/60 backdrop-blur rounded-xl border border-gray-200 dark:border-slate-700 hover:border-purple-400 dark:hover:border-purple-600 flex flex-col items-center gap-4 transition-all duration-300 hover:shadow-lg hover:shadow-purple-500/20 group"
              >
                <skill.icon
                  className="w-10 h-10 transition-colors duration-300 group-hover:text-purple-600 dark:group-hover:text-purple-400"
                  style={{ color: skill.color }}
                />
                <span className="font-medium text-lg text-slate-900 dark:text-white">{skill.name}</span>
              </motion.div>
            ))}
          </div>
        </motion.div>
      </div>
    </section>
  );
}
