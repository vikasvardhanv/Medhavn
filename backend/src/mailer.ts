import nodemailer from "nodemailer";
import { config } from "./config.js";

const transporter = nodemailer.createTransport({
  host: config.smtp.host,
  port: config.smtp.port,
  secure: config.smtp.port === 465,
  requireTLS: config.smtp.port !== 465, // 587 and similar: refuse to send credentials without STARTTLS
  auth: { user: config.smtp.user, pass: config.smtp.pass },
  pool: true,
  connectionTimeout: 10_000,
  socketTimeout: 20_000,
});

export async function sendMail(to: string, mail: { subject: string; html: string }): Promise<void> {
  await transporter.sendMail({ from: config.smtp.from, to, subject: mail.subject, html: mail.html });
}
