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
