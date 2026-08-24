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
    }
  ]
};
