import { motion } from "framer-motion";
import { Send } from "lucide-react";
import { useState } from "react";

export function Contact() {
  const [formData, setFormData] = useState({
    name: "",
    email: "",
    subject: "",
    message: "",
  });

  const [submitted, setSubmitted] = useState(false);

  const handleChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>
  ) => {
    const { name, value } = e.target;
    setFormData((prev) => ({
      ...prev,
      [name]: value,
    }));
  };

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    // Handle form submission here
    console.log("Form submitted:", formData);
    setSubmitted(true);
    setTimeout(() => {
      setSubmitted(false);
      setFormData({ name: "", email: "", subject: "", message: "" });
    }, 3000);
  };

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
      transition: { duration: 0.6 },
    },
  };

  return (
    <section id="contact" className="relative py-20 px-4 sm:px-6 lg:px-8">
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
              Get In Touch
            </h2>
            <div className="w-24 h-1 bg-linear-to-r from-purple-600 to-purple-800 dark:from-purple-400 dark:to-purple-600 mx-auto" />
            <p className="text-gray-600 dark:text-gray-400 mt-6 max-w-2xl mx-auto">
              Have a project in mind? Let's talk about it. I'm always open to
              discussing new projects, creative ideas, or opportunities to be
              part of your vision.
            </p>
          </motion.div>

          <div className="flex justify-center">
            {/* Contact Form */}
            <motion.div variants={itemVariants} className="w-full max-w-2xl">
              <form onSubmit={handleSubmit} className="space-y-6">
                <div>
                  <label
                    htmlFor="name"
                    className="block text-sm font-medium text-slate-900 dark:text-white mb-2"
                  >
                    Name
                  </label>
                  <input
                    type="text"
                    id="name"
                    name="name"
                    value={formData.name}
                    onChange={handleChange}
                    required
                    className="w-full px-4 py-3 rounded-lg bg-white/60 dark:bg-slate-800/60 border border-gray-300 dark:border-slate-600 text-slate-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-400 focus:outline-none focus:border-purple-600 focus:ring-2 focus:ring-purple-600/20 transition-all duration-300"
                    placeholder="Your Name"
                  />
                </div>

                <div>
                  <label
                    htmlFor="email"
                    className="block text-sm font-medium text-slate-900 dark:text-white mb-2"
                  >
                    Email
                  </label>
                  <input
                    type="email"
                    id="email"
                    name="email"
                    value={formData.email}
                    onChange={handleChange}
                    required
                    className="w-full px-4 py-3 rounded-lg bg-white/60 dark:bg-slate-800/60 border border-gray-300 dark:border-slate-600 text-slate-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-400 focus:outline-none focus:border-purple-600 focus:ring-2 focus:ring-purple-600/20 transition-all duration-300"
                    placeholder="your@email.com"
                  />
                </div>

                <div>
                  <label
                    htmlFor="subject"
                    className="block text-sm font-medium text-slate-900 dark:text-white mb-2"
                  >
                    Subject
                  </label>
                  <input
                    type="text"
                    id="subject"
                    name="subject"
                    value={formData.subject}
                    onChange={handleChange}
                    required
                    className="w-full px-4 py-3 rounded-lg bg-white/60 dark:bg-slate-800/60 border border-gray-300 dark:border-slate-600 text-slate-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-400 focus:outline-none focus:border-purple-600 focus:ring-2 focus:ring-purple-600/20 transition-all duration-300"
                    placeholder="Project subject"
                  />
                </div>

                <div>
                  <label
                    htmlFor="message"
                    className="block text-sm font-medium text-slate-900 dark:text-white mb-2"
                  >
                    Message
                  </label>
                  <textarea
                    id="message"
                    name="message"
                    value={formData.message}
                    onChange={handleChange}
                    required
                    rows={5}
                    className="w-full px-4 py-3 rounded-lg bg-white/60 dark:bg-slate-800/60 border border-gray-300 dark:border-slate-600 text-slate-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-400 focus:outline-none focus:border-purple-600 focus:ring-2 focus:ring-purple-600/20 transition-all duration-300 resize-none"
                    placeholder="Your message here..."
                  />
                </div>

                <button
                  type="submit"
                  disabled={submitted}
                  className="w-full px-6 py-3 rounded-lg bg-linear-to-r from-purple-600 to-purple-700 dark:from-purple-500 dark:to-purple-600 text-white font-medium hover:from-purple-700 hover:to-purple-800 dark:hover:from-purple-600 dark:hover:to-purple-700 disabled:from-purple-500 disabled:to-purple-600 disabled:cursor-not-allowed transition-all duration-300 flex items-center justify-center gap-2 shadow-lg hover:shadow-purple-500/50 cursor-pointer"
                >
                  {submitted ? (
                    <>
                      <span>Message Sent!</span>
                    </>
                  ) : (
                    <>
                      <Send className="w-5 h-5" />
                      Send Message
                    </>
                  )}
                </button>
              </form>
            </motion.div>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
