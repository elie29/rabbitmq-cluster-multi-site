# 📄 Technical Datasheet

## 🎯 Objective: Data Synchronization Architecture

Enable on-premise sites with Oracle, PostgreSQL or SQL Server databases to operate independently while ensuring data synchronization via a resilient event bus (RabbitMQ).

This project is intended to build the cluster described in the following article: [Building a Resilient Site-Aware Synchronization](https://elie29.hashnode.dev/building-a-resilient-site-aware-synchronization)

## 🧱 Components

| Component            | Role                                                                 |
|----------------------|----------------------------------------------------------------------|
| `Outbox`             | Local table storing events emitted by the application, pending dispatch. |
| `RabbitMQ Cluster`   | Deployed with 3 brokers in clustered mode behind HaProxy. Handles event distribution (fanout). |
| `Producer`           | The local application that writes to the database and the `Outbox` in a single transaction. |
| `Consumer`           | Local process consuming events via RabbitMQ to apply changes to the database. |
| `Event`              | Typical structure: `id`, `timestamp`, `origin`, `type`, `data`. |
| `SITE_PARIS`         | Queue dedicated to events propagated to the Paris site. |
| `SITE_LONDON`        | Queue dedicated to events propagated to the London site. |
| `SITE_MADRID`        | Queue dedicated to events propagated to the Madrid site. |
| `SITE_PARIS_HISTO`   | Queue dedicated to the centralized `golden source` archive. Stores all events from all sites. |

When a `Consumer` receives an event it originally emitted, it deletes it from the `Outbox`. This confirms the event has been successfully propagated through RabbitMQ.

## 🔁 Event Lifecycle

1. **Local Production**: The application writes to the database and inserts into the `Outbox` in the same transaction.
2. **Detection & Push**: A local dispatcher (Cron-based) reads from the `Outbox` and publishes to RabbitMQ.
3. **Fanout**: RabbitMQ distributes the event to all sites.
4. **Local Processing**: Each site checks if it has already processed the event (via `id`), and applies it if not.
5. **Purge**: The emitting site deletes the event from its `Outbox`.
6. **Archiving**: The event is also sent in parallel to the `SITE_PARIS_HISTO` queue (central archive).
7. **Cleanup**: A scheduled task purges events older than X days (default is 90 days).

## 🔐 Guarantees

| Guarantee             | Details |
|------------------------|---------|
| Network Resilience     | The system continues to function even if RabbitMQ is temporarily unreachable. |
| Idempotency            | Ensured via the globally unique `id` of each event. |
| Disconnection Support  | Each site is autonomous with its own database and `Outbox`. |
| Replay                 | Archived events in Paris enable replay if needed. |
| Flow Isolation         | Business flows and historical tracking are separated and non-intrusive. |

## 🛠️ Advanced Options

- Processing confirmations or error messages can be sent back to the emitting site via the default (direct) exchange, or to both the emitter and the archive using a topic exchange.

## Try it your self

### `docker-compose.yml`

docker-compose config file, including 3 RabbitMQ nodes and an HAProxy.

| Service     | Description               |
| ----------- | ------------------------- |
| `rabbitmq1` | RabbitMQ (cluster)        |
| `rabbitmq2` | RabbitMQ (cluster member) |
| `rabbitmq3` | RabbitMQ (cluster member) |
| `haproxy`   | Load Balancer             |

#### Default expose ports

| Host              | Description                     |
| ----------------- | ------------------------------- |
| `localhost:1936`  | HA proxy stats                  |
| `localhost:5672`  | AMQP 0-9-1 and AMQP 1.0 clients |
| `localhost:15672` | HTTP API clients, management UI |

### `.env`

| Name                     | Default |
| ------------------------ | ------- |
| `RABBITMQ_DEFAULT_USER`  | admin   |
| `RABBITMQ_DEFAULT_PASS`  | 123456  |
| `RABBITMQ_DEFAULT_VHOST` | /       |
| `RABBITMQ_SHARED_COOKIE` | 123455054ce768211b836f9b392fc |

### Configure and launch

- rename .env.sample to .env, than update the info
- `docker-compose up -d`

### Stop node and try again

- `docker-compose up -d --scale rabbitmq1=0`
