export interface ServiceConfig {
  name: string;
  envPrefix: string;
  defaultUrl: string;
}

export const SERVICES: Record<string, ServiceConfig> = {
  navidrome: {
    name: 'Navidrome',
    envPrefix: 'NAVIDROME',
    defaultUrl: 'https://navidrome.bobtail-clownfish.ts.net',
  },
  grafana: {
    name: 'Grafana',
    envPrefix: 'GRAFANA',
    defaultUrl: 'http://admin:3000',
  },
  jellyfin: {
    name: 'Jellyfin',
    envPrefix: 'JELLYFIN',
    defaultUrl: 'https://jellyfin.bobtail-clownfish.ts.net',
  },
};

export function getServiceConfig(serviceKey: string) {
  const svc = SERVICES[serviceKey];
  if (!svc) throw new Error(`Unknown service: ${serviceKey}`);

  const url = process.env[`${svc.envPrefix}_URL`] || svc.defaultUrl;
  const username = process.env[`${svc.envPrefix}_USERNAME`];
  const password = process.env[`${svc.envPrefix}_PASSWORD`];

  if (!username || !password) {
    throw new Error(
      `${svc.envPrefix}_USERNAME and ${svc.envPrefix}_PASSWORD must be set`
    );
  }

  return { ...svc, url, username, password };
}
