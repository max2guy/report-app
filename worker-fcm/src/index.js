/**
 * Cloudflare Worker: /fcm-send, /report-notification
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

    if (request.method !== "POST") {
      return json({ ok: false, error: "method_not_allowed" }, 405);
    }

    try {
      requireProxyToken(request, env);
      const url = new URL(request.url);
      const payload = await request.json();

      if (url.pathname === "/report-notification") {
        return handleReportNotification(payload, env);
      }

      if (url.pathname !== "/fcm-send") {
        return json({ ok: false, error: "not_found" }, 404);
      }

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

      const sa = parseServiceAccount(env.GOOGLE_SERVICE_ACCOUNT_JSON);
      const accessToken = await getGoogleAccessToken(sa, [
        "https://www.googleapis.com/auth/firebase.database",
        "https://www.googleapis.com/auth/firebase.messaging",
        "https://www.googleapis.com/auth/userinfo.email",
      ]);

      const token = await loadTargetToken(env, targetRole, accessToken);
      if (!token) {
        return json(
          { ok: false, error: "token_not_found", message: `No token for role ${targetRole}` },
          404
        );
      }

      const fcmResult = await sendFcmMessage({
        sa,
        accessToken,
        token,
        title,
        body,
        tag,
        targetUrl,
      });
      if (!fcmResult.ok) {
        return json(
          {
            ok: false,
            error: "fcm_send_failed",
            status: fcmResult.status,
            details: fcmResult.details,
          },
          502
        );
      }

      return json({ ok: true, targetRole, result: fcmResult.details }, 200);
    } catch (err) {
      if (err?.message === "unauthorized" || err?.status === 401) {
        return json({ ok: false, error: "unauthorized" }, 401);
      }
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

function requireProxyToken(request, env) {
  const provided = request.headers.get("X-Push-Token") || "";
  if (!provided || provided !== (env.PUSH_PROXY_TOKEN || "")) {
    const err = new Error("unauthorized");
    err.status = 401;
    throw err;
  }
}

async function handleReportNotification(payload, env) {
  const {
    notification,
    targetRole = "viewerApp",
    title = "📄 새 보고서 도착",
    body = "",
    tag = "church-viewer",
    url: targetUrl = "./viewer.html",
  } = payload || {};

  if (!notification?.id || !notification?.title) {
    return json(
      { ok: false, error: "invalid_request", message: "notification.id/title required" },
      400
    );
  }

  const sa = parseServiceAccount(env.GOOGLE_SERVICE_ACCOUNT_JSON);
  const accessToken = await getGoogleAccessToken(sa, [
    "https://www.googleapis.com/auth/firebase.database",
    "https://www.googleapis.com/auth/firebase.messaging",
    "https://www.googleapis.com/auth/userinfo.email",
  ]);

  const savedNotification = await writeNotification(env, notification, accessToken);
  const token = await loadTargetToken(env, targetRole, accessToken);
  if (!token) {
    return json({
      ok: true,
      notification: savedNotification,
      push: { ok: false, error: "token_not_found", targetRole },
    });
  }

  const fcmResult = await sendFcmMessage({
    sa,
    accessToken,
    token,
    title,
    body,
    tag,
    targetUrl,
  });

  return json({
    ok: true,
    notification: savedNotification,
    push: fcmResult.ok
      ? { ok: true, result: fcmResult.details }
      : { ok: false, status: fcmResult.status, details: fcmResult.details },
  });
}

async function writeNotification(env, notification, accessToken) {
  if (!env.FIREBASE_RTDB_URL) {
    throw new Error("Missing FIREBASE_RTDB_URL secret");
  }
  const base = env.FIREBASE_RTDB_URL.replace(/\/+$/, "");
  const auth = authQuery(env, accessToken);
  const res = await fetch(`${base}/notifications.json${auth}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(notification),
  });
  const details = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(`RTDB notification write failed: ${res.status}`);
  }
  return { key: details.name || "", item: notification };
}

async function loadTargetToken(env, targetRole, accessToken = "") {
  if (!env.FIREBASE_RTDB_URL) {
    throw new Error("Missing FIREBASE_RTDB_URL secret");
  }
  const base = env.FIREBASE_RTDB_URL.replace(/\/+$/, "");
  const auth = authQuery(env, accessToken);
  const res = await fetch(`${base}/fcm-tokens/${encodeURIComponent(targetRole)}.json${auth}`);
  if (!res.ok) {
    throw new Error(`RTDB fetch failed: ${res.status}`);
  }
  const value = await res.json();
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function authQuery(env, accessToken = "") {
  if (env.FIREBASE_RTDB_AUTH) {
    return `?auth=${encodeURIComponent(env.FIREBASE_RTDB_AUTH)}`;
  }
  return accessToken ? `?access_token=${encodeURIComponent(accessToken)}` : "";
}

async function sendFcmMessage({ sa, accessToken, token, title, body, tag, targetUrl }) {
  const fcmRes = await fetch(
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
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

  const details = await fcmRes.json().catch(() => ({}));
  return { ok: fcmRes.ok, status: fcmRes.status, details };
}

function parseServiceAccount(raw) {
  if (!raw) throw new Error("Missing GOOGLE_SERVICE_ACCOUNT_JSON secret");
  const parsed = JSON.parse(raw);
  if (!parsed.client_email || !parsed.private_key || !parsed.project_id) {
    throw new Error("Invalid service account JSON");
  }
  return parsed;
}

async function getGoogleAccessToken(sa, scopes = ["https://www.googleapis.com/auth/firebase.messaging"]) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = base64UrlEncode(
    JSON.stringify({
      iss: sa.client_email,
      scope: scopes.join(" "),
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
  const responseStatus = payload?.error === "unauthorized" ? 401 : status;
  return new Response(JSON.stringify(payload, null, 2), {
    status: responseStatus,
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
