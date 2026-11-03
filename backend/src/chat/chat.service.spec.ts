import { ChatService } from './chat.service';

describe('ChatService.getChannelMessages', () => {
  it('starts message retrieval while the read marker is being saved', async () => {
    let finishReadMarker: ((value: { rows: unknown[] }) => void) | undefined;
    let messageQueryStarted = false;
    const db = {
      query: jest.fn((sql: string, params?: unknown[]) => {
        if (sql.includes('SELECT id FROM chat_participants')) {
          return Promise.resolve({ rows: [{ id: 'participant-1' }] });
        }
        if (sql.includes('UPDATE chat_participants SET last_read_at')) {
          return new Promise<{ rows: unknown[] }>((resolve) => { finishReadMarker = resolve; });
        }
        if (sql.includes('chat_messages')) {
          messageQueryStarted = true;
          return Promise.resolve({ rows: [] });
        }
        return Promise.resolve({ rows: [] });
      }),
    };
    const service = new ChatService(db as any, {} as any, {} as any);

    const result = service.getChannelMessages('channel-1', 'user-1', 100);
    await new Promise((resolve) => setImmediate(resolve));
    const startedWithoutWaitingForReadWrite = messageQueryStarted;
    finishReadMarker?.({ rows: [] });
    await result;

    expect(startedWithoutWaitingForReadWrite).toBe(true);
  });
});

describe('ChatService.getUserChannels', () => {
  it('waits for channel sync before returning the first channel list', async () => {
    let finishSync: (() => void) | undefined;
    let channelListRead = false;
    const db = {
      query: jest.fn((sql: string) => {
        if (sql.includes('FROM chat_participants cp')) channelListRead = true;
        return Promise.resolve({ rows: [] });
      }),
    };
    const service = new ChatService(db as any, {} as any, {} as any);
    jest.spyOn(service as any, 'ensureUserProjectChannels').mockImplementation(
      () => new Promise<void>((resolve) => { finishSync = resolve; }),
    );

    const result = service.getUserChannels('user-1');
    await new Promise((resolve) => setImmediate(resolve));
    const listReadBeforeSync = channelListRead;
    finishSync?.();
    await result;

    expect(listReadBeforeSync).toBe(false);
  });
});

describe('ChatService.sendMessage attachments', () => {
  it('persists document metadata and returns it to chat clients', async () => {
    const message = {
      id: 'message-1', channel_id: 'channel-1', sender_id: 'user-1',
      content: '', image_url: null, file_url: '/uploads/chat/report.pdf',
      file_name: 'report.pdf', file_mime_type: 'application/pdf',
      project_id: null, reply_to_id: null, created_at: new Date().toISOString(),
    };
    const db = {
      query: jest.fn((sql: string) => {
        if (sql.includes('FROM chat_channels c')) return Promise.resolve({ rows: [{ id: 'channel-1', type: 'direct', name: 'Direct' }] });
        if (sql.includes('INSERT INTO chat_messages')) return Promise.resolve({ rows: [message] });
        if (sql.includes('FROM users WHERE id')) return Promise.resolve({ rows: [{ full_name: 'Sender', role: 'project_member' }] });
        return Promise.resolve({ rows: [] });
      }),
    };
    const service = new ChatService(db as any, {} as any, {} as any);

    const sent = await service.sendMessage(
      'user-1', 'channel-1', '', undefined, undefined,
      '/uploads/chat/report.pdf', 'report.pdf', 'application/pdf',
    );

    expect(sent).toMatchObject({
      fileUrl: '/uploads/chat/report.pdf',
      fileName: 'report.pdf',
      fileMimeType: 'application/pdf',
    });
    const insert = db.query.mock.calls.find(([sql]) => sql.includes('INSERT INTO chat_messages')) as unknown as [string, unknown[]] | undefined;
    expect(insert?.[0]).toContain('file_url, file_name, file_mime_type');
    expect(insert?.[1]).toEqual(expect.arrayContaining(['/uploads/chat/report.pdf', 'report.pdf', 'application/pdf']));
  });
});
