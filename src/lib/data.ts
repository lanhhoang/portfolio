import {
  SiReact,
  SiTypescript,
  SiTailwindcss,
  SiNodedotjs,
  SiPostgresql,
  SiGraphql,
  SiDocker,
  SiAmazonwebservices,
  SiFramer,
  SiGit,
  SiRubyonrails,
  SiPython,
  SiGo,
  SiRuby,
  SiFastapi,
  SiJavascript,
  SiLeetcode,
} from "react-icons/si";
import { FiGithub, FiLinkedin } from "react-icons/fi";

export const links = [
  {
    name: "Home",
    hash: "#home",
  },
  {
    name: "About",
    hash: "#about",
  },
  {
    name: "Skills",
    hash: "#skills",
  },
  {
    name: "Projects",
    hash: "#projects",
  },
  {
    name: "Experience",
    hash: "#experience",
  },
  {
    name: "Contact",
    hash: "#contact",
  },
] as const;

export const skills = [
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
] as const;

export const projects = [
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
] as const;

export const experiences = [
  {
    title: "Software Engineer",
    company: "Centennial Innovates",
    period: "2024 - Present",
    description:
      "Leading development of mental health platform for Canada market",
    highlights: [
      "Engineered an asynchronous job processing system using Redis and Sidekiq, moving heavy computations to background workers and improving application response time by 20%",
      "Designed secure payment and notification services integrating Stripe and SendGrid, ensuring PCI compliance and reliable email delivery",
      "Optimized the CI/CD pipeline via GitHub Actions, reducing build and deployment times by 25% through caching strategies",
    ],
  },
  {
    title: "Software Engineer",
    company: "Remitano",
    period: "2020 - 2021",
    description: "Developed and maintained Remitano P2P exchange platform",
    highlights: [
      "Integrated third-party APIs to automate trading across 6 external exchanges, directly contributing to a 10X increase in monthly trading volume",
      "Led a major infrastructure upgrade, migrating the core monolith from Ruby on Rails 5 to 6. Refactored legacy modules to adhere to modern standards, reducing technical debt",
      "Engineered distributed services in Python and Rails to provide alternative verification methods, reducing user wait times by 50%",
    ],
  },
  {
    title: "Software Engineer",
    company: "LOGIVAN",
    period: "2019 - 2020",
    description:
      "Developed and maintained LOGIVAN platform to connect shippers with truck drivers",
    highlights: [
      "Developed a custom truck-matching algorithm, factoring in load capacity, route constraints, and truck type to automate the dispatch process and tripled daily order fulfillment",
      "Analyzed query execution plans, added composite indexes, optimized PostgreSQL database performance for a dataset of 30k + active pricing records to reduce quote generation time by 20%",
      "Architected a constraints - based API for order creation, abstracting complex logic away from the frontend and reducing order flow complexity by 25%",
    ],
  },
  {
    title: "Software Engineer",
    company: "TINYpulse",
    period: "2017 - 2019",
    description:
      "Developed and maintained TINYpulse platform to improve employee engagement",
    highlights: [
      "Integrated Slack API for real-time survey participation, reducing average user response time by 75% for 50k+ monthly users",
      "Refactored React frontend components, implementing efficient data fetching patterns that decreased page load times by 60%",
      "Built a high-volume data ingestion tool for CSV organization imports, reducing manual customer onboarding time",
    ],
  },
] as const;

export const socialLinks = [
  { icon: FiGithub, href: "https://github.com/lanhhoang", label: "GitHub" },
  { icon: FiLinkedin, href: "https://linkedin.com/in/lanh", label: "LinkedIn" },
  {
    icon: SiLeetcode,
    href: "https://leetcode.com/lanhhoang",
    label: "LeetCode",
  },
] as const;
