export class RateLimiter {
  private readonly buckets = new Map<string, number[]>();

  constructor(
    private readonly windowMs: number,
    private readonly maxMessages: number,
  ) {}

  allow(key: string, now = Date.now()): boolean {
    const cutoff = now - this.windowMs;
    const existing = this.buckets.get(key) ?? [];
    const recent = existing.filter((ts) => ts >= cutoff);
    if (recent.length >= this.maxMessages) {
      this.buckets.set(key, recent);
      return false;
    }
    recent.push(now);
    this.buckets.set(key, recent);
    return true;
  }

  clear(key: string): void {
    this.buckets.delete(key);
  }
}
