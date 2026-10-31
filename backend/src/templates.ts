// Email bodies live on the server so clients cannot send arbitrary HTML from our domain.

export function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

const wrap = (inner: string) =>
  `<div style="font-family: sans-serif; padding: 20px; color: #333;">${inner}</div>`;

export function otpEmail(code: string) {
  return {
    subject: "Verify your email - Medhavn",
    html: wrap(`
      <h2>Welcome to Medhavn</h2>
      <p>Use this One-Time Password (OTP) to complete your registration:</p>
      <div style="font-size: 28px; font-weight: bold; color: #007AFF; letter-spacing: 4px; padding: 15px; background-color: #f2f2f7; border-radius: 8px; display: inline-block; margin: 15px 0;">${escapeHtml(code)}</div>
      <p>This code expires in 10 minutes. If you did not request it, ignore this email.</p>`),
  };
}

export function safeCircleInviteEmail(name: string) {
  return {
    subject: "Invitation to join SafeCircle on Medhavn",
    html: wrap(`
      <h2>You've been added to a SafeCircle care network</h2>
      <p>Hello ${escapeHtml(name)},</p>
      <p>You have been designated as a trusted contact in a Medhavn user's SafeCircle network.</p>
      <p>If they miss a scheduled dose of their medication, you may receive alert notifications to help keep them safe.</p>
      <p>Thank you for being part of their care network.</p>`),
  };
}

export function referralEmail(code?: string) {
  const codeLine = code
    ? `<p>Use referral code <strong>${escapeHtml(code)}</strong> when you sign up to get started!</p>`
    : "";
  return {
    subject: "You're invited to Medhavn!",
    html: wrap(`
      <h2>Get Started on Medhavn</h2>
      <p>Your friend has invited you to join Medhavn to track medications and manage your health.</p>
      ${codeLine}
      <p>Download Medhavn now and take control of your health journey.</p>`),
  };
}

export function missedDoseAlertEmail(patientName: string, doses: { itemName: string; block: string; date: string }[]) {
  const rows = doses
    .map((d) => `<li>${escapeHtml(d.itemName)} (${escapeHtml(d.block)}, ${escapeHtml(d.date)})</li>`)
    .join("");
  return {
    subject: `Missed dose alert for ${patientName}`,
    html: wrap(`
      <h2>Missed dose alert</h2>
      <p>${escapeHtml(patientName)} has not marked these doses as taken:</p>
      <ul>${rows}</ul>
      <p>Please check in with them. You received this because you are in their Medhavn SafeCircle.</p>`),
  };
}
