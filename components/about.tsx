"use client";

import { useState, useEffect } from "react";
import SectionHeading from "./section-heading";
import LoadingSpinner from "./loading-spinner";
import { motion } from "framer-motion";
import { Profile } from "@/types/Profile";
import { getProfile } from "@/sanity/sanity-utils";
import { PortableText } from "@portabletext/react";

export default function About() {
  const [profile, setProfile] = useState<Profile | null>(null);

  useEffect(() => {
    fetchProfile();
  }, []);

  const fetchProfile = async () => {
    try {
      const data = await getProfile("lucas");
      setProfile(data);
    } catch (error) {
      console.error("Error fetching profile:", error);
    }
  };

  return (
    <div>
      {profile ? (
        <motion.section
          className="mb-28 max-w-[45rem] text-center leading-8 sm:mb-40"
          initial={{ opacity: 0, y: 100 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.175 }}
        >
          <SectionHeading>About me</SectionHeading>
          <p className="mb-3">
            <PortableText value={profile.about} />
          </p>
        </motion.section>
      ) : (
        <LoadingSpinner />
      )}
    </div>
  );
}