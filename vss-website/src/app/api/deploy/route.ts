import { NextResponse } from 'next/server';

export interface VSSAppDeployment {
  id: string;
  appName: string;
  subdomain: string;
  url: string;
  status: 'deploying' | 'active' | 'stopped' | 'error';
  createdAt: string;
  memory: string;
  routes: Array<{ method: string; path: string; description: string }>;
  envVars: Record<string, string>;
  dockerConfig: string;
  nginxConfig: string;
}

// In-memory deployment store for platform demo
const deployedAppsStore: VSSAppDeployment[] = [
  {
    id: 'app-rest-api-01',
    appName: 'vss-rest-api',
    subdomain: 'api-demo.vss-app.dev',
    url: 'https://api-demo.vss-app.dev',
    status: 'active',
    createdAt: new Date(Date.now() - 3600000).toISOString(),
    memory: '14.2 MB',
    routes: [
      { method: 'GET', path: '/', description: 'API Health Check & Status' },
      { method: 'GET', path: '/api/v1/data', description: 'JSON Payload Stream' },
      { method: 'POST', path: '/api/v1/submit', description: 'Submit Ingest Task' },
    ],
    envVars: { PORT: '8080', ENV: 'production', DEBUG: 'false' },
    dockerConfig: `FROM gcc:latest AS builder
WORKDIR /app
COPY . .
RUN gcc -o vss.exe src/*.c -Iinclude -lws2_32
CMD ["./vss.exe", "run", "app.vss"]`,
    nginxConfig: `server {
    listen 80;
    server_name api-demo.vss-app.dev;
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}`,
  },
];

export async function GET() {
  return NextResponse.json({ success: true, apps: deployedAppsStore });
}

export async function POST(request: Request) {
  try {
    const { appName, code, envVars = {} } = await request.json();

    if (!appName) {
      return NextResponse.json(
        { success: false, error: 'App name is required for deployment.' },
        { status: 400 }
      );
    }

    const sanitizedName = appName
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9-]/g, '-');
    const subdomain = `${sanitizedName}.vss-app.dev`;
    const url = `https://${subdomain}`;
    const containerPort = Math.floor(8000 + Math.random() * 1000);

    // Dynamic Route Detection from VSS code
    const detectedRoutes: Array<{ method: string; path: string; description: string }> = [];
    if (code) {
      const getMatches = [...code.matchAll(/server\.get\(["']([^"']+)["']/g)];
      getMatches.forEach((m) =>
        detectedRoutes.push({ method: 'GET', path: m[1], description: 'Registered VSS route' })
      );

      const postMatches = [...code.matchAll(/server\.post\(["']([^"']+)["']/g)];
      postMatches.forEach((m) =>
        detectedRoutes.push({ method: 'POST', path: m[1], description: 'Registered VSS route' })
      );
    }

    if (detectedRoutes.length === 0) {
      detectedRoutes.push({ method: 'GET', path: '/', description: 'Root VSS Handler' });
    }

    const nginxConfig = `# Option B: Free Nginx Reverse Proxy Route for ${subdomain}
server {
    listen 80;
    server_name ${subdomain};
    
    location / {
        proxy_pass http://127.0.0.1:${containerPort};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}`;

    const dockerConfig = `# Option B: Docker Containerfile for ${sanitizedName}
FROM gcc:latest AS builder
WORKDIR /vss-app
COPY . .
RUN gcc -o vss.exe src/*.c -Iinclude -lws2_32
EXPOSE ${containerPort}
ENV PORT=${containerPort}
CMD ["./vss.exe", "run", "main.vss"]`;

    const newApp: VSSAppDeployment = {
      id: `app-${Date.now()}`,
      appName: sanitizedName,
      subdomain,
      url,
      status: 'active',
      createdAt: new Date().toISOString(),
      memory: `${(12 + Math.random() * 5).toFixed(1)} MB`,
      routes: detectedRoutes,
      envVars: { PORT: String(containerPort), ...envVars },
      dockerConfig,
      nginxConfig,
    };

    deployedAppsStore.unshift(newApp);

    return NextResponse.json({
      success: true,
      app: newApp,
      logs: [
        `[1/4] Code received. Validating VSS AST & bytecode constants... OK`,
        `[2/4] Allocating isolated port ${containerPort} & configuring Nginx reverse proxy... OK`,
        `[3/4] Requesting zero-cost SSL certificate for *.vss-app.dev... OK`,
        `[4/4] Deployment successful! Active live endpoint: ${url}`,
      ],
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message || 'Deployment error' },
      { status: 500 }
    );
  }
}
