/**
 * Cloudflare Worker: /fcm-send
 *
 * Required secrets:
 * - PUSH_PROXY_TOKEN
 * - GOOGLE_SERVICE_ACCOUNT_JSON (raw JSON string for service account)
 * - FIREBASE_RTDB_URL (e.g. https://<project>-default-rtdb.asia-southeast1.firebasedatabase.app)
 *
 * Optional secret:
 * - FIREBASE_RTDB_AUTH (database secret or custom token if rules require auth)
 */

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    const url = new URL(request.url);
    if (url.pathname !== "/fcm-send") {
      return json({ ok: false, error: "not_found" }, 404);
    }

    if (request.method !== "POST") {
      return json({ ok: false, error: "method_not_allowed" }, 405);
    }

    try {
      const provided = request.headers.get("X-Push-Token") || "";
      if (!provided || provided !== (env.PUSH_PROXY_TOKEN || "")) {
        return json({ ok: false, error: "unauthorized" }, 401);
      }

      const payload = await request.json();
      const {
        targetRole,
        title,
        body = "",
        tag = "church-report",
        url: targetUrl = "./",
      } = payload || {};

      if (!targetRole || !title) {
        return json(
          { ok: false, error: "invalid_request", message: "targetRole/title required" },
          400
        );
      }

      const token = await loadTargetToken(env, targetRole);
      if (!token) {
        return json(
          { ok: false, error: "token_not_found", message: `No token for role ${targetRole}` },
          404
        );
      }

      const sa = parseServiceAccount(env.GOOGLE_SERVICE_ACCOUNT_JSON);
      const accessToken = await getGoogleAccessToken(sa);
      const projectId = sa.project_id;

      const fcmRes = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token,
              data: {
                title: String(title),
                body: String(body),
                tag: String(tag),
                url: String(targetUrl),
              },
              webpush: {
                headers: { TTL: "86400" },
              },
            },
          }),
        }
      );

      const fcmJson = await fcmRes.json().catch(() => ({}));
      if (!fcmRes.ok) {
        return json(
          {
            ok: false,
            error: "fcm_send_failed",
            status: fcmRes.status,
            details: fcmJson,
          },
          502
        );
      }

      return json({ ok: true, targetRole, result: fcmJson }, 200);
    } catch (err) {
      return json(
        {
          ok: false,
          error: "internal_error",
          message: err instanceof Error ? err.message : String(err),
        },
        500
      );
    }
  },
};

async function loadTargetToken(env, targetRole) {
  if (!env.FIREBASE_RTDB_URL) {
    throw new Error("Missing FIREBASE_RTDB_URL secret");
  }
  const base = env.FIREBASE_RTDB_URL.replace(/\/+$/, "");
  const auth = env.FIREBASE_RTDB_AUTH
    ? `?auth=${encodeURIComponent(env.FIREBASE_RTDB_AUTH)}`
    : "";
  const res = await fetch(`${base}/fcm-tokens/${encodeURIComponent(targetRole)}.json${auth}`);
  if (!res.ok) {
    throw new Error(`RTDB fetch failed: ${res.status}`);
  }
  const value = await res.json();
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function parseServiceAccount(raw) {
  if (!raw) throw new Error("Missing GOOGLE_SERVICE_ACCOUNT_JSON secret");
  const parsed = JSON.parse(raw);
  if (!parsed.client_email || !parsed.private_key || !parsed.project_id) {
    throw new Error("Invalid service account JSON");
  }
  return parsed;
}

async function getGoogleAccessToken(sa) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = base64UrlEncode(
    JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      exp: now + 3600,
      iat: now,
    })
  );
  const signingInput = `${header}.${claim}`;
  const signature = await signJwtRS256(signingInput, sa.private_key);
  const jwt = `${signingInput}.${signature}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const tokenJson = await tokenRes.json().catch(() => ({}));
  if (!tokenRes.ok || !tokenJson.access_token) {
    throw new Error(`OAuth token exchange failed: ${tokenRes.status}`);
  }
  return tokenJson.access_token;
}

async function signJwtRS256(input, pem) {
  const keyData = pemToArrayBuffer(pem);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(input)
  );
  return base64UrlFromBytes(new Uint8Array(sig));
}

function pemToArrayBuffer(pem) {
  const b64 = pem.replace(/-----[A-Z ]+-----/g, "").replace(/\s+/g, "");
  const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  return bytes.buffer;
}

function base64UrlEncode(str) {
  const bytes = new TextEncoder().encode(str);
  return base64UrlFromBytes(bytes);
}

function base64UrlFromBytes(bytes) {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function json(payload, status = 200) {
  return new Response(JSON.stringify(payload, null, 2), {
    status,
    headers: {
      ...corsHeaders(),
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type, X-Push-Token",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}
