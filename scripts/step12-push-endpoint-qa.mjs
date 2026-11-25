import assert from 'node:assert/strict';
import { validatedPushEndpoint } from '../supabase/functions/ff-push/push-endpoint.mjs';
const valid = [
  'https://fcm.googleapis.com/fcm/send/test',
  'https://android.googleapis.com/gcm/send/test',
  'https://updates.push.services.mozilla.com/wpush/v2/test',
  'https://web.push.apple.com/QAtest',
  'https://web.push.apple.com:443/QAtest',
  'https://wns2-example.notify.windows.com/?token=test'
];
const invalid = [null, 12, '', 'http://fcm.googleapis.com/test',
  'https://example.invalid/test', 'https://127.0.0.1/test', 'https://[::1]/test',
  'https://fcm.googleapis.com.example.invalid/test', 'https://fakepush.apple.com/test',
  'https://evilnotify.windows.com/test', 'https://evilpush.services.mozilla.com/test',
  'https://example.invalid@fcm.googleapis.com/test', 'https://fcm.googleapis.com@other.invalid/test',
  'https://fcm.googleapis.com:8443/test', 'https://fcm.googleapis.com/test#fragment',
  'https://fcm.googleapis.com\\@other.invalid/test', 'https://fcm.googleapis.com/test\n',
  'https://fcm.googleapis.com./test', 'https://fcm.googleapis.com/'+'x'.repeat(2048)];
for (const v of valid) assert.equal(validatedPushEndpoint(v), new URL(v).href, v);
for (const v of invalid) assert.equal(validatedPushEndpoint(v), null, String(v));
console.log("PASS STEP12 push endpoint boundary: "+valid.length+" valid browser endpoints; "+invalid.length+" unsafe/invalid inputs rejected; no outbound traffic");
