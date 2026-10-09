import { Pool } from 'pg';
import * as bcrypt from 'bcryptjs';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.join(__dirname, '../.env') });

async function seed() {
  const email = process.env.ADMIN_EMAIL || process.argv[2] || 'admin@gw.com';
  const password = process.env.ADMIN_PASSWORD || process.argv[3] || 'password123';
  const fullName = process.env.ADMIN_NAME || process.argv[4] || 'System Administrator';

  const pool = new Pool({
    host: process.env.DB_HOST || '163.227.239.97',
    port: parseInt(process.env.DB_PORT || '5437', 10),
    database: process.env.DB_NAME || 'spendwise_db',
    user: process.env.DB_USER || 'spendwise',
    password: process.env.DB_PASSWORD || 'spendwise123',
    connectionTimeoutMillis: 5000,
  });

  try {
    console.log(`Connecting to PostgreSQL database at ${process.env.DB_HOST || '163.227.239.97'}:${process.env.DB_PORT || '5437'}...`);
    const hashedPassword = await bcrypt.hash(password, 10);

    const query = `
      INSERT INTO users (email, password_hash, full_name, role, department, designation, phone, is_active)
      VALUES ($1, $2, $3, 'main_admin', 'Corporate Governance', 'System Administrator', '+880 1711-000000', TRUE)
      ON CONFLICT (email) 
      DO UPDATE SET 
        password_hash = EXCLUDED.password_hash,
        full_name = EXCLUDED.full_name,
        role = 'main_admin',
        is_active = TRUE
      RETURNING id, email, full_name, role;
    `;

    const res = await pool.query(query, [email.trim().toLowerCase(), hashedPassword, fullName]);
    console.log('✅ Super Admin successfully seeded in PostgreSQL:');
    console.log(res.rows[0]);
    console.log(`\nLogin Credentials:`);
    console.log(`Email:    ${email}`);
    console.log(`Password: ${password}`);
  } catch (error) {
    console.error('❌ Error seeding Super Admin:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

seed();
