export type LogLevel = "debug" | "info" | "warning" | "error";

function envInt(env: NodeJS.ProcessEnv, name: string, fallback: number): number {
  const raw = env[name];
  if (raw === undefined || raw === "") {
    return fallback;
  }
  const value = Number.parseInt(raw, 10);
  return Number.isFinite(value) ? value : fallback;
}

function envString(env: NodeJS.ProcessEnv, name: string, fallback: string): string {
  const raw = env[name];
  return raw === undefined || raw === "" ? fallback : raw;
}

export interface ServerConfig {
  port: number;
  host: string;
  allowedOrigins: string[];
  allowLanOrigins: boolean;
  maxPlayersPerRoom: number;
  roomCodeLength: number;
  playerNameMaxLength: number;
  roomIdleTtlMs: number;
  rateLimitWindowMs: number;
  rateLimitMaxMessages: number;
  logLevel: LogLevel;
  tlsCertFile: string;
  tlsKeyFile: string;
}

function envBool(env: NodeJS.ProcessEnv, name: string, fallback: boolean): boolean {
  const raw = env[name];
  if (raw === undefined || raw === "") {
    return fallback;
  }
  const normalized = raw.trim().toLowerCase();
  return normalized === "1" || normalized === "true" || normalized === "yes" || normalized === "on";
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): ServerConfig {
  const origins = envString(env, "ALLOWED_ORIGINS", "http://localhost:8080")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);

  const logLevel = envString(env, "LOG_LEVEL", "info") as LogLevel;

  return {
    port: envInt(env, "PORT", 8787),
    host: envString(env, "HOST", "0.0.0.0"),
    allowedOrigins: origins,
    allowLanOrigins: envBool(env, "ALLOW_LAN_ORIGINS", false),
    maxPlayersPerRoom: envInt(env, "MAX_PLAYERS_PER_ROOM", 2),
    roomCodeLength: envInt(env, "ROOM_CODE_LENGTH", 6),
    playerNameMaxLength: envInt(env, "PLAYER_NAME_MAX_LENGTH", 16),
    roomIdleTtlMs: envInt(env, "ROOM_IDLE_TTL_MS", 1_800_000),
    rateLimitWindowMs: envInt(env, "RATE_LIMIT_WINDOW_MS", 10_000),
    rateLimitMaxMessages: envInt(env, "RATE_LIMIT_MAX_MESSAGES", 60),
    logLevel,
    tlsCertFile: envString(env, "TLS_CERT_FILE", ""),
    tlsKeyFile: envString(env, "TLS_KEY_FILE", ""),
  };
}
