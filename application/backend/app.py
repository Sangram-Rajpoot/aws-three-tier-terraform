import json
import logging
import os
import time
from datetime import date, datetime
from functools import lru_cache
from typing import Any, Optional

import boto3
import pymysql
from flask import Flask, jsonify, request
from pymysql.cursors import DictCursor
from pymysql.err import IntegrityError

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
LOGGER = logging.getLogger("taskflow-api")


def json_value(value: Any) -> Any:
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    return value


def serialise_row(row: dict[str, Any]) -> dict[str, Any]:
    return {key: json_value(value) for key, value in row.items()}


@lru_cache(maxsize=1)
def database_config() -> dict[str, Any]:
    secret_arn = os.getenv("DB_SECRET_ARN", "").strip()
    if secret_arn:
        region = os.getenv("AWS_REGION", os.getenv("AWS_DEFAULT_REGION", "ap-south-1"))
        client = boto3.client("secretsmanager", region_name=region)
        response = client.get_secret_value(SecretId=secret_arn)
        secret = json.loads(response["SecretString"])
        return {
            "host": os.environ["DB_HOST"],
            "port": int(os.getenv("DB_PORT", secret.get("port", 3306))),
            "database": os.getenv("DB_NAME", "taskflow"),
            "user": secret["username"],
            "password": secret["password"],
        }

    required = ["DB_HOST", "DB_USER", "DB_PASSWORD"]
    missing = [name for name in required if not os.getenv(name)]
    if missing:
        raise RuntimeError(f"Missing database environment variables: {', '.join(missing)}")

    return {
        "host": os.environ["DB_HOST"],
        "port": int(os.getenv("DB_PORT", "3306")),
        "database": os.getenv("DB_NAME", "taskflow"),
        "user": os.environ["DB_USER"],
        "password": os.environ["DB_PASSWORD"],
    }


def get_connection():
    config = database_config().copy()
    ssl_ca = os.getenv("DB_SSL_CA", "").strip()
    if ssl_ca:
        config["ssl_ca"] = ssl_ca
        config["ssl_verify_cert"] = True
        config["ssl_verify_identity"] = True

    return pymysql.connect(
        **config,
        cursorclass=DictCursor,
        autocommit=True,
        connect_timeout=5,
        read_timeout=10,
        write_timeout=10,
        charset="utf8mb4",
    )


