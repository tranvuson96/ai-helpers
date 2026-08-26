const path = require('path');
const rootDir = path.resolve(__dirname, '..');

module.exports = {
  apps: [
    {
      name: '9router',
      cwd: path.join(rootDir, '9router'),
      script: 'custom-server.js',
      args: '--port 20128 -H 127.0.0.1',
      interpreter: 'node',
      env: {
        NODE_ENV: 'production',
        PORT: 20128,
        HOST: '127.0.0.1',
        INITIAL_PASSWORD: process.env.INITIAL_PASSWORD || '123456',
        JWT_SECRET: process.env.JWT_SECRET || 'secret-jwt-token-key-9router-prod',
        NEXT_PUBLIC_BASE_URL: process.env.ROUTER_BASE_URL || 'http://router.sontv.test'
      }
    },
    {
      name: 'deepseek-harness',
      cwd: path.join(rootDir, 'dsh'),
      script: 'pnpm',
      args: 'dsh web --port 3080 --host 127.0.0.1',
      interpreter: 'none',
      env: {
        NODE_ENV: 'production',
        DSH_HOME: path.join(rootDir, 'config'),
        HOME: rootDir
      }
    },
    {
      name: 'hermes-agent',
      cwd: path.join(rootDir, 'hermes', 'web'),
      script: 'pnpm',
      args: 'run dev --host 127.0.0.1 --port 3090',
      interpreter: 'none',
      env: {
        NODE_ENV: 'production',
        PORT: 3090
      }
    }
  ]
};
