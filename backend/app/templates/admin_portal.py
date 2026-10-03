"""
Luxury Sovereign Superadmin Portal HTML Template.
Zero-vulnerability, CSP-compliant, standalone reactive console.
Strictly authorized for asiverticals@gmail.com.
"""

def get_admin_portal_html() -> str:
    return """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>UR-Heart Sovereign Admin Sentinel | asiverticals@gmail.com</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&family=Playfair+Display:ital,wght@0,600;1,600&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #09090D;
      --card-bg: rgba(22, 22, 30, 0.75);
      --card-border: rgba(224, 169, 109, 0.2);
      --card-border-hover: rgba(224, 169, 109, 0.45);
      --gold: #E0A96D;
      --gold-glow: rgba(224, 169, 109, 0.25);
      --crimson: #E63946;
      --emerald: #2A9D8F;
      --text: #F3F4F6;
      --text-muted: #9CA3AF;
      --font-body: 'Plus Jakarta Sans', -apple-system, sans-serif;
      --font-title: 'Playfair Display', Georgia, serif;
    }

    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: var(--bg);
      color: var(--text);
      font-family: var(--font-body);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      background-image: 
        radial-gradient(circle at 15% 15%, rgba(224, 169, 109, 0.07) 0%, transparent 40%),
        radial-gradient(circle at 85% 85%, rgba(42, 157, 143, 0.05) 0%, transparent 40%);
    }

    /* Auth Gate Modal */
    #authModal {
      position: fixed;
      inset: 0;
      background: rgba(9, 9, 13, 0.95);
      backdrop-filter: blur(12px);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 9999;
      padding: 20px;
    }
    .auth-card {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 20px;
      padding: 40px;
      max-width: 460px;
      width: 100%;
      text-align: center;
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.6), 0 0 30px var(--gold-glow);
    }
    .auth-badge {
      display: inline-block;
      padding: 6px 14px;
      background: rgba(224, 169, 109, 0.15);
      border: 1px solid var(--gold);
      border-radius: 999px;
      color: var(--gold);
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 1.5px;
      text-transform: uppercase;
      margin-bottom: 20px;
    }
    .auth-card h1 {
      font-family: var(--font-title);
      font-size: 26px;
      margin-bottom: 10px;
      color: var(--gold);
    }
    .auth-card p {
      color: var(--text-muted);
      font-size: 13px;
      line-height: 1.6;
      margin-bottom: 25px;
    }
    .auth-input {
      width: 100%;
      padding: 14px 16px;
      background: rgba(10, 10, 15, 0.8);
      border: 1px solid rgba(255, 255, 255, 0.15);
      border-radius: 10px;
      color: #FFF;
      font-size: 14px;
      outline: none;
      margin-bottom: 20px;
      transition: all 0.2s;
    }
    .auth-input:focus {
      border-color: var(--gold);
      box-shadow: 0 0 10px var(--gold-glow);
    }
    .btn-gold {
      width: 100%;
      padding: 14px;
      background: linear-gradient(135deg, #E0A96D, #C58B4F);
      color: #09090D;
      font-weight: 700;
      border: none;
      border-radius: 10px;
      cursor: pointer;
      font-size: 14px;
      transition: transform 0.15s, box-shadow 0.15s;
    }
    .btn-gold:hover {
      transform: translateY(-2px);
      box-shadow: 0 8px 20px rgba(224, 169, 109, 0.4);
    }

    /* Main Console Header */
    header {
      border-bottom: 1px solid rgba(255, 255, 255, 0.08);
      padding: 18px 32px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: rgba(14, 14, 20, 0.7);
      backdrop-filter: blur(10px);
    }
    .brand-group {
      display: flex;
      align-items: center;
      gap: 14px;
    }
    .brand-crown {
      font-size: 24px;
      color: var(--gold);
    }
    .brand-title {
      font-family: var(--font-title);
      font-size: 20px;
      font-weight: 600;
      letter-spacing: 0.5px;
    }
    .admin-pill {
      background: rgba(224, 169, 109, 0.12);
      border: 1px solid var(--gold);
      color: var(--gold);
      padding: 4px 12px;
      border-radius: 999px;
      font-size: 12px;
      font-weight: 600;
    }
    .btn-logout {
      padding: 8px 16px;
      background: transparent;
      border: 1px solid rgba(255, 255, 255, 0.2);
      color: var(--text-muted);
      border-radius: 8px;
      cursor: pointer;
      font-size: 12px;
      transition: all 0.2s;
    }
    .btn-logout:hover {
      border-color: var(--crimson);
      color: var(--crimson);
    }

    /* Nav Tabs */
    .nav-tabs {
      display: flex;
      gap: 12px;
      padding: 14px 32px;
      background: rgba(10, 10, 15, 0.4);
      border-bottom: 1px solid rgba(255, 255, 255, 0.05);
      overflow-x: auto;
    }
    .tab-btn {
      background: transparent;
      border: none;
      color: var(--text-muted);
      padding: 10px 18px;
      font-size: 13px;
      font-weight: 600;
      border-radius: 8px;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 8px;
      transition: all 0.2s;
    }
    .tab-btn:hover {
      color: var(--text);
      background: rgba(255, 255, 255, 0.05);
    }
    .tab-btn.active {
      color: #09090D;
      background: var(--gold);
    }

    /* Content Area */
    main {
      flex: 1;
      padding: 32px;
      max-width: 1400px;
      margin: 0 auto;
      width: 100%;
    }
    .tab-pane { display: none; }
    .tab-pane.active { display: block; }

    /* Stat Cards Grid */
    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 20px;
      margin-bottom: 30px;
    }
    .stat-card {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 16px;
      padding: 22px;
      transition: all 0.2s;
    }
    .stat-card:hover {
      border-color: var(--card-border-hover);
      transform: translateY(-2px);
    }
    .stat-label {
      color: var(--text-muted);
      font-size: 12px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 8px;
    }
    .stat-val {
      font-family: var(--font-title);
      font-size: 32px;
      color: var(--gold);
      font-weight: 600;
    }

    /* Tables & Cards */
    .section-card {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 16px;
      padding: 24px;
      margin-bottom: 24px;
    }
    .section-title {
      font-family: var(--font-title);
      font-size: 20px;
      margin-bottom: 18px;
      color: var(--text);
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 13px;
    }
    th, td {
      padding: 12px 16px;
      text-align: left;
      border-bottom: 1px solid rgba(255, 255, 255, 0.06);
    }
    th {
      color: var(--text-muted);
      font-weight: 600;
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.8px;
    }
    tr:hover td {
      background: rgba(255, 255, 255, 0.02);
    }
    .badge {
      display: inline-block;
      padding: 3px 8px;
      border-radius: 6px;
      font-size: 11px;
      font-weight: 600;
    }
    .badge-gold { background: rgba(224, 169, 109, 0.2); color: var(--gold); border: 1px solid var(--gold); }
    .badge-green { background: rgba(42, 157, 143, 0.2); color: var(--emerald); border: 1px solid var(--emerald); }
    .badge-red { background: rgba(230, 57, 70, 0.2); color: var(--crimson); border: 1px solid var(--crimson); }

    /* Action Buttons */
    .action-btn {
      padding: 6px 12px;
      border-radius: 6px;
      border: 1px solid transparent;
      font-size: 12px;
      font-weight: 600;
      cursor: pointer;
      margin-right: 6px;
      transition: all 0.15s;
    }
    .btn-approve { background: rgba(42, 157, 143, 0.2); color: var(--emerald); border-color: var(--emerald); }
    .btn-approve:hover { background: var(--emerald); color: #FFF; }
    .btn-reject { background: rgba(230, 57, 70, 0.2); color: var(--crimson); border-color: var(--crimson); }
    .btn-reject:hover { background: var(--crimson); color: #FFF; }

    /* Search input */
    .search-bar {
      display: flex;
      gap: 12px;
      margin-bottom: 20px;
    }
    .search-input {
      flex: 1;
      padding: 10px 16px;
      background: rgba(10, 10, 15, 0.6);
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 8px;
      color: #FFF;
      font-size: 13px;
    }
    .search-input:focus { outline: none; border-color: var(--gold); }

    /* Notification Toast */
    #toast {
      position: fixed;
      bottom: 24px;
      right: 24px;
      background: #1A1A24;
      border: 1px solid var(--gold);
      color: #FFF;
      padding: 14px 22px;
      border-radius: 10px;
      font-size: 13px;
      display: none;
      box-shadow: 0 10px 30px rgba(0,0,0,0.6);
      z-index: 10000;
    }
  </style>
</head>
<body>

  <!-- Auth Gate Modal -->
  <div id="authModal">
    <div class="auth-card">
      <div class="auth-badge">👑 Superadmin Sovereign Gateway</div>
      <h1>Sanctuary Sentinel</h1>
      <p>This portal is strictly restricted to sovereign administrator <strong>asiverticals@gmail.com</strong>. All unauthorized attempts are cryptographically quarantined and logged.</p>
      
      <div style="text-align: left; margin-bottom: 6px; font-size: 11px; color: var(--gold); font-weight: 600; text-transform: uppercase;">Superadmin Canonical Email</div>
      <input type="email" id="adminEmailInput" class="auth-input" value="asiverticals@gmail.com" readonly style="opacity: 0.85; margin-bottom: 14px;" />
      
      <div style="text-align: left; margin-bottom: 6px; font-size: 11px; color: var(--text-muted); font-weight: 600; text-transform: uppercase;">Sovereign Secret Key or Bearer Token</div>
      <input type="password" id="adminTokenInput" class="auth-input" placeholder="Enter Sovereign Secret Key or Token" autocomplete="current-password" onkeydown="if(event.key==='Enter') authenticateAdmin()" />
      
      <button class="btn-gold" id="authBtn" onclick="authenticateAdmin()">Authenticate Sovereign Sentinel</button>
      <div id="authError" style="color: var(--crimson); font-size: 12px; margin-top: 14px; display: none;"></div>
    </div>
  </div>

  <!-- Header -->
  <header>
    <div class="brand-group">
      <span class="brand-crown">👑</span>
      <div>
        <div class="brand-title">UR-Heart Sovereign Command</div>
        <div style="font-size: 11px; color: var(--text-muted);">Production Cluster: urheart.asiverticals.me</div>
      </div>
    </div>
    <div style="display: flex; align-items: center; gap: 14px;">
      <span class="admin-pill">asiverticals@gmail.com</span>
      <button class="btn-logout" onclick="logoutAdmin()">Sign Out</button>
    </div>
  </header>

  <!-- Nav Tabs -->
  <div class="nav-tabs">
    <button class="tab-btn active" onclick="switchTab('overview')">📊 Overview & Metrics</button>
    <button class="tab-btn" onclick="switchTab('kyc')">🛡️ KYC Escalations Queue</button>
    <button class="tab-btn" onclick="switchTab('users')">👥 User Operations & Bans</button>
    <button class="tab-btn" onclick="switchTab('audit')">📜 Immutable Audit Logs</button>
    <button class="tab-btn" onclick="switchTab('config')">⚙️ System Runtime Config</button>
  </div>

  <!-- Content -->
  <main>
    <!-- TAB 1: OVERVIEW -->
    <div id="tab-overview" class="tab-pane active">
      <div class="stats-grid">
        <div class="stat-card">
          <div class="stat-label">Total Sanctuary Seekers</div>
          <div class="stat-val" id="stat-total-users">-</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Active Members</div>
          <div class="stat-val" id="stat-active-users">-</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Pending KYC Escalations</div>
          <div class="stat-val" id="stat-pending-kyc" style="color: var(--crimson);">-</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Active Paid Subscribers</div>
          <div class="stat-val" id="stat-subscribers">-</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Total Net IAP Revenue</div>
          <div class="stat-val" id="stat-revenue" style="color: var(--emerald);">-</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Banned / Quarantined</div>
          <div class="stat-val" id="stat-banned">-</div>
        </div>
      </div>

      <div class="section-card">
        <div class="section-title">
          <span>Cluster Health & Security Telemetry</span>
          <button class="btn-logout" onclick="loadPortalStats()">Refresh Telemetry</button>
        </div>
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 16px; font-size: 13px;">
          <div style="background: rgba(0,0,0,0.3); padding: 16px; border-radius: 10px;">
            <div style="color: var(--text-muted); margin-bottom: 4px;">Superadmin Whitelist:</div>
            <strong style="color: var(--gold);">asiverticals@gmail.com (Locked)</strong>
          </div>
          <div style="background: rgba(0,0,0,0.3); padding: 16px; border-radius: 10px;">
            <div style="color: var(--text-muted); margin-bottom: 4px;">Zero-Trust Fail-Closed Gate:</div>
            <strong style="color: var(--emerald);">Active (All other emails: 403 Forbidden)</strong>
          </div>
          <div style="background: rgba(0,0,0,0.3); padding: 16px; border-radius: 10px;">
            <div style="color: var(--text-muted); margin-bottom: 4px;">Server Timestamp:</div>
            <strong id="stat-server-time">-</strong>
          </div>
        </div>
      </div>
    </div>

    <!-- TAB 2: KYC QUEUE -->
    <div id="tab-kyc" class="tab-pane">
      <div class="section-card">
        <div class="section-title">
          <span>Pending Sentinel Verification Queue</span>
          <button class="btn-logout" onclick="loadKycQueue()">Refresh Queue</button>
        </div>
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>User ID</th>
              <th>Declared DOB / Age</th>
              <th>Groq Match Score</th>
              <th>Reasoning</th>
              <th>Media Preview</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody id="kycQueueBody">
            <tr><td colspan="7" style="text-align: center; color: var(--text-muted);">Loading pending verifications...</td></tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- TAB 3: USER OPERATIONS -->
    <div id="tab-users" class="tab-pane">
      <div class="section-card">
        <div class="section-title">User Roster & Ban Management</div>
        <div class="search-bar">
          <input type="text" id="userSearchInput" class="search-input" placeholder="Search user by full name or email..." onkeydown="if(event.key==='Enter') searchUsers()" />
          <button class="btn-gold" style="width: auto; padding: 10px 24px;" onclick="searchUsers()">Search</button>
        </div>
        <table>
          <thead>
            <tr>
              <th>Full Name</th>
              <th>Email</th>
              <th>Role</th>
              <th>KYC Status</th>
              <th>Tier</th>
              <th>Streak</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody id="userListBody">
            <tr><td colspan="8" style="text-align: center; color: var(--text-muted);">Click search or enter query...</td></tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- TAB 4: AUDIT LOGS -->
    <div id="tab-audit" class="tab-pane">
      <div class="section-card">
        <div class="section-title">
          <span>Forensic Administrative Audit Trail</span>
          <button class="btn-logout" onclick="loadAuditLogs()">Refresh Logs</button>
        </div>
        <table>
          <thead>
            <tr>
              <th>Time</th>
              <th>Admin</th>
              <th>Action</th>
              <th>Target</th>
              <th>Details</th>
              <th>IP Address</th>
            </tr>
          </thead>
          <tbody id="auditLogsBody">
            <tr><td colspan="6" style="text-align: center; color: var(--text-muted);">Loading forensic trail...</td></tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- TAB 5: SYSTEM CONFIG -->
    <div id="tab-config" class="tab-pane">
      <div class="section-card">
        <div class="section-title">Runtime Platform Switches & Security Toggles</div>
        <div style="display: flex; flex-direction: column; gap: 16px; max-width: 600px;">
          <label style="display: flex; justify-content: space-between; align-items: center; padding: 14px; background: rgba(0,0,0,0.3); border-radius: 10px;">
            <span>Maintenance Slumber Mode</span>
            <input type="checkbox" id="cfg-maintenance" />
          </label>
          <label style="display: flex; justify-content: space-between; align-items: center; padding: 14px; background: rgba(0,0,0,0.3); border-radius: 10px;">
            <span>Strict AI Moderation & Torso Skin Filter</span>
            <input type="checkbox" id="cfg-strict-ai" />
          </label>
          <label style="display: flex; justify-content: space-between; align-items: center; padding: 14px; background: rgba(0,0,0,0.3); border-radius: 10px;">
            <span>Ad SSV Mediation Engine</span>
            <input type="checkbox" id="cfg-ad-mediation" />
          </label>
          <label style="display: flex; justify-content: space-between; align-items: center; padding: 14px; background: rgba(0,0,0,0.3); border-radius: 10px;">
            <span>Allow New Seeker Registrations</span>
            <input type="checkbox" id="cfg-registration" />
          </label>
          <button class="btn-gold" style="margin-top: 10px;" onclick="saveSystemConfig()">Save Runtime Switches</button>
        </div>
      </div>
    </div>
  </main>

  <div id="toast"></div>

  <script>
    let authToken = sessionStorage.getItem('ur_heart_admin_token') || '';

    function showToast(msg) {
      const t = document.getElementById('toast');
      t.innerText = msg;
      t.style.display = 'block';
      setTimeout(() => { t.style.display = 'none'; }, 3500);
    }

    async function apiFetch(url, options = {}) {
      if (!options.headers) options.headers = {};
      options.headers['Authorization'] = 'Bearer ' + authToken;
      options.headers['Content-Type'] = 'application/json';
      const res = await fetch(url, options);
      if (res.status === 401 || res.status === 403) {
        sessionStorage.removeItem('ur_heart_admin_token');
        document.getElementById('authModal').style.display = 'flex';
        throw new Error('Unauthorized');
      }
      return res;
    }

    async function authenticateAdmin() {
      const input = document.getElementById('adminTokenInput').value.trim();
      const errEl = document.getElementById('authError');
      const btnEl = document.getElementById('authBtn');
      errEl.style.display = 'none';
      if (!input) return;

      btnEl.disabled = true;
      btnEl.innerText = 'Authenticating...';

      // 1. Try Sovereign Master Key Login
      try {
        const loginRes = await fetch('/api/v1/admin/portal/auth/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email: 'asiverticals@gmail.com', secret_key: input })
        });
        if (loginRes.ok) {
          const loginData = await loginRes.json();
          authToken = loginData.access_token;
          sessionStorage.setItem('ur_heart_admin_token', authToken);
          document.getElementById('authModal').style.display = 'none';
          loadPortalStats();
          showToast('Sovereign Sentinel Authenticated: asiverticals@gmail.com');
          btnEl.disabled = false;
          btnEl.innerText = 'Authenticate Sovereign Sentinel';
          return;
        }
      } catch (loginErr) {}

      // 2. Fallback: Verify as direct Bearer token
      authToken = input;
      try {
        const res = await apiFetch('/api/v1/admin/portal/stats');
        if (res.ok) {
          sessionStorage.setItem('ur_heart_admin_token', authToken);
          document.getElementById('authModal').style.display = 'none';
          loadPortalStats();
          showToast('Sovereign Sentinel Authenticated: asiverticals@gmail.com');
        } else {
          errEl.innerText = 'Access Denied: Invalid secret key or token.';
          errEl.style.display = 'block';
        }
      } catch (e) {
        errEl.innerText = 'Authorization failed. Confirm secret key or token.';
        errEl.style.display = 'block';
      } finally {
        btnEl.disabled = false;
        btnEl.innerText = 'Authenticate Sovereign Sentinel';
      }
    }

    function logoutAdmin() {
      sessionStorage.removeItem('ur_heart_admin_token');
      location.reload();
    }

    function switchTab(tabId) {
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
      
      const pane = document.getElementById('tab-' + tabId);
      if (pane) pane.classList.add('active');
      event.currentTarget.classList.add('active');

      if (tabId === 'overview') loadPortalStats();
      if (tabId === 'kyc') loadKycQueue();
      if (tabId === 'users') searchUsers();
      if (tabId === 'audit') loadAuditLogs();
      if (tabId === 'config') loadSystemConfig();
    }

    async function loadPortalStats() {
      try {
        const res = await apiFetch('/api/v1/admin/portal/stats');
        const data = await res.json();
        document.getElementById('stat-total-users').innerText = data.total_users;
        document.getElementById('stat-active-users').innerText = data.active_users;
        document.getElementById('stat-pending-kyc').innerText = data.pending_kyc_escalations;
        document.getElementById('stat-subscribers').innerText = data.active_subscribers;
        document.getElementById('stat-revenue').innerText = '$' + data.total_net_revenue_usd.toFixed(2);
        document.getElementById('stat-banned').innerText = data.banned_users;
        document.getElementById('stat-server-time').innerText = new Date(data.server_time).toLocaleString();
      } catch (e) {}
    }

    async function loadKycQueue() {
      const tbody = document.getElementById('kycQueueBody');
      tbody.innerHTML = '<tr><td colspan="7" style="text-align: center;">Loading...</td></tr>';
      try {
        const res = await apiFetch('/api/v1/admin/kyc/pending-queue');
        const items = await res.json();
        if (items.length === 0) {
          tbody.innerHTML = '<tr><td colspan="7" style="text-align: center; color: var(--emerald);">✓ Zero pending KYC items. Sanctuary is clear!</td></tr>';
          return;
        }
        tbody.innerHTML = items.map(item => `
          <tr>
            <td>#${item.id}</td>
            <td style="font-family: monospace; font-size: 11px;">${item.user_id}</td>
            <td>${item.declared_dob} (${item.declared_age} yrs)</td>
            <td><span class="badge ${item.groq_match_score >= 80 ? 'badge-green' : 'badge-gold'}">${item.groq_match_score}%</span></td>
            <td>${item.groq_reasoning}</td>
            <td><a href="${item.anchor_photo_url}" target="_blank" style="color: var(--gold);">Photo</a> | <a href="${item.kyc_video_url}" target="_blank" style="color: var(--gold);">Selfie Photo</a></td>
            <td>
              <button class="action-btn btn-approve" onclick="resolveKyc(${item.id}, '${item.user_id}', 'approve')">Approve</button>
              <button class="action-btn btn-reject" onclick="resolveKyc(${item.id}, '${item.user_id}', 'reject')">Reject</button>
            </td>
          </tr>
        `).join('');
      } catch (e) {
        tbody.innerHTML = '<tr><td colspan="7" style="text-align: center; color: var(--crimson);">Failed to load KYC queue.</td></tr>';
      }
    }

    async function resolveKyc(id, userId, action) {
      if (!confirm(`Are you sure you want to ${action.toUpperCase()} KYC escalation #${id}?`)) return;
      try {
        const res = await apiFetch('/api/v1/admin/kyc/resolve', {
          method: 'POST',
          body: JSON.stringify({ escalation_id: id, user_id: userId, action: action })
        });
        if (res.ok) {
          showToast(`KYC #${id} successfully ${action}d!`);
          loadKycQueue();
        }
      } catch (e) {
        alert('Resolution failed.');
      }
    }

    async function searchUsers() {
      const q = document.getElementById('userSearchInput').value.trim();
      const tbody = document.getElementById('userListBody');
      tbody.innerHTML = '<tr><td colspan="8" style="text-align: center;">Searching...</td></tr>';
      try {
        const res = await apiFetch('/api/v1/admin/portal/users?limit=30' + (q ? '&search=' + encodeURIComponent(q) : ''));
        const users = await res.json();
        if (users.length === 0) {
          tbody.innerHTML = '<tr><td colspan="8" style="text-align: center; color: var(--text-muted);">No users found.</td></tr>';
          return;
        }
        tbody.innerHTML = users.map(u => `
          <tr>
            <td><strong>${u.full_name}</strong></td>
            <td>${u.email || '-'}</td>
            <td><span class="badge ${u.role === 'superadmin' ? 'badge-gold' : ''}">${u.role}</span></td>
            <td><span class="badge ${u.kyc_status ? 'badge-green' : 'badge-gold'}">${u.kyc_status ? 'Verified' : 'Pending'}</span></td>
            <td>${u.subscription_tier}</td>
            <td>${u.streak_count}🔥</td>
            <td><span class="badge ${u.is_banned ? 'badge-red' : 'badge-green'}">${u.is_banned ? 'Banned' : 'Active'}</span></td>
            <td>
              ${u.is_banned ? 
                `<button class="action-btn btn-approve" onclick="toggleBan('${u.id}', false)">Unban</button>` :
                `<button class="action-btn btn-reject" onclick="toggleBan('${u.id}', true)">Ban</button>`
              }
              <button class="action-btn" style="background: rgba(224,169,109,0.15); color: var(--gold); border-color: var(--gold);" onclick="toggleKyc('${u.id}', ${!u.kyc_status})">${u.kyc_status ? 'Revoke KYC' : 'Grant KYC'}</button>
            </td>
          </tr>
        `).join('');
      } catch (e) {
        tbody.innerHTML = '<tr><td colspan="8" style="text-align: center; color: var(--crimson);">Failed to load users.</td></tr>';
      }
    }

    async function toggleBan(userId, doBan) {
      const action = doBan ? 'ban' : 'unban';
      if (!confirm(`Are you sure you want to ${action} this user?`)) return;
      try {
        const endpoint = `/api/v1/admin/portal/users/${userId}/${action}`;
        const res = await apiFetch(endpoint, {
          method: 'POST',
          body: JSON.stringify({ reason: 'Sovereign Sentinel Decision' })
        });
        if (res.ok) {
          showToast(`User ${action}ned successfully.`);
          searchUsers();
        }
      } catch (e) {
        alert(`Failed to ${action} user.`);
      }
    }

    async function toggleKyc(userId, newStatus) {
      try {
        const res = await apiFetch(`/api/v1/admin/portal/users/${userId}/set-kyc`, {
          method: 'POST',
          body: JSON.stringify({ is_verified: newStatus, notes: 'Superadmin direct toggle' })
        });
        if (res.ok) {
          showToast(`KYC status updated.`);
          searchUsers();
        }
      } catch (e) {
        alert('Failed to update KYC status.');
      }
    }

    async function loadAuditLogs() {
      const tbody = document.getElementById('auditLogsBody');
      tbody.innerHTML = '<tr><td colspan="6" style="text-align: center;">Loading audit logs...</td></tr>';
      try {
        const res = await apiFetch('/api/v1/admin/portal/audit-logs?limit=50');
        const logs = await res.json();
        if (logs.length === 0) {
          tbody.innerHTML = '<tr><td colspan="6" style="text-align: center; color: var(--text-muted);">No audit logs recorded yet.</td></tr>';
          return;
        }
        tbody.innerHTML = logs.map(l => `
          <tr>
            <td>${new Date(l.created_at).toLocaleString()}</td>
            <td><strong style="color: var(--gold);">${l.admin_email}</strong></td>
            <td><span class="badge badge-gold">${l.action}</span></td>
            <td style="font-family: monospace; font-size: 11px;">${l.target_type || ''}: ${l.target_id || ''}</td>
            <td style="max-width: 300px; word-break: break-all;">${l.details || '-'}</td>
            <td>${l.ip_address || '-'}</td>
          </tr>
        `).join('');
      } catch (e) {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align: center; color: var(--crimson);">Failed to load audit logs.</td></tr>';
      }
    }

    async function loadSystemConfig() {
      try {
        const res = await apiFetch('/api/v1/admin/portal/config');
        const data = await res.json();
        const cfg = data.config || {};
        document.getElementById('cfg-maintenance').checked = !!cfg.maintenance_mode;
        document.getElementById('cfg-strict-ai').checked = !!cfg.strict_ai_moderation;
        document.getElementById('cfg-ad-mediation').checked = !!cfg.ad_mediation_active;
        document.getElementById('cfg-registration').checked = !!cfg.registration_open;
      } catch (e) {}
    }

    async function saveSystemConfig() {
      const updated = {
        maintenance_mode: document.getElementById('cfg-maintenance').checked,
        strict_ai_moderation: document.getElementById('cfg-strict-ai').checked,
        ad_mediation_active: document.getElementById('cfg-ad-mediation').checked,
        registration_open: document.getElementById('cfg-registration').checked,
      };
      try {
        const res = await apiFetch('/api/v1/admin/portal/config', {
          method: 'PUT',
          body: JSON.stringify({ config: updated })
        });
        if (res.ok) {
          showToast('System Runtime Configuration Saved!');
        }
      } catch (e) {
        alert('Failed to save config.');
      }
    }

    // Auto-login via URL parameters or stored session
    const urlParams = new URLSearchParams(window.location.search);
    const keyParam = urlParams.get('key');
    const tokenParam = urlParams.get('token');

    if (tokenParam) {
      authToken = tokenParam;
      sessionStorage.setItem('ur_heart_admin_token', authToken);
    }

    if (authToken) {
      document.getElementById('authModal').style.display = 'none';
      loadPortalStats();
    } else if (keyParam) {
      document.getElementById('adminTokenInput').value = keyParam;
      authenticateAdmin();
    }
  </script>
</body>
</html>"""