def initialise_database(max_attempts: int = 30) -> None:
    schema = [
        """
        CREATE TABLE IF NOT EXISTS projects (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            name VARCHAR(120) NOT NULL,
            description TEXT NULL,
            status ENUM('planned','active','blocked','completed') NOT NULL DEFAULT 'planned',
            owner VARCHAR(120) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY uq_projects_name (name),
            INDEX idx_projects_status (status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        """,
        """
        CREATE TABLE IF NOT EXISTS tasks (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            project_id BIGINT UNSIGNED NOT NULL,
            title VARCHAR(180) NOT NULL,
            description TEXT NULL,
            priority ENUM('low','medium','high','critical') NOT NULL DEFAULT 'medium',
            status ENUM('todo','in_progress','review','done') NOT NULL DEFAULT 'todo',
            assignee VARCHAR(120) NULL,
            due_date DATE NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            CONSTRAINT fk_tasks_project FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
            INDEX idx_tasks_project (project_id),
            INDEX idx_tasks_status (status),
            INDEX idx_tasks_due_date (due_date)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        """,
        """
        CREATE TABLE IF NOT EXISTS activities (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            event_type VARCHAR(50) NOT NULL,
            entity_type VARCHAR(50) NOT NULL,
            entity_id BIGINT UNSIGNED NULL,
            message VARCHAR(255) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_activities_created_at (created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        """,
    ]

    for attempt in range(1, max_attempts + 1):
        try:
            with get_connection() as connection:
                with connection.cursor() as cursor:
                    for statement in schema:
                        cursor.execute(statement)
                    cursor.execute("SELECT GET_LOCK(%s, 30) AS acquired", ("taskflow-schema-seed",))
                    if cursor.fetchone()["acquired"] != 1:
                        raise RuntimeError("Could not acquire database seed lock")
                    try:
                        cursor.execute(
                            """
                            INSERT IGNORE INTO projects (name, description, status, owner)
                            VALUES (%s, %s, %s, %s)
                            """,
                            ("AWS Three-Tier Rollout", "Deploy and validate the production-style AWS platform.", "active", "Platform Team"),
                        )
                        project_created = cursor.rowcount == 1
                        cursor.execute("SELECT id FROM projects WHERE name = %s", ("AWS Three-Tier Rollout",))
                        project_id = cursor.fetchone()["id"]
                        seed_tasks = [
                            ("Validate load balancer health", "Confirm both AZ target groups are healthy.", "high", "in_progress", "DevOps", None),
                            ("Run RDS failover drill", "Execute during an approved test window.", "critical", "todo", "Database Team", None),
                            ("Restore DR backup", "Restore the copied snapshot in the DR Region.", "high", "todo", "Platform Team", None),
                        ]
                        for title, description, priority, status, assignee, due_date in seed_tasks:
                            cursor.execute(
                                "SELECT id FROM tasks WHERE project_id = %s AND title = %s LIMIT 1",
                                (project_id, title),
                            )
                            if cursor.fetchone() is None:
                                cursor.execute(
                                    """
                                    INSERT INTO tasks (project_id, title, description, priority, status, assignee, due_date)
                                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                                    """,
                                    (project_id, title, description, priority, status, assignee, due_date),
                                )
                        if project_created:
                            cursor.execute(
                                "INSERT INTO activities (event_type, entity_type, entity_id, message) VALUES (%s, %s, %s, %s)",
                                ("created", "project", project_id, "Initial AWS rollout project created"),
                            )
                    finally:
                        cursor.execute("SELECT RELEASE_LOCK(%s)", ("taskflow-schema-seed",))
            LOGGER.info("Database schema is ready")
            return
        except Exception as exc:  # noqa: BLE001
            LOGGER.warning("Database initialisation attempt %s/%s failed: %s", attempt, max_attempts, exc)
            if attempt == max_attempts:
                raise
            time.sleep(min(attempt * 2, 15))


def add_activity(cursor, event_type: str, entity_type: str, entity_id: Optional[int], message: str) -> None:
    cursor.execute(
        "INSERT INTO activities (event_type, entity_type, entity_id, message) VALUES (%s, %s, %s, %s)",
        (event_type, entity_type, entity_id, message[:255]),
    )


def require_json(required_fields: list[str]) -> dict[str, Any]:
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        raise ValueError("Request body must be a JSON object")
    missing = [field for field in required_fields if payload.get(field) in (None, "")]
    if missing:
        raise ValueError(f"Missing required fields: {', '.join(missing)}")
    return payload


