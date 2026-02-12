import { motion } from "framer-motion";
import { ExternalLink, Github } from "lucide-react";

const projects = [
  {
    title: "E-Commerce Platform",
    description:
      "A full-featured e-commerce platform with product catalog, shopping cart, and payment integration",
    tags: ["React", "Node.js", "Stripe", "MongoDB"],
    image:
      "https://images.unsplash.com/photo-1557821552-17105176677c?w=600&h=400&fit=crop",
    links: {
      github: "https://github.com",
      live: "https://example.com",
    },
  },
  {
    title: "AI Content Generator",
    description:
      "An AI-powered application that generates creative content using OpenAI API",
    tags: ["React", "TypeScript", "OpenAI", "Tailwind"],
    image:
      "https://images.unsplash.com/photo-1762330467572-5199bc772a20?w=600&h=400&fit=crop",
    links: {
      github: "https://github.com",
      live: "https://example.com",
    },
  },
  {
    title: "Real-time Collaboration Tool",
    description:
      "A collaborative workspace with real-time updates, WebSocket integration, and user presence",
    tags: ["React", "WebSocket", "Firebase", "Next.js"],
    image:
      "https://images.unsplash.com/photo-1552664730-d307ca884978?w=600&h=400&fit=crop",
    links: {
      github: "https://github.com",
      live: "https://example.com",
    },
  },
  {
    title: "Mobile Task Manager",
    description:
      "A responsive task management app with offline support and cloud synchronization",
    tags: ["React Native", "TypeScript", "Redux", "Firebase"],
    image:
      "https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=600&h=400&fit=crop",
    links: {
      github: "https://github.com",
      live: "https://example.com",
    },
  },
  {
    title: "Data Visualization Dashboard",
    description:
      "An interactive dashboard displaying complex data with charts and real-time analytics",
    tags: ["React", "D3.js", "Python", "PostgreSQL"],
    image:
      "https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=600&h=400&fit=crop",
    links: {
      github: "https://github.com",
      live: "https://example.com",
    },
  },
  {
    title: "Social Media Platform",
    description:
      "A social networking platform with user profiles, feeds, messaging, and notifications",
    tags: ["React", "Node.js", "Socket.io", "PostgreSQL"],
    image:
      "https://images.unsplash.com/photo-1611532736597-de2d4265fba3?w=600&h=400&fit=crop",
    links: {
      github: "https://github.com",
      live: "https://example.com",
    },
  },
];

export function Projects() {
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
    hidden: { opacity: 0, y: 30 },
    visible: {
      opacity: 1,
      y: 0,
      transition: { duration: 0.6 },
    },
  };

  return (
    <section id="projects" className="relative py-20 px-4 sm:px-6 lg:px-8">
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
              Featured Projects
            </h2>
            <div className="w-24 h-1 bg-linear-to-r from-purple-600 to-purple-800 dark:from-purple-400 dark:to-purple-600 mx-auto" />
          </motion.div>

          {/* Projects Grid */}
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            {projects.map((project, idx) => (
              <motion.div
                key={idx}
                variants={itemVariants}
                className="group relative rounded-xl overflow-hidden bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-700 hover:border-purple-400 dark:hover:border-purple-600 shadow-lg hover:shadow-xl hover:shadow-purple-500/20 transition-all duration-300"
              >
                {/* Image */}
                <div className="relative h-48 overflow-hidden bg-gray-100 dark:bg-slate-700">
                  <img
                    src={project.image}
                    alt={project.title}
                    className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-300"
                  />
                  <div className="absolute inset-0 bg-linear-to-t from-black/50 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
                </div>

                {/* Content */}
                <div className="p-6">
                  <h3 className="text-xl font-heading font-bold mb-2 text-slate-900 dark:text-white group-hover:text-purple-600 dark:group-hover:text-purple-400 transition-colors duration-300">
                    {project.title}
                  </h3>
                  <p className="text-gray-600 dark:text-gray-400 text-sm mb-4 line-clamp-2">
                    {project.description}
                  </p>

                  {/* Tags */}
                  <div className="flex flex-wrap gap-2 mb-4">
                    {project.tags.map((tag) => (
                      <span
                        key={tag}
                        className="px-2 py-1 text-xs rounded bg-purple-100 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300 font-medium"
                      >
                        {tag}
                      </span>
                    ))}
                  </div>

                  {/* Links */}
                  <div className="flex gap-3 pt-4 border-t border-gray-200 dark:border-slate-700">
                    <a
                      href={project.links.github}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex-1 inline-flex items-center justify-center gap-2 px-3 py-2 rounded-lg bg-gray-100 dark:bg-slate-700 hover:bg-purple-600 dark:hover:bg-purple-600 text-gray-700 dark:text-gray-300 hover:text-white transition-colors duration-300 cursor-pointer text-sm font-medium"
                    >
                      <Github className="w-4 h-4" />
                      Code
                    </a>
                    <a
                      href={project.links.live}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex-1 inline-flex items-center justify-center gap-2 px-3 py-2 rounded-lg bg-linear-to-r from-purple-600 to-purple-700 hover:from-purple-700 hover:to-purple-800 text-white transition-all duration-300 cursor-pointer text-sm font-medium"
                    >
                      <ExternalLink className="w-4 h-4" />
                      Live
                    </a>
                  </div>
                </div>
              </motion.div>
            ))}
          </div>
        </motion.div>
      </div>
    </section>
  );
}
