const need = (key: string): string => {
  const v = process.env[key]?.trim();
  if (!v) throw new Error(`Missing required env var ${key}`);
  return v;
};

export const config = {
  port: Number(process.env.PORT ?? 8080),
  supabaseUrl: need("SUPABASE_URL").replace(/\/+$/, ""),
  serviceKey: need("SUPABASE_SERVICE_ROLE_KEY"),
  jwtSecret: need("SUPABASE_JWT_SECRET"),
  smtp: {
    host: need("SMTP_HOST"),
    port: Number(process.env.SMTP_PORT ?? 465),
    user: need("SMTP_USER"),
    pass: need("SMTP_PASS"),
    from: process.env.MAIL_FROM?.trim() || need("SMTP_USER"),
  },
  openFdaKey: process.env.OPENFDA_API_KEY?.trim() ?? "",
  job: {
    enabled: (process.env.MISSED_DOSE_JOB_ENABLED ?? "true") !== "false",
    intervalMin: Number(process.env.MISSED_DOSE_JOB_INTERVAL_MIN ?? 10),
  },
};
