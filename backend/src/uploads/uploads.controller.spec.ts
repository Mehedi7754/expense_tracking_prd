import { BadRequestException } from '@nestjs/common';
import { UploadsController } from './uploads.controller';
import { UploadsService } from './uploads.service';

describe('UploadsController batch receipts', () => {
  const saveFile = jest.fn().mockResolvedValue({
    url: '/uploads/receipts/receipt.jpg', filename: 'receipt.jpg', sizeBytes: 42,
  });
  const controller = new UploadsController({ saveFile } as unknown as UploadsService);

  beforeEach(() => saveFile.mockClear());

  it('accepts the string array sent by mobile and web and returns results', async () => {
    const response = await controller.uploadBatch({
      files: ['data:image/jpeg;base64,YQ==', 'data:image/jpeg;base64,Yg=='],
      category: 'receipts',
    });
    expect(saveFile).toHaveBeenCalledTimes(2);
    expect(saveFile).toHaveBeenCalledWith('data:image/jpeg;base64,YQ==', 'receipts', undefined);
    expect(response.results).toHaveLength(2);
    expect(response.urls).toEqual(['/uploads/receipts/receipt.jpg', '/uploads/receipts/receipt.jpg']);
  });

  it('rejects malformed batch items instead of silently losing a receipt', async () => {
    await expect(controller.uploadBatch({ files: [''] })).rejects.toBeInstanceOf(BadRequestException);
    expect(saveFile).not.toHaveBeenCalled();
  });
});
