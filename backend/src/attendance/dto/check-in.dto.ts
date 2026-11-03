import { IsNotEmpty, IsNumber, IsOptional, IsString, IsIn } from 'class-validator';

export class CheckInDto {
  @IsNumber()
  @IsNotEmpty()
  latitude: number;

  @IsNumber()
  @IsNotEmpty()
  longitude: number;

  @IsOptional()
  @IsString()
  addressText?: string;

  @IsOptional()
  @IsString()
  address_text?: string;

  @IsOptional()
  @IsString()
  @IsIn(['morning', 'afternoon'])
  sessionType?: 'morning' | 'afternoon';

  @IsOptional()
  @IsString()
  @IsIn(['morning', 'afternoon'])
  session_type?: 'morning' | 'afternoon';

  @IsOptional()
  @IsString()
  deviceInfo?: string;

  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsString()
  @IsIn(['office', 'home', 'home_office', 'field'])
  workMode?: 'office' | 'home' | 'home_office' | 'field';

  @IsOptional()
  @IsString()
  @IsIn(['office', 'home', 'home_office', 'field'])
  work_mode?: 'office' | 'home' | 'home_office' | 'field';

  @IsOptional()
  @IsString()
  fieldProjectId?: string;

  @IsOptional()
  @IsString()
  field_project_id?: string;

  @IsOptional()
  @IsString()
  date?: string;
}