def create_app() -> Flask:
    app = Flask(__name__)

    initialise_database()

    @app.get("/health")
    @app.get("/api/health")
    def health():
        try:
            with get_connection() as connection:
                with connection.cursor() as cursor:
                    cursor.execute("SELECT 1 AS ok")
                    cursor.fetchone()
            return jsonify({"status": "healthy", "service": "taskflow-api"})
        except Exception as exc:  # noqa: BLE001
            LOGGER.exception("Health check failed")
            return jsonify({"status": "unhealthy", "service": "taskflow-api"}), 503

    @app.get("/api/dashboard")
    def dashboard():
        with get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT COUNT(*) AS total FROM projects")
                project_total = cursor.fetchone()["total"]
                cursor.execute("SELECT status, COUNT(*) AS count FROM projects GROUP BY status")
                projects_by_status = {row["status"]: row["count"] for row in cursor.fetchall()}
                cursor.execute("SELECT COUNT(*) AS total FROM tasks")
                task_total = cursor.fetchone()["total"]
                cursor.execute("SELECT status, COUNT(*) AS count FROM tasks GROUP BY status")
                tasks_by_status = {row["status"]: row["count"] for row in cursor.fetchall()}
                cursor.execute("SELECT priority, COUNT(*) AS count FROM tasks GROUP BY priority")
                tasks_by_priority = {row["priority"]: row["count"] for row in cursor.fetchall()}
                cursor.execute("SELECT COUNT(*) AS count FROM tasks WHERE due_date < CURRENT_DATE AND status <> 'done'")
                overdue = cursor.fetchone()["count"]
        return jsonify(
            {
                "projects": {"total": project_total, "by_status": projects_by_status},
                "tasks": {"total": task_total, "by_status": tasks_by_status, "by_priority": tasks_by_priority, "overdue": overdue},
            }
        )

    @app.get("/api/projects")
    def list_projects():
        status = request.args.get("status", "").strip()
        query = """
            SELECT p.*, COUNT(t.id) AS task_count,
                   SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END) AS completed_task_count
            FROM projects p
            LEFT JOIN tasks t ON t.project_id = p.id
        """
        params: list[Any] = []
        if status:
            query += " WHERE p.status = %s"
            params.append(status)
        query += " GROUP BY p.id ORDER BY p.updated_at DESC"
        with get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(query, params)
                rows = [serialise_row(row) for row in cursor.fetchall()]
        return jsonify(rows)

    @app.post("/api/projects")
    def create_project():
        payload = require_json(["name", "owner"])
        with get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    "INSERT INTO projects (name, description, status, owner) VALUES (%s, %s, %s, %s)",
                    (payload["name"], payload.get("description"), payload.get("status", "planned"), payload["owner"]),
                )
                project_id = cursor.lastrowid
                add_activity(cursor, "created", "project", project_id, f"Project '{payload['name']}' created")
                cursor.execute("SELECT * FROM projects WHERE id = %s", (project_id,))
                row = serialise_row(cursor.fetchone())
        return jsonify(row), 201

    @app.get("/api/projects/<int:project_id>")
    def get_project(project_id: int):
        with get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT * FROM projects WHERE id = %s", (project_id,))
                project = cursor.fetchone()
                if not project:
                    return jsonify({"error": "Project not found"}), 404
                cursor.execute("SELECT * FROM tasks WHERE project_id = %s ORDER BY updated_at DESC", (project_id,))
                tasks = [serialise_row(row) for row in cursor.fetchall()]
        result = serialise_row(project)
        result["tasks"] = tasks
        return jsonify(result)

    @app.put("/api/projects/<int:project_id>")
    def update_project(project_id: int):
        payload = require_json(["name", "owner", "status"])
        with get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE projects SET name=%s, description=%s, status=%s, owner=%s
                    WHERE id=%s
                    """,
                    (payload["name"], payload.get("description"), payload["status"], payload["owner"], project_id),
                )
                if cursor.rowcount == 0:
                    cursor.execute("SELECT id FROM projects WHERE id = %s", (project_id,))
                    if cursor.fetchone() is None:
                        return jsonify({"error": "Project not found"}), 404
                add_activity(cursor, "updated", "project", project_id, f"Project '{payload['name']}' updated")
                cursor.execute("SELECT * FROM projects WHERE id = %s", (project_id,))
                row = serialise_row(cursor.fetchone())
        return jsonify(row)

    @app.delete("/api/projects/<int:project_id>")
    def delete_project(project_id: int):
        with get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT name FROM projects WHERE id = %s", (project_id,))
                project = cursor.fetchone()
                if not project:
                    return jsonify({"error": "Project not found"}), 404
                cursor.execute("DELETE FROM projects WHERE id = %s", (project_id,))
                add_activity(cursor, "deleted", "project", project_id, f"Project '{project['name']}' deleted")
        return "", 204

    @app.get("/api/tasks")
    def list_tasks():
        clauses = []
        params: list[Any] = []
        project_id = request.args.get("project_id", "").strip()
        status = request.args.get("status", "").strip()
        search = request.args.get("q", "").strip()
        if project_id:
            clauses.append("t.project_id = %s")
            params.append(project_id)
        if status:
            clauses.append("t.status = %s")
            params.append(status)
        if search:
            clauses.append("(t.title LIKE %s OR t.description LIKE %s OR t.assignee LIKE %s)")
            like = f"%{search}%"
            params.extend([like, like, like])
        query = """
            SELECT t.*, p.name AS project_name
            FROM tasks t JOIN projects p ON p.id = t.project_id
        """
        if clauses:
            query += " WHERE " + " AND ".join(clauses)
        query += " ORDER BY FIELD(t.priority, 'critical','high','medium','low'), t.updated_at DESC"
        with get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(query, params)
                rows = [serialise_row(row) for row in cursor.fetchall()]
        return jsonify(rows)

    @app.post("/api/tasks")
    def create_task():
        payload = require_json(["project_id", "title"])
        with get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT name FROM projects WHERE id = %s", (payload["project_id"],))
                if not cursor.fetchone():
                    return jsonify({"error": "Project not found"}), 404
                cursor.execute(
                    """
                    INSERT INTO tasks (project_id, title, description, priority, status, assignee, due_date)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        payload["project_id"], payload["title"], payload.get("description"),
                        payload.get("priority", "medium"), payload.get("status", "todo"),
                        payload.get("assignee"), payload.get("due_date") or None,
                    ),
                )
                task_id = cursor.lastrowid
                add_activity(cursor, "created", "task", task_id, f"Task '{payload['title']}' created")
                cursor.execute("SELECT * FROM tasks WHERE id = %s", (task_id,))
                row = serialise_row(cursor.fetchone())
        return jsonify(row), 201

    @app.put("/api/tasks/<int:task_id>")
    def update_task(task_id: int):
        payload = require_json(["project_id", "title", "priority", "status"])
        with get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE tasks
                    SET project_id=%s, title=%s, description=%s, priority=%s, status=%s, assignee=%s, due_date=%s
                    WHERE id=%s
                    """,
                    (
                        payload["project_id"], payload["title"], payload.get("description"), payload["priority"],
                        payload["status"], payload.get("assignee"), payload.get("due_date") or None, task_id,
                    ),
                )
                if cursor.rowcount == 0:
                    cursor.execute("SELECT id FROM tasks WHERE id = %s", (task_id,))
                    if cursor.fetchone() is None:
                        return jsonify({"error": "Task not found"}), 404
                add_activity(cursor, "updated", "task", task_id, f"Task '{payload['title']}' updated")
                cursor.execute("SELECT * FROM tasks WHERE id = %s", (task_id,))
                row = serialise_row(cursor.fetchone())
        return jsonify(row)

    @app.delete("/api/tasks/<int:task_id>")
    def delete_task(task_id: int):
        with get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT title FROM tasks WHERE id = %s", (task_id,))
                task = cursor.fetchone()
                if not task:
                    return jsonify({"error": "Task not found"}), 404
                cursor.execute("DELETE FROM tasks WHERE id = %s", (task_id,))
                add_activity(cursor, "deleted", "task", task_id, f"Task '{task['title']}' deleted")
        return "", 204

    @app.get("/api/activity")
    def list_activity():
        limit = min(max(int(request.args.get("limit", "20")), 1), 100)
        with get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT * FROM activities ORDER BY created_at DESC LIMIT %s", (limit,))
                rows = [serialise_row(row) for row in cursor.fetchall()]
        return jsonify(rows)

    @app.errorhandler(ValueError)
    def validation_error(error):
        return jsonify({"error": str(error)}), 400

    @app.errorhandler(IntegrityError)
    def integrity_error(error):
        LOGGER.info("Database constraint rejected request: %s", error)
        return jsonify({"error": "A record with the same unique value already exists"}), 409

    @app.errorhandler(Exception)
    def unhandled_error(error):
        LOGGER.exception("Unhandled request failure")
        return jsonify({"error": "Internal server error"}), 500

    return app
