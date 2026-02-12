import { motion } from "framer-motion";
import { Briefcase, Calendar } from "lucide-react";
import { experiences } from "@/lib/data";

export function Experience() {
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
    hidden: { opacity: 0, x: -30 },
    visible: {
      opacity: 1,
      x: 0,
      transition: { duration: 0.6 },
    },
  };

  return (
    <section id="experience" className="relative py-20 px-4 sm:px-6 lg:px-8">
      <div className="max-w-4xl mx-auto">
        <motion.div
          variants={containerVariants}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, margin: "-100px" }}
        >
          {/* Section Title */}
          <motion.div variants={itemVariants} className="text-center mb-16">
            <h2 className="text-4xl sm:text-5xl font-heading font-bold mb-4 text-slate-900 dark:text-white">
              Experience
            </h2>
            <div className="w-24 h-1 bg-linear-to-r from-purple-600 to-purple-800 dark:from-purple-400 dark:to-purple-600 mx-auto" />
          </motion.div>

          {/* Timeline */}
          <div className="space-y-8">
            {experiences.map((exp, idx) => (
              <motion.div
                key={idx}
                variants={itemVariants}
                className="relative pl-8 pb-8 border-l-2 border-purple-600 dark:border-purple-400 last:border-l-transparent"
              >
                {/* Timeline dot */}
                <div className="absolute -left-4 top-0 w-8 h-8 bg-purple-600 dark:bg-purple-400 rounded-full border-4 border-white dark:border-slate-900 flex items-center justify-center">
                  <Briefcase className="w-4 h-4 text-white dark:text-slate-900" />
                </div>

                {/* Content */}
                <div className="bg-white/60 dark:bg-slate-800/60 backdrop-blur p-6 rounded-xl border border-gray-200 dark:border-slate-700 hover:border-purple-400 dark:hover:border-purple-600 transition-all duration-300">
                  <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-2 mb-3">
                    <div>
                      <h3 className="text-xl font-heading font-bold text-slate-900 dark:text-white">
                        {exp.title}
                      </h3>
                      <p className="text-purple-600 dark:text-purple-400 font-medium">
                        {exp.company}
                      </p>
                    </div>
                    <div className="flex items-center gap-2 text-gray-600 dark:text-gray-400 text-sm font-medium whitespace-nowrap">
                      <Calendar className="w-4 h-4" />
                      {exp.period}
                    </div>
                  </div>

                  <p className="text-gray-600 dark:text-gray-400 mb-4">
                    {exp.description}
                  </p>

                  {/* Highlights */}
                  <ul className="space-y-2">
                    {exp.highlights.map((highlight, hIdx) => (
                      <li
                        key={hIdx}
                        className="flex gap-2 text-gray-600 dark:text-gray-400 text-sm"
                      >
                        <span className="text-purple-600 dark:text-purple-400 font-bold">
                          •
                        </span>
                        {highlight}
                      </li>
                    ))}
                  </ul>
                </div>
              </motion.div>
            ))}
          </div>
        </motion.div>
      </div>
    </section>
  );
}
