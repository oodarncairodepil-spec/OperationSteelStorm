import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { loadConfig } from "../src/config.js";
import { ClientMessageSchema } from "../src/protocol.js";
import { RateLimiter } from "../src/rate-limiter.js";
import { RoomStore } from "../src/room-store.js";

describe("RoomStore", () => {
  it("creates and joins a room", () => {
    const store = new RoomStore(2, 6);
    const room = store.createRoom("host-1", "Alpha");
    assert.equal(room.hostPeerId, "host-1");
    assert.equal(room.code.length, 6);

    const join = store.joinRoom(room.code, "client-1", "Bravo");
    assert.equal(join.ok, true);
    if (join.ok) {
      assert.equal(join.room.players.size, 2);
    }
  });

  it("rejects full rooms and duplicate names", () => {
    const store = new RoomStore(2, 6);
    const room = store.createRoom("host-1", "Alpha");
    assert.equal(store.joinRoom(room.code, "c1", "Bravo").ok, true);
    assert.equal(store.joinRoom(room.code, "c2", "Charlie").ok, false);

    const store2 = new RoomStore(4, 6);
    const room2 = store2.createRoom("host-1", "Alpha");
    const dup = store2.joinRoom(room2.code, "c1", "alpha");
    assert.equal(dup.ok, false);
    if (!dup.ok) {
      assert.equal(dup.reason, "duplicate_name");
    }
  });
});

describe("RateLimiter", () => {
  it("blocks after max messages in window", () => {
    const limiter = new RateLimiter(1000, 3);
    assert.equal(limiter.allow("a", 1000), true);
    assert.equal(limiter.allow("a", 1001), true);
    assert.equal(limiter.allow("a", 1002), true);
    assert.equal(limiter.allow("a", 1003), false);
  });
});

describe("protocol validation", () => {
  it("accepts create_room and rejects garbage", () => {
    const ok = ClientMessageSchema.safeParse({
      type: "create_room",
      playerName: "Scout",
    });
    assert.equal(ok.success, true);

    const bad = ClientMessageSchema.safeParse({ type: "explode", payload: 1 });
    assert.equal(bad.success, false);
  });
});

describe("config", () => {
  it("loads defaults and env overrides", () => {
    const config = loadConfig({
      PORT: "9000",
      ALLOWED_ORIGINS: "https://a.example,https://b.example",
      ALLOW_LAN_ORIGINS: "true",
      MAX_PLAYERS_PER_ROOM: "2",
      TLS_CERT_FILE: "/tmp/dev-cert.pem",
      TLS_KEY_FILE: "/tmp/dev-key.pem",
    });
    assert.equal(config.port, 9000);
    assert.deepEqual(config.allowedOrigins, ["https://a.example", "https://b.example"]);
    assert.equal(config.allowLanOrigins, true);
    assert.equal(config.maxPlayersPerRoom, 2);
    assert.equal(config.tlsCertFile, "/tmp/dev-cert.pem");
    assert.equal(config.tlsKeyFile, "/tmp/dev-key.pem");
  });
});
