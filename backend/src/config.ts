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
  // Mail goes through Resend when RESEND_API_KEY is set, otherwise through SMTP.
  mail: {
    from: need("MAIL_FROM"),
    resendKey: process.env.RESEND_API_KEY?.trim() ?? "",
    smtp: process.env.RESEND_API_KEY?.trim()
      ? null
      : {
          host: need("SMTP_HOST"),
          port: Number(process.env.SMTP_PORT ?? 465),
          user: need("SMTP_USER"),
          pass: need("SMTP_PASS"),
        },
  },
  // Public store link put in referral emails. Leave unset until the app has a store page.
  appStoreUrl: /^https:\/\//.test(process.env.APP_STORE_URL?.trim() ?? "") ? process.env.APP_STORE_URL!.trim() : "",
  openFdaKey: process.env.OPENFDA_API_KEY?.trim() ?? "",
  job: {
    enabled: (process.env.MISSED_DOSE_JOB_ENABLED ?? "true") !== "false",
    intervalMin: Number(process.env.MISSED_DOSE_JOB_INTERVAL_MIN ?? 10),
  },
};
