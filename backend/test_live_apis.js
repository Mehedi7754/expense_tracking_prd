/**
 * Live HTTP API Test Suite for GW Project NestJS Backend
 * Tests all REST endpoints over actual TCP/HTTP sockets.
 */
const http = require('http');

const BASE_URL = process.env.API_BASE || 'http://127.0.0.1:8080/api/v1';

async function request(method, path, body = null, token = null) {
  const url = new URL(BASE_URL + path);
  const postData = body ? JSON.stringify(body) : null;

  const start = Date.now();
  return new Promise((resolve, reject) => {
    const req = http.request(
      url,
      {
        method,
        headers: {
          'Content-Type': 'application/json',
          ...(postData ? { 'Content-Length': Buffer.byteLength(postData) } : {}),
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      },
      (res) => {
        let rawData = '';
        res.on('data', (chunk) => (rawData += chunk));
        res.on('end', () => {
          const duration = Date.now() - start;
          let parsed;
          try {
            parsed = rawData ? JSON.parse(rawData) : null;
          } catch (e) {
            parsed = rawData;
          }
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            data: parsed,
            duration,
          });
        });
      },
    );

    req.on('error', (e) => reject(e));
    if (postData) req.write(postData);
    req.end();
  });
}

const results = [];

function assert(condition, message, details = '') {
  if (condition) {
    results.push({ passed: true, message, details });
    console.log(`  \x1b[32m✔\x1b[0m ${message} ${details ? `\x1b[90m(${details})\x1b[0m` : ''}`);
  } else {
    results.push({ passed: false, message, details });
    console.error(`  \x1b[31m✖\x1b[0m ${message} ${details ? `\x1b[31m(${details})\x1b[0m` : ''}`);
  }
}

async function runTests() {
  console.log('\n======================================================');
  console.log(' GW Project — Live Backend HTTP API Verification Suite');
  console.log(` Target: ${BASE_URL}`);
  console.log('======================================================\n');

  let adminToken = '';
  let memberToken = '';
  let projectId = '';
  let expenseId = '';
  let taskId = '';
  let clientId = '';

  // 1. Health & Low-Resource Diagnostics
  console.log('\x1b[1m[1. System Health & Infrastructure]\x1b[0m');
  const health = await request('GET', '/health');
  assert(health.statusCode === 200, 'GET /health returns 200 OK', `${health.duration}ms`);
  assert(health.data.status === 'ok', 'Status is "ok"');
  const mem = health.data.memoryUsage || {};
  const rssMB = Math.round((mem.rss || 0) / 1024 / 1024);
  const heapMB = Math.round((mem.heapUsed || 0) / 1024 / 1024);
  assert(rssMB < 150, 'Memory footprint is lightweight', `RSS: ${rssMB} MB, Heap: ${heapMB} MB`);

  // 2. Authentication Flow
  console.log('\n\x1b[1m[2. Authentication & Authorization Flow]\x1b[0m');
  const badLogin = await request('POST', '/auth/login', {
    email: 'admin@pfis.com',
    password: 'wrongpassword',
  });
  assert(badLogin.statusCode === 401, 'POST /auth/login fails on wrong credentials', `${badLogin.duration}ms`);

  const adminLogin = await request('POST', '/auth/login', {
    email: 'admin@pfis.com',
    password: 'password123',
  });
  assert(adminLogin.statusCode === 200, 'POST /auth/login succeeds for Admin (Eleanor Vance)', `${adminLogin.duration}ms`);
  assert(adminLogin.data.token && adminLogin.data.user.role === 'main_admin', 'JWT token received with main_admin role');
  adminToken = adminLogin.data.token;

  const memberLogin = await request('POST', '/auth/login', {
    email: 'fahim@pfis.com',
    password: 'password123',
  });
  assert(memberLogin.statusCode === 200, 'POST /auth/login succeeds for Member (Fahim Ahmed)', `${memberLogin.duration}ms`);
  memberToken = memberLogin.data.token;

  // 3. User Registration
  console.log('\n\x1b[1m[3. User Registration & Profile]\x1b[0m');
  const newEmail = `engineer_${Date.now()}@gwproject.org`;
  const registerRes = await request('POST', '/auth/register', {
    email: newEmail,
    password: 'securePassword123!',
    name: 'Tariq Al-Mansoor',
    role: 'project_member',
    department: 'GIS & Remote Sensing',
  });
  assert(registerRes.statusCode === 201, 'POST /auth/register creates new project member', `${registerRes.duration}ms`);
  assert(registerRes.data.user.email === newEmail, 'User profile registered correctly');

  const meRes = await request('GET', '/auth/me', null, adminToken);
  assert(meRes.statusCode === 200, 'GET /auth/me returns current user profile with token', `${meRes.duration}ms`);
  assert(meRes.data.email === 'admin@pfis.com', 'Profile matches Eleanor Vance');

  const meUnauth = await request('GET', '/auth/me');
  assert(meUnauth.statusCode === 401, 'GET /auth/me correctly rejects unauthenticated request');

  // 4. Categories API
  console.log('\n\x1b[1m[4. Categories & Budget Specifications]\x1b[0m');
  const catRes = await request('GET', '/categories', null, adminToken);
  assert(catRes.statusCode === 200, 'GET /categories returns seeded expense categories', `${catRes.duration}ms`);
  assert(Array.isArray(catRes.data) && catRes.data.length >= 5, `Fetched ${catRes.data?.length} categories`);
  const equipmentCat = catRes.data.find((c) => c.name === 'Equipment');
  assert(!!equipmentCat, 'Category "Equipment" exists with ID: ' + equipmentCat?.id);

  // 5. Corporate Clients CRM
  console.log('\n\x1b[1m[5. Corporate Client Management]\x1b[0m');
  const clientsRes = await request('GET', '/clients', null, adminToken);
  assert(clientsRes.statusCode === 200, 'GET /clients returns clients directory', `${clientsRes.duration}ms`);
  assert(Array.isArray(clientsRes.data) && clientsRes.data.length >= 1, `Found ${clientsRes.data?.length} clients`);

  const createClientRes = await request('POST', '/clients', {
    name: `Dhaka Mass Transit Authority ${Date.now().toString().slice(-4)}`,
    companyCode: `DMTA-${Date.now().toString().slice(-3)}`,
    clientType: 'government',
    contactPerson: 'Engr. M. Haque',
    email: 'procurement@dmta.gov.bd',
    phone: '+880-1711-223344',
    address: 'Agargaon, Dhaka-1207',
  }, adminToken);
  assert(createClientRes.statusCode === 201, 'POST /clients registers new corporate client', `${createClientRes.duration}ms`);
  clientId = createClientRes.data.id;

  // 6. Projects & Financial Management
  console.log('\n\x1b[1m[6. Projects & Financial Management]\x1b[0m');
  const projectsRes = await request('GET', '/projects', null, adminToken);
  assert(projectsRes.statusCode === 200, 'GET /projects returns all projects for Admin', `${projectsRes.duration}ms`);
  assert(Array.isArray(projectsRes.data) && projectsRes.data.length >= 1, `Loaded ${projectsRes.data?.length} projects`);

  const createProjRes = await request('POST', '/projects', {
    name: 'National GIS Drone Topography Survey 2026',
    description: 'High-precision corridor survey for high-speed rail corridor',
    client: 'Dhaka Mass Transit Authority',
    grossProjectValue: 6000000.0,
    budget: 4500000.0,
    taxStatus: 'included',
    taxRate: 0.10,
    officeBenefitRate: 0.30,
    startDate: '2026-10-01',
    endDate: '2027-03-31',
    categoryBudgets: {
      equipment: 1500000.0,
      transportation: 1000000.0,
      food: 500000.0,
    },
    teamMemberIds: [],
  }, adminToken);
  assert(createProjRes.statusCode === 201, 'POST /projects creates project with financial parameters', `${createProjRes.duration}ms`);
  assert(createProjRes.data.expectedNetRevenue === 5400000.0, 'Calculates net revenue after tax: ৳5,400,000');
  projectId = createProjRes.data.id;

  // Record revenue milestone
  const revenueRes = await request('POST', `/projects/${projectId}/revenue`, {
    amount: 1500000.0,
    date: '2026-10-10',
    note: 'Initial Mobilization Advance (25%)',
  }, adminToken);
  assert(revenueRes.statusCode === 201, 'POST /projects/:id/revenue logs milestone', `${revenueRes.duration}ms`);

  // Verify project sync trigger
  const projUpdated = await request('GET', `/projects/${projectId}`, null, adminToken);
  assert(projUpdated.data.amountReceived === 1500000.0, 'Project amountReceived updated to ৳1,500,000 via DB trigger');
  assert(projUpdated.data.amountReceivable === 4500000.0, 'Project amountReceivable synchronized to ৳4,500,000');

  // 7. Tasks Management
  console.log('\n\x1b[1m[7. Tasks Management]\x1b[0m');
  const tasksRes = await request('GET', '/tasks', null, adminToken);
  assert(tasksRes.statusCode === 200, 'GET /tasks returns project task list', `${tasksRes.duration}ms`);

  const createTaskRes = await request('POST', '/tasks', {
    projectId,
    title: 'Establish GCP Network & Base Stations',
    description: 'Install and calibrate RTK reference stations across survey zone',
    priority: 'high',
    dueDate: '2026-10-20',
  }, adminToken);
  assert(createTaskRes.statusCode === 201, 'POST /tasks schedules high-priority task', `${createTaskRes.duration}ms`);
  taskId = createTaskRes.data.id;

  // 8. Expense Submission, Office Benefit & Approval Workflow
  console.log('\n\x1b[1m[8. Expenses, Office Benefit & Workflow]\x1b[0m');
  const submitExpenseRes = await request('POST', '/expenses', {
    projectId,
    taskId,
    categoryId: equipmentCat.id,
    amount: 80000.0,
    currency: 'BDT',
    note: 'Trimble Geo 7X Handheld GNSS Receiver Calibration',
    hasReceipt: true,
    receiptPhotoUrl: 'https://cdn.gwproject.org/receipts/gnss_cal_2026.pdf',
    equipmentDetails: {
      equipmentName: 'Trimble Geo 7X GNSS',
      serialNumber: 'GEO7X-9882-DH',
    },
  }, memberToken);

  assert(submitExpenseRes.statusCode === 201, 'POST /expenses submits structured expense claim', `${submitExpenseRes.duration}ms`);
  assert(submitExpenseRes.data.amount === 80000.0, 'Direct expenditure recorded as ৳80,000');
  assert(submitExpenseRes.data.officeBenefitAmount === 24000.0, 'Database trigger calculated 30% Office Benefit: ৳24,000');
  assert(submitExpenseRes.data.status === 'pending', 'Initial expense status is "pending"');
  expenseId = submitExpenseRes.data.id;

  // Add Comment / Audit Note
  const commentRes = await request('POST', `/expenses/${expenseId}/comments`, {
    comment: 'Calibration certified by Bangladesh Survey Department lab.',
  }, memberToken);
  assert(commentRes.statusCode === 201, 'POST /expenses/:id/comments adds audit note to thread', `${commentRes.duration}ms`);
  assert(commentRes.data.comment === 'Calibration certified by Bangladesh Survey Department lab.', 'Comment content matches payload');

  // Approve Expense by Admin
  const approveRes = await request('POST', `/expenses/${expenseId}/approve`, {
    note: 'Approved after verifying survey calibration certificate.',
  }, adminToken);
  assert(approveRes.statusCode === 201, 'POST /expenses/:id/approve approves claim', `${approveRes.duration}ms`);
  assert(approveRes.data.status === 'approved', 'Expense status updated to "approved"');

  // Verify single expense fetch includes comments
  const singleExpense = await request('GET', `/expenses/${expenseId}`, null, adminToken);
  assert(singleExpense.data.comments.length >= 1, `Fetched expense with ${singleExpense.data.comments.length} comments`);

  // 9. Audit Logs & Compliance Trail
  console.log('\n\x1b[1m[9. Audit Logs & System Activity]\x1b[0m');
  const auditRes = await request('GET', '/audit-logs', null, adminToken);
  assert(auditRes.statusCode === 200, 'GET /audit-logs returns tamper-evident activity stream', `${auditRes.duration}ms`);
  assert(Array.isArray(auditRes.data), `Retrieved ${Array.isArray(auditRes.data) ? auditRes.data.length : 0} audit entries`);

  // 10. Notifications Center
  console.log('\n\x1b[1m[10. User Notifications System]\x1b[0m');
  const notifRes = await request('GET', '/notifications', null, adminToken);
  assert(notifRes.statusCode === 200, 'GET /notifications returns user notifications', `${notifRes.duration}ms`);
  assert(Array.isArray(notifRes.data), 'Notifications is an array');

  // Summary
  console.log('\n======================================================');
  const total = results.length;
  const passed = results.filter((r) => r.passed).length;
  const failed = total - passed;
  console.log(` Results: ${passed}/${total} Passed (${failed} Failed)`);
  console.log('======================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error('Fatal Test Execution Error:', err);
  process.exit(1);
});
