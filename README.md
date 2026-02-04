# Frappe Bench Development - Docker Services

Docker setup for running Redis and MariaDB services required for Frappe Bench development.

## Services Included

- **MariaDB 10.6**: Database server with Frappe-optimized configuration
- **Redis Cache**: Cache server (port 13000)
- **Redis Queue**: Queue server (port 11000)
- **Redis SocketIO**: SocketIO server (port 12000)

## Prerequisites

- Docker installed and running
- Docker Compose installed

## Quick Start

### 1. Start Services

```bash
docker-compose up -d
```

### 2. Verify Services are Running

```bash
docker-compose ps
```

All services should show as "healthy" after a few seconds.

### 3. Check Service Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f mariadb
docker-compose logs -f redis-cache
```

## Configuration

### Environment Variables

Edit `.env` file to customize:

- `MYSQL_ROOT_PASSWORD`: MariaDB root password (default: admin)
- `MYSQL_DATABASE`: Default database name (default: frappe)
- `MYSQL_USER`: MariaDB user (default: frappe)
- `MYSQL_PASSWORD`: MariaDB password (default: frappe)
- `MYSQL_PORT`: MariaDB port (default: 3306)
- `REDIS_CACHE_PORT`: Redis cache port (default: 13000)
- `REDIS_QUEUE_PORT`: Redis queue port (default: 11000)
- `REDIS_SOCKETIO_PORT`: Redis socketio port (default: 12000)

### MariaDB Configuration

Custom MariaDB configuration is in `mariadb-config/frappe.cnf`. This includes:
- UTF8MB4 character set
- InnoDB optimizations
- Connection limits
- Slow query logging

## Frappe Bench Integration

```bash
bench init --skip-redis-config-generation --frappe-branch version-15 frappe-bench
```

### Existing Bench Configuration

If you have an existing bench, update `common_site_config.json`:

```json
{
  "db_host": "127.0.0.1",
  "db_port": 3306,
  "redis_cache": "redis://127.0.0.1:13000",
  "redis_queue": "redis://127.0.0.1:11000",
  "redis_socketio": "redis://127.0.0.1:12000"
}
```

### Creating a New Site

When creating a new Frappe site, use these connection details:

```bash
bench new-site --mariadb-user-host-login-scope=% development.localhost
```

### Site Configuration

Your site's `site_config.json` should include:

```json
{
  "db_host": "127.0.0.1",
  "db_port": 3306,
  "redis_cache": "redis://127.0.0.1:13000",
  "redis_queue": "redis://127.0.0.1:11000",
  "redis_socketio": "redis://127.0.0.1:12000"
}
```

## Common Commands

### Stop Services

```bash
docker-compose stop
```

### Start Services

```bash
docker-compose start
```

### Restart Services

```bash
docker-compose restart
```

### Stop and Remove Containers

```bash
docker-compose down
```

### Stop and Remove Containers + Volumes (⚠️ Deletes all data)

```bash
docker-compose down -v
```

## Database Management

### Connect to MariaDB

```bash
# Using docker exec
docker exec -it frappe-mariadb mysql -u root -padmin

# Using mysql client on host
mysql -h 127.0.0.1 -P 3306 -u root -padmin
```

### Backup Database

```bash
docker exec frappe-mariadb mysqldump -u root -padmin --all-databases > backup.sql
```

### Restore Database

```bash
docker exec -i frappe-mariadb mysql -u root -padmin < backup.sql
```

## Redis Management

### Connect to Redis

```bash
# Redis Cache
docker exec -it frappe-redis-cache redis-cli

# Redis Queue
docker exec -it frappe-redis-queue redis-cli

# Redis SocketIO
docker exec -it frappe-redis-socketio redis-cli
```

### Clear Redis Cache

```bash
docker exec frappe-redis-cache redis-cli FLUSHALL
docker exec frappe-redis-queue redis-cli FLUSHALL
docker exec frappe-redis-socketio redis-cli FLUSHALL
```

## Troubleshooting

### Check Container Health

```bash
docker-compose ps
```

### View Container Logs

```bash
docker-compose logs -f [service-name]
```

### Restart a Specific Service

```bash
docker-compose restart mariadb
docker-compose restart redis-cache
```

### Check Port Conflicts

If ports are already in use, modify the ports in `.env` file:

```bash
# Example: Change MariaDB port to 3307
MYSQL_PORT=3307
```

### Permission Issues

If you encounter permission issues with volumes:

```bash
docker-compose down
sudo chown -R $USER:$USER .
docker-compose up -d
```

## Data Persistence

All data is persisted in Docker volumes:

- `mariadb-data`: MariaDB database files
- `redis-cache-data`: Redis cache data
- `redis-queue-data`: Redis queue data
- `redis-socketio-data`: Redis socketio data

To view volumes:

```bash
docker volume ls | grep frappe
```

## Network

All services are connected via the `frappe-network` bridge network, allowing them to communicate with each other using service names.

## Security Notes

⚠️ **Important**: This setup is for development only. For production:

1. Change default passwords
2. Restrict network access
3. Enable SSL/TLS
4. Configure proper firewall rules
5. Regular backups
6. Use secrets management

## License

This configuration is provided as-is for Frappe development purposes.
# frappe_dev_docker
