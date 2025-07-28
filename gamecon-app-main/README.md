# GameCon App

> A Flask-based game management application demonstrating modern DevOps practices including containerization, CI/CD pipelines, monitoring, and GitOps deployment workflows.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [CI/CD Pipeline](#cicd-pipeline)
- [Acknowledgments](#acknowledgments)

## Overview

GameCon App is a comprehensive web application for managing game collections that showcases enterprise-grade DevOps practices. The project demonstrates full-stack development with automated testing, security scanning, quality analysis, and cloud deployment using modern containerization and GitOps principles.

Key features:

- **Full CRUD Operations** - Create, read, update, and delete game entries with cover images
- **Enterprise Monitoring** - Prometheus metrics, structured logging, and health checks
- **Security-First Approach** - Bandit security scanning.
- **Cloud-Native Deployment** - Docker containerization with AWS ECR.
- **Automated Quality Assurance** - Unit testing, coverage analysis, and SonarQube integration

## Architecture

The application follows a microservices architecture pattern with containerized components, reverse proxy setup, and cloud-native deployment practices. The CI/CD pipeline implements GitOps principles for automated deployment and infrastructure management.


![Architecture](architecture/CI-Flow.png)
 

## Technology Stack

| Category             | Technologies   |
| -------------------- | -------------- |
| **Infrastructure**   | Docker, Docker Compose, AWS ECR, Jenkins |
| **Containerization** | Docker Multi-stage builds, Alpine Linux |
| **CI/CD**            | Jenkins Pipeline, GitLab, GitOps |
| **Version Control**  | Git, GitLab, Semantic Versioning |
| **Security**         | Bandit|
| **Application**      | Flask, Python 3.11, Jinja2, SQLAlchemy |
| **Database**         | PostgreSQL 16, psycopg2 |
| **Monitoring**       | Prometheus, Structured JSON Logging |
| **Quality**          | SonarQube, pytest, Coverage.py |
| **Web Server**       | Nginx, Static Asset Optimization |

## Repository Structure

```
GameCon-App/
├── app/                   # Main application code
│   ├── app.py             # Flask application factory with logging
│   ├── routes.py          # API routes and business logic
│   ├── models.py          # SQLAlchemy database models
│   └── config.py          # Environment-based configuration
├── templates/             # Jinja2 HTML templates
│   ├── index.html         # Game listing page
│   ├── create_game.html   # Game creation form
│   ├── edit_game.html     # Game editing interface
│   └── game_detail.html   # Individual game view
├── static/                # Static web assets
│   ├── style.css          # Responsive CSS styling
│   └── scripts.js         # Client-side JavaScript
├── tests/                 # Comprehensive test suite
│   ├── test_basic.py      # Unit and integration tests
│   └── e2e_tests.sh       # End-to-end testing script
├── scripts/               # DevOps automation scripts
│   ├── code-coverage.sh   # Coverage analysis automation
│   └── sonarqube-analysis.sh # Code quality scanning
├── docker-compose.yml     # Multi-container orchestration
├── Dockerfile             # Application container definition
├── Dockerfile.nginx       # Nginx reverse proxy container
├── Jenkinsfile           # Complete CI/CD pipeline definition
└── requirements.txt      # Python dependency management
```

## Prerequisites

Requirements for building and running the project:

- **Docker** (version 20.0+) and Docker Compose (v2.0+)
- **Python** 3.11+ (for local development)
- **Git** (version 2.0+)
- **Jenkins** (for CI/CD pipeline)
- **AWS CLI** (for ECR integration)

## Getting Started

Follow these instructions to set up the project locally and deploy it to your cloud environment.

### Infrastructure Setup

1. **Clone the Repository**

```bash
# Clone the GameCon App repository
git clone https://github.com/ShobashAndi/GameCon-App.git
cd GameCon-App
```

2. **Configure Environment Variables**

```bash
# Create environment configuration
cp .env.example .env
# Edit .env with your specific configuration
```

Expected configuration:

```env
POSTGRES_USER=flaskuser
POSTGRES_PASSWORD=flaskpass
POSTGRES_DB=flaskdb
DATABASE_URL=postgresql://flaskuser:flaskpass@postgres_db/flaskdb
ENVIRONMENT=production
LOG_LEVEL=INFO
```

3. **Build and Start Services**

```bash
# Build all containers and start the application stack
docker compose up -d --build
```

### Application Deployment

1. **Verify Service Health**

```bash
# Check all containers are running
docker compose ps
# Test application health endpoint
curl http://localhost/health
```

2. **Access the Application**

```bash
# Open browser to application
open http://localhost
# Or check specific endpoints
curl http://localhost/metrics  # Prometheus metrics
```

3. **Run Test Suite**

```bash
# Execute comprehensive test suite
chmod +x scripts/code-coverage.sh
./scripts/code-coverage.sh
```

Expected result: All services running with green health checks, application accessible on port 80.

## CI/CD Pipeline

The Jenkins pipeline implements a comprehensive DevOps workflow with automated testing, security scanning, quality analysis, and GitOps deployment. Each stage includes proper error handling and notification systems.

```mermaid
graph LR
    A[Checkout] --> B[Build Images + Package]
    B --> C[Unit Tests]
    C --> D[Unit Testing]
    D --> E[SonarQube Analysis]
    E --> F[Security Scanning]
    F --> G[E2E Tests]
    G --> H[Semantic Versioning]
    H --> I[Push to ECR]
    I --> J[Git Tagging]
    J --> K[GitOps Update]
    K --> M[Report]
```

**Pipeline Stages:**
- **Checkout Repository**: Code retrieval with commit info extraction
- **Build**: Multi-stage Docker builds with optimization
- **Unit Testing**: pytest execution with coverage reporting
- **Code Coverage**: Coverage analysis with SonarQube integration
- **SonarQube Analysis**: Code quality and security analysis
- **Security Testing**: Bandit static security analysis
- **E2E Testing**: Comprehensive end-to-end test automation
- **Versioning**: Automatic semantic version incrementation
- **ECR Push**: Container image publishing to AWS ECR
- **Git Tagging**: Release tag creation and pushing
- **GitOps Update**: Automated deployment configuration updates

## Acknowledgments

- **Flask Community** for providing an excellent web framework foundation
- **Docker Team** for revolutionizing application containerization
- **PostgreSQL Development Group** for robust database technology
- **Jenkins Project** for powerful CI/CD automation capabilities
- **Prometheus Community** for comprehensive monitoring solutions
- **GitLab** for integrated DevOps platform and source control
- **AWS** for reliable cloud infrastructure and container registry services
