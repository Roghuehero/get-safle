# Automated Deployment, Scalability, and Monitoring of a Containerized Node.js Application

## Overview

This project automates the deployment, scalability, and monitoring of a containerized Node.js application using Terraform for infrastructure-as-code (IaC) and GitHub Actions for CI/CD. The infrastructure includes load balancing, auto-scaling, and monitoring with Prometheus and Grafana, along with security best practices.

## Features

- **Containerization**: The Node.js application is containerized using Docker.

- **Infrastructure as Code (IaC)**: Terraform is used to automate the provisioning of GCP infrastructure, including a load balancer, auto-scaling groups, and managed databases.

- **CI/CD Pipeline**: GitHub Actions pipeline automates building, testing, and deploying the Docker images to GCP. Changes pushed to the `main` branch trigger automatic deployment.

- **High Availability**: The infrastructure is designed to scale automatically based on traffic demand, with a load balancer distributing requests across multiple instances.

- **Monitoring**: Prometheus and Grafana are set up for monitoring key metrics like CPU usage, memory, and request rate. Alerts are triggered for specific metrics such as high CPU usage or downtime.

- **Centralized Logging**: ELK stack (Elasticsearch, Logstash, Kibana) is integrated for centralized logging and easy debugging.
- **Security**: HTTPS is implemented using Let's Encrypt, and SSH access is restricted through firewall rules. Sensitive information is securely managed via environment variables.


## Infrastructure

The infrastructure is built on GCP and includes:

- **Load Balancer**: Distributes traffic evenly across the auto-scaling instances of the Node.js application.

- **Auto-scaling Group**: Automatically scales the number of instances based on incoming traffic.

- **Managed Database**: Provides persistent storage for application data.

- **Monitoring Stack**: Prometheus for metrics collection and Grafana for visualization.

- **Logging**: Centralized logging using the ELK stack (Elasticsearch, Logstash, Kibana).

## Deployment

The deployment is fully automated using GitHub Actions. The CI/CD pipeline performs the following steps:

1. Build the Docker image for the Node.js application.
2. Push the Docker image to Google Artifact Registry.
3. Run unit tests to verify the integrity of the application.
4. Deploy the application to the infrastructure provisioned by Terraform.

Every push to the `main` branch triggers the pipeline, ensuring that the latest changes are deployed automatically.

## Monitoring and Alerts

Prometheus is configured to monitor metrics such as CPU usage, memory consumption, and request rates. Grafana dashboards provide visual insights into the application's performance. Alerts are set up for critical metrics, and notifications are sent via email or Slack in case of any issues.

## Security

- **HTTPS**: Configured using Let's Encrypt for secure communication.
- **SSH Access**: Restricted to specific IP addresses through firewall rules.
- **Environment Variables**: Sensitive information like API keys and credentials are stored securely using environment variables.

## Centralized Logging

The application logs are aggregated and managed using the ELK stack. Logs are searchable in Kibana, making debugging and monitoring easier.
