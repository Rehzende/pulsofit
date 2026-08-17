import { registerOTel } from '@vercel/otel';

export function register() {
  // We use registerOTel from @vercel/otel which is a convenient wrapper 
  // that works well in Next.js and Vercel environments.
  // It automatically picks up OTEL_EXPORTER_OTLP_ENDPOINT and OTEL_EXPORTER_OTLP_HEADERS.
  
  registerOTel({
    serviceName: 'pulso-frontend',
  });
}
