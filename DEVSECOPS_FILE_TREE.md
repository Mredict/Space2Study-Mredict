# DevSecOps File Tree

Complete file structure of all DevSecOps-related files in the Space2Study monorepo.

```
Space2Study-Monorepo/
├── sonar-project.properties    
├── docker-compose.yml                    # Orchestrates multi-container deployment
├── Jenkinsfile                           # CI/CD pipeline definition
├── devops/
│   ├── configuration_management/
│   │   └── ansible/
│   │       ├── agent.yml
│   │       ├── app.yml
│   │       ├── ansible.cfg
│   │       ├── deploy-app.yml
│   │       ├── jenkins.yml
<!-- │   │       ├── site.yml
│   │       ├── inventories/
│   │       │   └── local/
│   │       │       ├── hosts.ini
│   │       │       └── group_vars/
│   │       │           ├── backend/
│   │       │           │   ├── backend.yml
│   │       │           │   ├── secrets.yml
│   │       │           │   └── secrets.yml.example
│   │       │           └── frontend/
│   │       │               └── frontend.yml --> this block used for local deploy without CI/CD and Dockerization skip it
│   │       └── roles/
│   │           ├── agent_setup/
│   │           │   ├── handlers/
│   │           │   │   └── main.yml
│   │           │   └── tasks/
│   │           │       └── main.yml
<!-- │   │           ├── backend/
│   │           │   ├── tasks/
│   │           │   │   └── main.yml
│   │           │   └── templates/
│   │           │       └── backend-env.j2 --> this block used for local deploy without CI/CD and Dockerization skip it
│   │           ├── common/
│   │           │   └── tasks/
│   │           │       └── main.yml
<!-- │   │           ├── database/
│   │           │   ├── handlers/
│   │           │   │   └── main.yml
│   │           │   ├── tasks/
│   │           │   │   └── main.yml
│   │           │   └── templates/
│   │           │       └── mongod.conf.j2 --> this block used for local deploy without CI/CD and Dockerization skip it
│   │           ├── docker_setup/
│   │           │   ├── handlers/
│   │           │   │   └── main.yml
│   │           │   └── tasks/
│   │           │       └── main.yml
<!-- │   │           ├── frontend/
│   │           │   ├── tasks/
│   │           │   │   └── main.yml
│   │           │   └── templates/
│   │           │       ├── frontend-env.j2
│   │           │       └── nginx.conf.j2 --> this block used for local deploy without CI/CD and Dockerization skip it
│   │           ├── jenkins_setup/
│   │           │   └── tasks/
│   │           │       └── main.yml
│   │           └── sonarqube_setup/
│   │           |    └── tasks/
│   │           |       └── main.yml
│   │           ├── monitoring_server/
│   │           │   └── tasks/
│   │           │   |   └── main.yml
│   │           │   └── templates/
│   │           │       ├── docker-compose.yml.j2
│   │           │       └── prometheus.yml.j2
│   │           └── monitoring_agent/
│   │               └── tasks/
│   │               |   └── main.yml
│   │               └── templates/
│   │                  ├── docker-compose.yml.j2
│   │                  └── promtail-config.yml.j2
│   ├── infrastructure/
│   │   ├── with_docker/
│   │   │   ├── Vagrantfile
│   │   │   └── .vagrant/
<!-- │   │   └── without_docker/
│   │       ├── Vagrantfile
│   │       └── .vagrant/ --> this block used for local deploy without CI/CD and Dockerization skip it
│   └── loadbalancer/
│       └── nginx-lb.conf
├── backend/
│   ├── Dockerfile                        # Containerizes backend application
│   ├── .dockerignore                     # Files to exclude from Docker build
│   ├── .env
│   ├── .env.example
│   ├── .gitignore
└── frontend/
    ├── Dockerfile                        # Containerizes frontend application
    ├── .dockerignore                     # Files to exclude from Docker build
    ├── nginx.conf                        # Nginx configuration for production
    ├── .env
    ├── .env.example
    ├── .gitignore
```


                      [ HTTPS (443) ]
                             │
                      ┌──────▼──────┐
                      │   AWS WAF   │
                      └──────┬──────┘
                             │
                     ┌───────▼───────┐
                     │  Public Subnet│
                     │      ALB      │
                     └──┬─────────┬──┘
                        │ /       │ /api/*
       ┌────────────────┘         └────────────────┐
       │ (Port 8080)                               │ (Port 8080)
┌──────▼─────────────────────┐     ┌───────────────▼────────────┐
│ Private Subnet             │     │ Private Subnet             │
│ ECS Service: Frontend      │     │ ECS Service: Backend       │
│ (React - Nginx unpriv)     │     │ (Node.js - 3 Replicas)     │
└────────────────────────────┘     └───────────────┬────────────┘
                                                   │ (Port 27017)
                                   ┌───────────────▼────────────┐
                                   │ Database Isolated Subnet   │
                                   │ DocumentDB / Managed Mongo │
                                   └────────────────────────────┘