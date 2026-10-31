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

export function referralEmail(opts: { inviterName: string; code: string; appStoreUrl: string; family: boolean }) {
  const who = escapeHtml(opts.inviterName);
  const intro = opts.family
    ? `${who} invited you to Medhavn so you can stay connected and look out for each other's health.`
    : `${who} invited you to join Medhavn to track medications and manage your health.`;
  const button = opts.appStoreUrl
    ? `<p><a href="${escapeHtml(opts.appStoreUrl)}" style="display:inline-block;background:#007AFF;color:#fff;padding:12px 20px;border-radius:8px;text-decoration:none;font-weight:bold;">Download Medhavn</a></p>`
    : "";
  return {
    subject: `${opts.inviterName} invited you to Medhavn`,
    html: wrap(`
      <h2>You're invited to Medhavn</h2>
      <p>${intro}</p>
      ${button}
      <p>Sign up with this email address and we will connect you automatically. Or enter this referral code during sign-up:</p>
      <div style="font-size: 22px; font-weight: bold; letter-spacing: 3px; padding: 12px; background-color: #f2f2f7; border-radius: 8px; display: inline-block;">${escapeHtml(opts.code)}</div>`),
  };
}

/** Short account notice. Names only, never health details. */
export function noticeEmail(heading: string, lines: string[]) {
  return {
    subject: heading,
    html: wrap(`<h2>${escapeHtml(heading)}</h2>${lines.map((l) => `<p>${escapeHtml(l)}</p>`).join("")}<p>Open Medhavn to respond.</p>`),
  };
}

/** `doses` is only passed for recipients who were granted the medications scope. Everyone else gets a neutral message. */
export function missedDoseAlertEmail(patientName: string, count: number, doses?: { itemName: string; block: string; date: string }[]) {
  const detail = doses
    ? `<ul>${doses.map((d) => `<li>${escapeHtml(d.itemName)} (${escapeHtml(d.block)}, ${escapeHtml(d.date)})</li>`).join("")}</ul>`
    : "";
  return {
    subject: `Missed dose alert for ${patientName}`,
    html: wrap(`
      <h2>Missed dose alert</h2>
      <p>${escapeHtml(patientName)} missed ${count === 1 ? "a scheduled dose" : `${count} scheduled doses`}. Please check in with them.</p>
      ${detail}
      <p>You received this because ${escapeHtml(patientName)} chose to share missed-dose alerts with you.</p>`),
  };
}
