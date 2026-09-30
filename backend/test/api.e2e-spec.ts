import { Test, TestingModule } from '@nestjs/testing';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from '../src/app.module';

describe('SpendWise / GW Project API E2E Tests (Fastify + NestJS + PostgreSQL)', () => {
  let app: NestFastifyApplication;
  let adminToken: string;
  let memberToken: string;
  let createdProjectId: string;
  let createdExpenseId: string;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication<NestFastifyApplication>(
      new FastifyAdapter({ logger: false }),
    );

    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        transform: true,
        forbidNonWhitelisted: false,
      }),
    );

    await app.init();
    await app.getHttpAdapter().getInstance().ready();
  });

  afterAll(async () => {
    await app.close();
  });

  describe('1. System Health & Infrastructure', () => {
    it('GET /api/v1/health - should report healthy database connection and low memory usage', async () => {
      const res = await app.inject({
        method: 'GET',
        url: '/api/v1/health',
      });

      expect(res.statusCode).toBe(200);
      const body = JSON.parse(res.payload);
      expect(body.status).toBe('ok');
      expect(body.database).toBe('connected');
      expect(body.engine).toContain('Fastify');
      expect(body.memoryUsage).toBeDefined();
    });
  });

  describe('2. Authentication & Authorization Flow', () => {
    it('POST /api/v1/auth/login - should fail with wrong password', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/login',
        payload: {
          email: 'admin@pfis.com',
          password: 'wrong_password_123',
        },
      });

      expect(res.statusCode).toBe(401);
    });

    it('POST /api/v1/auth/login - should login seeded Eleanor Vance (Admin) successfully', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/login',
        payload: {
          email: 'admin@pfis.com',
          password: 'password123',
        },
      });

      expect(res.statusCode).toBe(200);
      const body = JSON.parse(res.payload);
      expect(body.token).toBeDefined();
      expect(body.user.email).toBe('admin@pfis.com');
      expect(body.user.role).toBe('main_admin');
      adminToken = body.token;
    });

    it('POST /api/v1/auth/login - should login seeded Fahim Ahmed (Member) successfully', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/login',
        payload: {
          email: 'fahim@pfis.com',
          password: 'password123',
        },
      });

      expect(res.statusCode).toBe(200);
      const body = JSON.parse(res.payload);
      expect(body.token).toBeDefined();
      expect(body.user.email).toBe('fahim@pfis.com');
      expect(body.user.role).toBe('project_member');
      memberToken = body.token;
    });

    it('POST /api/v1/auth/register - should register a new test user and return JWT', async () => {
      const randomEmail = `test_${Date.now()}@gwproject.com`;
      const res = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/register',
        payload: {
          name: 'Integration Test Engineer',
          email: randomEmail,
          password: 'password123',
          role: 'projectMember',
          department: 'Quality Assurance',
        },
      });

      expect(res.statusCode).toBe(201);
      const body = JSON.parse(res.payload);
      expect(body.token).toBeDefined();
      expect(body.user.email).toBe(randomEmail);
    });

    it('GET /api/v1/auth/me - should reject unauthenticated requests', async () => {
      const res = await app.inject({
        method: 'GET',
        url: '/api/v1/auth/me',
      });

      expect(res.statusCode).toBe(401);
    });

    it('GET /api/v1/auth/me - should return profile for authenticated admin', async () => {
      const res = await app.inject({
        method: 'GET',
        url: '/api/v1/auth/me',
        headers: {
          authorization: `Bearer ${adminToken}`,
        },
      });

      expect(res.statusCode).toBe(200);
      const body = JSON.parse(res.payload);
      expect(body.email).toBe('admin@pfis.com');
      expect(body.name).toBe('Eleanor Vance');
    });
  });

  describe('3. Categories API', () => {
    it('GET /api/v1/categories - should list seeded categories with icons', async () => {
      const res = await app.inject({
        method: 'GET',
        url: '/api/v1/categories',
        headers: {
          authorization: `Bearer ${adminToken}`,
        },
      });

      expect(res.statusCode).toBe(200);
      const categories = JSON.parse(res.payload);
      expect(Array.isArray(categories)).toBe(true);
      expect(categories.length).toBeGreaterThanOrEqual(5);
      const names = categories.map((c: any) => c.name);
      expect(names).toContain('Equipment');
      expect(names).toContain('Transportation');
      expect(names).toContain('Food');
    });
  });

  describe('4. Projects & Financial Management', () => {
    it('GET /api/v1/projects - should return project portfolio for admin', async () => {
      const res = await app.inject({
        method: 'GET',
        url: '/api/v1/projects',
        headers: {
          authorization: `Bearer ${adminToken}`,
        },
      });

      expect(res.statusCode).toBe(200);
      const projects = JSON.parse(res.payload);
      expect(Array.isArray(projects)).toBe(true);
      expect(projects.length).toBeGreaterThanOrEqual(4);
      expect(projects[0].name).toBeDefined();
      expect(projects[0].grossProjectValue).toBeDefined();
    });

    it('POST /api/v1/projects - should create a new project with financial rules', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/api/v1/projects',
        headers: {
          authorization: `Bearer ${adminToken}`,
        },
        payload: {
          name: 'Geospatial Smart Infrastructure Mapping',
          description: 'High precision satellite & LiDAR mapping for urban corridors',
          client: 'Apex Technologies Inc.',
          grossProjectValue: 4000000.0,
          budget: 3200000.0,
          taxStatus: 'included',
          taxRate: 0.10,
          officeBenefitRate: 0.30,
          startDate: '2026-10-01',
          endDate: '2027-04-30',
          categoryBudgets: {
            equipment: 1000000.0,
            transportation: 800000.0,
            food: 400000.0,
          },
          teamMemberIds: [],
        },
      });

      expect(res.statusCode).toBe(201);
      const project = JSON.parse(res.payload);
      expect(project.id).toBeDefined();
      expect(project.name).toBe('Geospatial Smart Infrastructure Mapping');
      expect(project.expectedNetRevenue).toBe(3600000.0); // 4M * 0.9
      createdProjectId = project.id;
    });

    it('POST /api/v1/projects/:id/revenue - should record a revenue milestone', async () => {
      const res = await app.inject({
        method: 'POST',
        url: `/api/v1/projects/${createdProjectId}/revenue`,
        headers: {
          authorization: `Bearer ${adminToken}`,
        },
        payload: {
          amount: 1000000.0,
          date: '2026-10-15',
          note: 'Initial Mobilization Milestone',
        },
      });

      expect(res.statusCode).toBe(201);
      const revenue = JSON.parse(res.payload);
      expect(Number(revenue.amount)).toBe(1000000.0);
    });
  });

  describe('5. Expenses & Approval Workflow', () => {
    let equipmentCategoryId: string;

    beforeAll(async () => {
      const res = await app.inject({
        method: 'GET',
        url: '/api/v1/categories',
        headers: { authorization: `Bearer ${adminToken}` },
      });
      const categories = JSON.parse(res.payload);
      const eq = categories.find((c: any) => c.name === 'Equipment');
      equipmentCategoryId = eq.id;
    });

    it('GET /api/v1/expenses - should list expenses for project', async () => {
      const res = await app.inject({
        method: 'GET',
        url: '/api/v1/expenses',
        headers: {
          authorization: `Bearer ${adminToken}`,
        },
      });

      expect(res.statusCode).toBe(200);
      const expenses = JSON.parse(res.payload);
      expect(Array.isArray(expenses)).toBe(true);
      expect(expenses.length).toBeGreaterThanOrEqual(1);
    });

    it('POST /api/v1/expenses - should submit an expense and calculate office benefit via trigger', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/api/v1/expenses',
        headers: {
          authorization: `Bearer ${memberToken}`,
        },
        payload: {
          projectId: createdProjectId,
          categoryId: equipmentCategoryId,
          amount: 50000.0,
          currency: 'BDT',
          note: 'Differential GPS Rover and Tribrach purchase',
          hasReceipt: true,
          date: '2026-10-05',
          equipmentDetails: {
            equipmentName: 'Trimble R12i GNSS Rover',
            serialNumber: 'TRM-2026-099',
          },
        },
      });

      expect(res.statusCode).toBe(201);
      const expense = JSON.parse(res.payload);
      expect(expense.id).toBeDefined();
      expect(expense.amount).toBe(50000.0);
      // Office benefit trigger (30% of 50,000 = 15,000)
      expect(expense.officeBenefitAmount).toBe(15000.0);
      expect(expense.status).toBe('pending');
      createdExpenseId = expense.id;
    });

    it('POST /api/v1/expenses/:id/comments - should add an audit note', async () => {
      const res = await app.inject({
        method: 'POST',
        url: `/api/v1/expenses/${createdExpenseId}/comments`,
        headers: {
          authorization: `Bearer ${memberToken}`,
        },
        payload: {
          comment: 'Equipment calibrated and tested in field before deployment.',
        },
      });

      expect(res.statusCode).toBe(201);
      const comment = JSON.parse(res.payload);
      expect(comment.comment).toBe('Equipment calibrated and tested in field before deployment.');
    });

    it('POST /api/v1/expenses/:id/approve - should approve the expense', async () => {
      const res = await app.inject({
        method: 'POST',
        url: `/api/v1/expenses/${createdExpenseId}/approve`,
        headers: {
          authorization: `Bearer ${adminToken}`,
        },
        payload: {
          note: 'Verified purchase against project CAPEX budget.',
        },
      });

      expect(res.statusCode).toBe(201);
      const expense = JSON.parse(res.payload);
      expect(expense.status).toBe('approved');
    });
  });

  describe('6. Clients, Tasks & Compliance', () => {
    it('GET /api/v1/clients - should return corporate client directory', async () => {
      const res = await app.inject({
        method: 'GET',
        url: '/api/v1/clients',
        headers: { authorization: `Bearer ${adminToken}` },
      });

      expect(res.statusCode).toBe(200);
      const clients = JSON.parse(res.payload);
      expect(Array.isArray(clients)).toBe(true);
      expect(clients.length).toBeGreaterThanOrEqual(4);
    });

    it('GET /api/v1/tasks - should return task lists', async () => {
      const res = await app.inject({
        method: 'GET',
        url: '/api/v1/tasks',
        headers: { authorization: `Bearer ${adminToken}` },
      });

      expect(res.statusCode).toBe(200);
      const tasks = JSON.parse(res.payload);
      expect(Array.isArray(tasks)).toBe(true);
    });

    it('GET /api/v1/audit-logs - should return audit trail', async () => {
      const res = await app.inject({
        method: 'GET',
        url: '/api/v1/audit-logs',
        headers: { authorization: `Bearer ${adminToken}` },
      });

      expect(res.statusCode).toBe(200);
      const logs = JSON.parse(res.payload);
      expect(Array.isArray(logs)).toBe(true);
    });
  });
});
