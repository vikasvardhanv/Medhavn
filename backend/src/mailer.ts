import nodemailer from "nodemailer";
import { config } from "./config.js";

const { from, resendKey, smtp } = config.mail;

const transporter = smtp
  ? nodemailer.createTransport({
      host: smtp.host,
      port: smtp.port,
      secure: smtp.port === 465,
      requireTLS: smtp.port !== 465, // 587 and similar: refuse to send credentials without STARTTLS
      auth: { user: smtp.user, pass: smtp.pass },
      pool: true,
      connectionTimeout: 10_000,
      socketTimeout: 20_000,
    })
  : null;

export async function sendMail(to: string, mail: { subject: string; html: string }): Promise<void> {
  if (resendKey) {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${resendKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from, to, subject: mail.subject, html: mail.html }),
      signal: AbortSignal.timeout(15_000),
    });
    if (!res.ok) throw new Error(`Resend ${res.status}: ${(await res.text()).slice(0, 200)}`);
    return;
  }
  await transporter!.sendMail({ from, to, subject: mail.subject, html: mail.html });
}
