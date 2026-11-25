// Browser push services only; never forward a client-controlled URL to a generic host.
export function validatedPushEndpoint(value) {
  if (typeof value !== 'string' || value.length > 2048 || !value.startsWith('https://') || /[\s\\\u0000-\u001f\u007f]/u.test(value)) return null;
  let url;
  try { url = new URL(value); } catch { return null; }
  if (url.protocol !== 'https:' || url.username || url.password || url.port || url.hash) return null;
  const host = url.hostname;
  const trusted = host === 'fcm.googleapis.com' || host === 'android.googleapis.com' ||
    host.endsWith('.push.services.mozilla.com') || host.endsWith('.push.apple.com') ||
    host.endsWith('.notify.windows.com');
  return trusted ? url.href : null;
}
