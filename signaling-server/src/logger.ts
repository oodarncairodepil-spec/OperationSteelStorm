import type { LogLevel } from "./config.js";

const LEVEL_ORDER: Record<LogLevel, number> = {
  debug: 10,
  info: 20,
  warning: 30,
  error: 40,
};

export class Logger {
  constructor(private readonly minLevel: LogLevel) {}

  debug(event: string, data: Record<string, unknown> = {}): void {
    this.write("debug", event, data);
  }

  info(event: string, data: Record<string, unknown> = {}): void {
    this.write("info", event, data);
  }

  warning(event: string, data: Record<string, unknown> = {}): void {
    this.write("warning", event, data);
  }

  error(event: string, data: Record<string, unknown> = {}): void {
    this.write("error", event, data);
  }

  private write(level: LogLevel, event: string, data: Record<string, unknown>): void {
    if (LEVEL_ORDER[level] < LEVEL_ORDER[this.minLevel]) {
      return;
    }
    const line = JSON.stringify({
      ts: new Date().toISOString(),
      level,
      event,
      ...data,
    });
    if (level === "error") {
      console.error(line);
    } else if (level === "warning") {
      console.warn(line);
    } else {
      console.log(line);
    }
  }
}
