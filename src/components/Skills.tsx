import { motion } from "framer-motion";
import {
  SiReact, SiTypescript, SiTailwindcss, SiNodedotjs,
  SiPostgresql, SiGraphql, SiDocker, SiAmazonwebservices, SiFramer,
  SiGit, SiRubyonrails, SiPython, SiGo, SiRuby, SiFastapi, SiJavascript
} from "react-icons/si";

const skills = [
  { name: "Ruby", icon: SiRuby, color: "#CC0000" },
  { name: "Ruby on Rails", icon: SiRubyonrails, color: "#CC0000" },
  { name: "Python", icon: SiPython, color: "#3776AB" },
  { name: "FastAPI", icon: SiFastapi, color: "#009688" },
  { name: "Go", icon: SiGo, color: "#007D9C" },
  { name: "PostgreSQL", icon: SiPostgresql, color: "#4169E1" },
  { name: "JavaScript", icon: SiJavascript, color: "#F7DF1E" },
  { name: "TypeScript", icon: SiTypescript, color: "#3178C6" },
  { name: "React", icon: SiReact, color: "#61DAFB" },
  { name: "Framer Motion", icon: SiFramer, color: "#0055FF" },
  { name: "Node.js", icon: SiNodedotjs, color: "#339933" },
  { name: "Tailwind CSS", icon: SiTailwindcss, color: "#06B6D4" },
  { name: "GraphQL", icon: SiGraphql, color: "#E10098" },
  { name: "Git", icon: SiGit, color: "#F05032" },
  { name: "Docker", icon: SiDocker, color: "#2496ED" },
  { name: "AWS", icon: SiAmazonwebservices, color: "#FF9900" },
];

export function Skills() {
  return (
    <section id="skills" className="py-20 relative">
      <div className="container px-4 mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="text-center max-w-4xl mx-auto"
        >
          <h2 className="text-3xl md:text-4xl font-heading font-bold mb-12">
            My <span className="text-primary">Skills</span>
          </h2>

          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
            {skills.map((skill, index) => (
              <motion.div
                key={skill.name}
                initial={{ opacity: 0, scale: 0.8 }}
                whileInView={{ opacity: 1, scale: 1 }}
                viewport={{ once: true }}
                transition={{ delay: index * 0.05 }}
                whileHover={{ scale: 1.05 }}
                className="p-6 bg-secondary/50 backdrop-blur-sm rounded-xl border border-primary/20 hover:border-primary flex flex-col items-center gap-4 transition-all hover:bg-primary/10 hover:shadow-[0_0_20px_rgba(124,58,237,0.2)] group"
              >
                <skill.icon className="w-10 h-10 transition-colors group-hover:text-primary" style={{ color: "currentColor" }} />
                <span className="font-medium text-lg">{skill.name}</span>
              </motion.div>
            ))}
          </div>
        </motion.div>
      </div>
    </section>
  );
}
