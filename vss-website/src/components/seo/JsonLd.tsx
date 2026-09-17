import React from 'react';
import { VSS_CREATOR, VSS_VERSIONS } from '@/lib/vss-data';

export function JsonLd() {
  const latestVersion = VSS_VERSIONS[0];

  const personSchema = {
    '@context': 'https://schema.org',
    '@type': 'Person',
    name: VSS_CREATOR.name,
    alternateName: VSS_CREATOR.handle,
    jobTitle: VSS_CREATOR.role,
    description: VSS_CREATOR.bio,
    url: 'https://vss-lang.org/creator',
    sameAs: [
      VSS_CREATOR.githubUrl,
      VSS_CREATOR.linkedinUrl,
      VSS_CREATOR.vscodeExtUrl,
    ],
  };

  const softwareSchema = {
    '@context': 'https://schema.org',
    '@type': 'SoftwareApplication',
    name: 'VSS Programming Language',
    alternateName: 'Very Simple Syntax',
    softwareVersion: latestVersion.version,
    applicationCategory: 'DeveloperApplication',
    operatingSystem: 'Windows, Linux, macOS',
    author: {
      '@type': 'Person',
      name: VSS_CREATOR.name,
      url: 'https://vss-lang.org/creator',
    },
    description: 'Lightweight, readable, general-purpose programming language compiled in pure C with ARC memory management and native OS worker-thread concurrency.',
    url: 'https://vss-lang.org',
    downloadUrl: 'https://vss-lang.org/install',
    license: 'https://opensource.org/licenses/MIT',
  };

  const websiteSchema = {
    '@context': 'https://schema.org',
    '@type': 'WebSite',
    name: 'VSS Programming Language',
    url: 'https://vss-lang.org',
    description: 'Official documentation and website platform for VSS Programming Language created by Vooka Sai Siddharth.',
    publisher: {
      '@type': 'Person',
      name: VSS_CREATOR.name,
    },
  };

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(personSchema) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(softwareSchema) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(websiteSchema) }}
      />
    </>
  );
}
