import { ChatService } from './chat.service';

describe('ChatService.getChannelMessages', () => {
  it('starts message retrieval while the read marker is being saved', async () => {
    let finishReadMarker: ((value: { rows: unknown[] }) => void) | undefined;
    let messageQueryStarted = false;
    const db = {
      query: jest.fn((sql: string) => {
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
