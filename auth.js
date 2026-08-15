/* ============================================================================
   CLUBVMK curator — access gate
   ----------------------------------------------------------------------------
   The curator writes straight to Supabase with the publishable key. That key is
   public by design (it ships in the portal too), so the database — not this
   page — is what actually decides who may write: see supabase-lockdown.sql,
   where every write policy calls is_curator() against the Discord id on the
   verified JWT.

   This file is the other half of that. It signs you in so your writes carry
   that JWT, and it hides the editing UI from anyone who isn't a curator. Treat
   the hiding as a courtesy, not a control: someone can always open the console.
   The policies are the control, and they hold with or without this file.

   ADMIN_IDS below must match the id list inside is_curator(). Changing it here
   alone only changes who sees the buttons; changing it there alone locks a
   curator out of a UI they can still see.

   Load order on every page that talks to Supabase:
     supabase-js  ->  config.js  ->  auth.js  ->  the page's own script

   Pages call window.curatorClient() instead of creating their own client. One
   client per page matters: after the Discord redirect the URL carries a
   single-use PKCE code, and two clients racing to exchange it means one of
   them loses.
   ========================================================================== */
(function () {
  "use strict";

  // Keep in step with is_curator() in supabase-lockdown.sql.
  const ADMIN_IDS = ["886570059974201405"];

  let client = null;

  /** The one Supabase client for this page, created on first use. */
  window.curatorClient = function curatorClient() {
    if (!client) {
      client = window.supabase.createClient(window.SUPABASE_URL, window.SUPABASE_ANON_KEY);
    }
    return client;
  };

  /** The Discord id off the verified session, whichever shape it arrives in. */
  function discordIdFromSession(session) {
    const u = session && session.user;
    if (!u) return null;
    const meta = u.user_metadata || {};
    const ident = (u.identities || []).find((i) => i.provider === "discord") || {};
    return meta.provider_id || meta.sub || ident.id
      || (ident.identity_data && ident.identity_data.provider_id) || null;
  }

  function el(tag, style, text) {
    const node = document.createElement(tag);
    if (style) node.setAttribute("style", style);
    if (text) node.textContent = text;
    return node;
  }

  /* ---------- the gate ---------- */

  const overlay = el("div",
    "position:fixed;inset:0;z-index:99999;display:none;align-items:center;"
    + "justify-content:center;background:#11131a;color:#e7e9ee;"
    + "font:15px/1.5 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;text-align:center;padding:24px");

  const card = el("div", "max-width:420px");
  const title = el("h1", "margin:0 0 10px;font-size:22px", "CLUBVMK curator");
  const msg = el("p", "margin:0 0 18px;color:#9aa1ad");
  const button = el("button",
    "background:#5865f2;color:#fff;border:0;border-radius:8px;padding:11px 20px;"
    + "font-size:15px;font-weight:600;cursor:pointer");
  const secondary = el("button",
    "display:none;margin-top:12px;background:none;color:#9aa1ad;border:0;"
    + "text-decoration:underline;cursor:pointer;font-size:13px");

  card.append(title, msg, button, secondary);
  overlay.append(card);

  // A small "signed in as …" chip, so it is obvious which account is writing.
  const chip = el("div",
    "position:fixed;right:10px;bottom:10px;z-index:9998;display:none;gap:8px;"
    + "align-items:center;background:#1b1e27;color:#9aa1ad;border:1px solid #2a2f3a;"
    + "border-radius:999px;padding:6px 12px;font:12px system-ui,sans-serif");
  const chipText = el("span");
  const chipOut = el("button",
    "background:none;border:0;color:#7d8694;text-decoration:underline;cursor:pointer;font:12px system-ui,sans-serif");
  chipOut.textContent = "sign out";
  chip.append(chipText, chipOut);

  function mount() {
    if (!document.body) return;
    if (!overlay.isConnected) document.body.append(overlay, chip);
  }

  function show(message, action, actionLabel, showSignOut) {
    mount();
    msg.textContent = message;
    button.textContent = actionLabel;
    button.onclick = action;
    secondary.style.display = showSignOut ? "" : "none";
    overlay.style.display = "flex";
    chip.style.display = "none";
  }

  function pass(id) {
    mount();
    overlay.style.display = "none";
    chipText.textContent = "curating as " + id;
    chip.style.display = "flex";
  }

  async function signIn() {
    // redirectTo must be listed under Authentication -> URL Configuration
    // -> Redirect URLs in the Supabase dashboard, or Discord bounces back here
    // without a session and nothing appears to happen.
    const sb = window.curatorClient();
    const { error } = await sb.auth.signInWithOAuth({
      provider: "discord",
      options: { redirectTo: window.location.href.split("#")[0].split("?")[0] },
    });
    if (error) show("Could not start Discord sign-in: " + error.message, signIn, "Try again", false);
  }

  async function signOut() {
    await window.curatorClient().auth.signOut();
    render(null);
  }

  button.onclick = signIn;
  secondary.onclick = signOut;
  secondary.textContent = "sign out";
  chipOut.onclick = signOut;

  function render(session) {
    const id = discordIdFromSession(session);
    if (!session) {
      show("Sign in with Discord to curate. Rarities, art and names all feed the live bot.",
        signIn, "Sign in with Discord", false);
      return;
    }
    if (!ADMIN_IDS.includes(String(id))) {
      show("That account (" + (id || "unknown") + ") isn't a curator, so its edits would be "
        + "rejected by the database anyway.", signIn, "Sign in with another account", true);
      return;
    }
    pass(id);
  }

  async function start() {
    mount();
    // Held up front rather than after the session check: a page that paints its
    // editing UI for a beat before the gate lands looks like it is open.
    overlay.style.display = "flex";
    msg.textContent = "Checking your access…";
    button.textContent = "Sign in with Discord";

    if (!window.SUPABASE_URL || !window.SUPABASE_ANON_KEY) {
      show("Supabase isn't configured in config.js, so there is nothing to sign in to.",
        function () { location.reload(); }, "Reload", false);
      return;
    }

    const sb = window.curatorClient();
    const { data } = await sb.auth.getSession();
    render(data ? data.session : null);
    sb.auth.onAuthStateChange(function (_event, session) { render(session); });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start);
  } else {
    start();
  }
})();
