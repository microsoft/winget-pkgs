import { MetadataRoute } from 'next';

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl = 'https://vss-lang.org';

  const routes = [
    '',
    '/about',
    '/creator',
    '/getting-started',
    '/install',
    '/docs',
    '/docs/v3-1',
  ];

  return routes.map((route) => ({
    url: `${baseUrl}${route}`,
    lastModified: new Date(),
    changeFrequency: 'weekly',
    priority: route === '' ? 1.0 : route.startsWith('/docs') || route === '/creator' ? 0.9 : 0.8,
  }));
}
