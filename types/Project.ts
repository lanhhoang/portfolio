import { PortableTextBlock } from "sanity";

export type Project = {
  _id: string;
  _createdAt: Date;
  name: string;
  slug: string;
  image: string;
  alt: string;
  url: string;
  description: PortableTextBlock[];
  tags: string[];
};
