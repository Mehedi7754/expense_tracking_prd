import { Pool } from 'pg';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.join(__dirname, '../.env') });

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5433', 10),
  database: process.env.DB_NAME || 'spendwise_db',
  user: process.env.DB_USER || 'spendwise',
  password: process.env.DB_PASSWORD || 'spendwise123',
  connectionTimeoutMillis: 5000,
});

async function runVerification() {
  console.log('--- GW Backend & Database Verification Specialist ---');
  console.log(`Connected DB: ${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`);

  try {
    // 1. Ensure test user exists with department & designation
    const userRes = await pool.query(`
      INSERT INTO users (email, password_hash, full_name, role, department, designation, is_active)
      VALUES ('test_emp@gw.com', 'dummy_hash', 'Test Employee', 'project_member', 'Engineering & Survey', 'Senior GIS Analyst', true)
      ON CONFLICT (email) DO UPDATE 
      SET department = EXCLUDED.department, designation = EXCLUDED.designation, is_active = true
      RETURNING id, full_name, email, role, department, designation, is_active;
    `);
    const testUser = userRes.rows[0];
    console.log('\n[1] Verified Test User:', testUser);

    // 2. Insert test attendance record with all required fields
    const today = new Date().toISOString().slice(0, 10);
    const attRes = await pool.query(`
      INSERT INTO attendance_records (
        user_id, date, session_type, login_time, latitude, longitude,
        address_text, device_info, work_mode, status, notes
      ) VALUES (
        $1, $2, 'morning', clock_timestamp(), 23.8103, 90.4125,
        'Road 11, Banani, Dhaka, Bangladesh', 'Test Agent Verification Script',
        'office', 'present', 'Automated verification check-in test'
      )
      ON CONFLICT (user_id, date, session_type) DO UPDATE
      SET address_text = EXCLUDED.address_text,
          work_mode = EXCLUDED.work_mode,
          notes = EXCLUDED.notes,
          status = EXCLUDED.status,
          login_time = clock_timestamp()
      RETURNING id, user_id, date, session_type, login_time, address_text, work_mode, status, notes;
    `, [testUser.id, today]);
    console.log('\n[2] Inserted/Updated Attendance Record:', attRes.rows[0]);

    // 3. Test Live Query matching AttendanceService.getRecordsByDate
    console.log('\n[3] Testing Attendance Joined Query (getRecordsByDate):');
    const querySql = `
      SELECT a.id, 
             a.user_id as "userId", a.user_id as "user_id",
             u.full_name as "userName", u.full_name as "user_name",
             u.email as "userEmail", u.email as "user_email",
             COALESCE(u.department, '') as department, 
             COALESCE(u.designation, '') as designation,
             u.avatar_url as "avatarUrl", u.avatar_url as "avatar_url",
             a.date::text as "date", 
             a.session_type as "sessionType", a.session_type as "session_type",
             a.login_time::text as "loginTime", a.login_time::text as "login_time",
             a.latitude, a.longitude,
             a.address_text as "addressText", a.address_text as "address_text",
             a.device_info as "deviceInfo", a.device_info as "device_info",
             a.status, a.notes, 
             a.work_mode as "workMode", a.work_mode as "work_mode",
             a.created_at::text as "createdAt", a.created_at::text as "created_at"
      FROM attendance_records a
      JOIN users u ON a.user_id = u.id
      WHERE 1=1
      ORDER BY a.date DESC, a.login_time DESC LIMIT 500
    `;
    const joinedRows = (await pool.query(querySql)).rows;
    console.log(`Retrieved ${joinedRows.length} recent record(s) with LIMIT 500:`);
    const sample = joinedRows[0];
    console.log({
      id: sample.id,
      userId: sample.userId,
      user_id: sample.user_id,
      userName: sample.userName,
      department: sample.department,
      designation: sample.designation,
      notes: sample.notes,
      address_text: sample.address_text,
      addressText: sample.addressText,
      work_mode: sample.work_mode,
      workMode: sample.workMode,
      login_time: sample.login_time,
      loginTime: sample.loginTime,
      status: sample.status,
    });

    // Assertions
    if (!sample.department) throw new Error('Missing department in joined attendance');
    if (!sample.designation) throw new Error('Missing designation in joined attendance');
    if (!sample.notes) throw new Error('Missing notes in attendance');
    if (!sample.address_text) throw new Error('Missing address_text in attendance');
    if (!sample.work_mode) throw new Error('Missing work_mode in attendance');
    if (!sample.login_time) throw new Error('Missing login_time in attendance');
    if (!sample.status) throw new Error('Missing status in attendance');

    console.log('✅ ALL ATTENDANCE FIELDS PROPERLY JOINED & POPULATED!');

    // 4. Test Expenses Data Query
    console.log('\n[4] Testing Expenses Query & Schema:');
    const expensesRes = await pool.query(`
      SELECT e.id, e.amount, e.currency, e.status, e.date, e.has_receipt,
             u.full_name as employee_name, u.department, u.designation,
             c.name as category_name
      FROM expenses e
      LEFT JOIN users u ON e.employee_id = u.id
      LEFT JOIN categories c ON e.category_id = c.id
      LIMIT 5
    `);
    console.log(`Fetched ${expensesRes.rows.length} expense row(s) from PostgreSQL:`);
    if (expensesRes.rows.length > 0) {
      console.log(expensesRes.rows[0]);
    } else {
      console.log('Expenses table query successful (currently 0 records in fresh DB).');
    }

    console.log('\n✅ Verification Script Completed Successfully with 0 Errors!');
  } finally {
    await pool.end();
  }
}

runVerification().catch((err) => {
  console.error('❌ Verification failed:', err);
  process.exit(1);
});
