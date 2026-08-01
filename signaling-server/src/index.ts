import { loadConfig } from "./config.js";
import { SignalingServer } from "./server.js";

const config = loadConfig();
const server = new SignalingServer(config);
server.start();
