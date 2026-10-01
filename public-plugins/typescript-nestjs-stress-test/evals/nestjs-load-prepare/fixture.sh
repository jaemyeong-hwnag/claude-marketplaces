#!/usr/bin/env bash
# 기본 스타터 모양의 NestJS 앱. 계측이 없고 logger 옵션도 없다
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src
cat > package.json <<'JSON'
{
  "name": "orders",
  "scripts": { "build": "nest build", "start": "nest start", "start:dev": "nest start --watch", "start:prod": "node dist/main" },
  "dependencies": { "@nestjs/common": "^12.1.2", "@nestjs/core": "^12.1.2", "@nestjs/platform-express": "^12.1.2" },
  "devDependencies": { "@nestjs/cli": "^12.0.8", "typescript": "^6.0.3" }
}
JSON
cat > src/main.ts <<'TS'
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  await app.listen(3000);
}
bootstrap();
TS
cat > src/app.module.ts <<'TS'
import { Module } from '@nestjs/common';
import { OrderController } from './order.controller';

@Module({ controllers: [OrderController] })
export class AppModule {}
TS
cat > src/order.controller.ts <<'TS'
import { Controller, Get, Logger, Param } from '@nestjs/common';

@Controller('orders')
export class OrderController {
  private readonly logger = new Logger(OrderController.name);
  @Get(':id')
  find(@Param('id') id: string) {
    this.logger.debug(`find ${id}`);
    return { id };
  }
}
TS
git add -A
git commit -qm init
