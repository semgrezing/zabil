# PROJECT_OVERVIEW.md

```md
# Project Overview

## Project Goal
Collaborative notes MVP application for:
- Android (APK)
- Windows Desktop (.exe)

Main goal:
Create the cheapest, fastest and maintainable MVP for ~20 users.

---

# Tech Stack

## Frontend
- Flutter
- Riverpod
- go_router
- Dio

## Backend
- Node.js
- Fastify
- PostgreSQL
- Prisma ORM
- JWT Authentication

## Deployment
- Ubuntu 24.04 VPS
- Docker
- Docker Compose
- Nginx
- Let's Encrypt SSL

---

# Main Features

## Authentication
- Username + password
- JWT auth
- Refresh tokens

## Groups
- Create groups
- Invite users by username
- Accept invitations

## Notes
- Text notes
- Checklists
- Image uploads
- Search notes
- Archive notes

---

# Non Goals (NOT MVP)

- Realtime collaboration
- WebSockets
- Push notifications
- OAuth
- Telegram login
- Roles system
- Comments
- Version history
- Offline mode
- Microservices
- Kubernetes
- GraphQL

---

# Main Priorities

1. Simplicity
2. Fast development
3. Low server cost
4. Easy maintenance
5. Production-ready MVP
6. Future scalability

---

# Architecture

- Modular monolith backend
- REST API
- Shared PostgreSQL database
- Local image storage
- Single VPS deployment

---

# Expected Scale

- ~20 active users
- Low traffic
- Small image uploads

---

# Design Style

- Notion-style minimalist UI
- Dark mode
- Light mode
- Russian language only
```

---

# ARCHITECTURE.md

```md
# System Architecture

## Overview

System consists of:

1. Flutter Client
2. Node.js Backend API
3. PostgreSQL Database
4. Local File Storage
5. Nginx Reverse Proxy

---

# Frontend Architecture

## Stack
- Flutter
- Riverpod
- go_router
- Dio

## Structure

/lib
    /core
    /features
    /shared
    /services
    /widgets
    /theme
    main.dart

---

# Feature Structure

/features/auth
/features/notes
/features/groups
/features/invitations
/features/search
/features/settings

Each feature contains:
- screens
- widgets
- providers
- models
- repositories
- services

---

# Backend Architecture

## Pattern
Modular monolith.

## Stack
- Fastify
- Prisma
- PostgreSQL
- JWT
- Zod validation

---

# Backend Structure

/src
    /modules
        /auth
        /users
        /groups
        /notes
        /uploads
        /invitations
    /plugins
    /middleware
    /utils
    /config
    app.ts
    server.ts

---

# API Style

- REST API only
- JSON responses
- Consistent error format

---

# File Upload Flow

Client -> API -> Validation -> Compression -> Local Storage -> DB Record

---

# Security

- bcrypt password hashing
- JWT auth
- Rate limiting
- Upload validation
- File type validation
- HTTPS only

---

# Deployment

Single VPS deployment:

- nginx
- backend
- postgres

via Docker Compose.
```

---

# DATABASE_SCHEMA.md

```md
# Database Schema

## users

Purpose:
Application users.

Columns:
- id UUID PK
- username VARCHAR UNIQUE
- password_hash TEXT
- created_at TIMESTAMP
- updated_at TIMESTAMP

Indexes:
- unique username index

---

## groups

Purpose:
User groups.

Columns:
- id UUID PK
- title VARCHAR
- created_by UUID FK users.id
- created_at TIMESTAMP
- updated_at TIMESTAMP

---

## group_members

Purpose:
Group membership.

Columns:
- id UUID PK
- group_id UUID FK groups.id
- user_id UUID FK users.id
- role VARCHAR DEFAULT 'member'
- joined_at TIMESTAMP

Indexes:
- unique group/user pair

---

## invitations

Purpose:
Group invitations.

Columns:
- id UUID PK
- group_id UUID FK groups.id
- sender_id UUID FK users.id
- receiver_id UUID FK users.id
- status VARCHAR
- created_at TIMESTAMP

Statuses:
- pending
- accepted
- declined

---

## notes

Purpose:
Shared notes.

Columns:
- id UUID PK
- group_id UUID FK groups.id
- created_by UUID FK users.id
- title VARCHAR
- content TEXT
- archived BOOLEAN DEFAULT false
- created_at TIMESTAMP
- updated_at TIMESTAMP
- deleted_at TIMESTAMP NULL

Indexes:
- group_id
- archived

---

## note_checklist_items

Purpose:
Checklist items.

Columns:
- id UUID PK
- note_id UUID FK notes.id
- text VARCHAR
- completed BOOLEAN DEFAULT false
- position INTEGER
- created_at TIMESTAMP

---

## note_images

Purpose:
Stored note images.

Columns:
- id UUID PK
- note_id UUID FK notes.id
- filename VARCHAR
- original_name VARCHAR
- mime_type VARCHAR
- file_size INTEGER
- path TEXT
- created_at TIMESTAMP
```

---

# API_SPEC.md

```md
# API Specification

Base URL:
/api/v1

---

# AUTH

## POST /auth/register

Request:
{
  "username": "alex",
  "password": "12345678"
}

Response:
{
  "user": {},
  "accessToken": "",
  "refreshToken": ""
}

---

## POST /auth/login

Request:
{
  "username": "alex",
  "password": "12345678"
}

Response:
{
  "accessToken": "",
  "refreshToken": ""
}

---

# USERS

## GET /users/search?username=alex

Auth required.

Response:
{
  "user": {
    "id": "",
    "username": "alex"
  }
}

---

# GROUPS

## POST /groups

Request:
{
  "title": "Work"
}

---

## GET /groups

Returns current user groups.

---

# INVITATIONS

## POST /invitations

Request:
{
  "groupId": "",
  "username": "alex"
}

---

## POST /invitations/:id/accept

---

## POST /invitations/:id/decline

---

# NOTES

## GET /notes

Query params:
- search
- archived
- groupId

---

## POST /notes

Request:
{
  "groupId": "",
  "title": "",
  "content": ""
}

---

## PATCH /notes/:id

---

## POST /notes/:id/archive

---

# UPLOADS

## POST /uploads/note-image

Multipart form-data.

Validation:
- images only
- max 50MB

Allowed:
- jpg
- jpeg
- png
- webp
```

---

# FRONTEND_STRUCTURE.md

```md
# Frontend Structure

## State Management

Use Riverpod.

Reason:
- simple
- scalable
- modern
- less boilerplate than Bloc

---

# Navigation

Use go_router.

---

# Main Screens

/auth
/main
/notes
/note-editor
/search
/invitations
/groups
/settings

---

# Shared Widgets

/widgets
    app_button.dart
    app_input.dart
    app_card.dart
    app_loader.dart
    app_modal.dart

---

# Theme

/theme
    app_colors.dart
    app_theme.dart
    typography.dart

---

# API Layer

/services
    api_client.dart
    auth_service.dart
    notes_service.dart
    groups_service.dart

---

# Rules

- No business logic inside widgets
- Reusable UI components
- Consistent spacing
- Responsive desktop support
```

---

# UI_GUIDELINES.md

```md
# UI Guidelines

## Style

Minimalistic Notion-style UI.

---

# Colors

Use neutral palette.

Avoid:
- bright gradients
- neon colors
- excessive shadows

---

# Border Radius

Use medium rounded corners.

---

# Spacing

Consistent spacing system:
- 4
- 8
- 12
- 16
- 24
- 32

---

# Typography

Readable modern sans-serif.

Hierarchy:
- H1
- H2
- Body
- Caption

---

# Cards

Use clean flat cards.

---

# Dark Mode

Required.

---

# Light Mode

Required.

---

# Animations

Minimal subtle animations only.
```

---

# DEVELOPMENT_RULES.md

```md
# Development Rules

## Main Principle

Always prefer simplicity over abstraction.

---

# Forbidden

Do NOT introduce:
- microservices
- CQRS
- DDD
- event bus
- GraphQL
- repositories unless necessary
- massive abstractions
- overengineering

---

# Backend Rules

- Validate all input
- Use DTO validation
- Keep services small
- No inline SQL
- No duplicated logic
- Use environment variables

---

# Frontend Rules

- No business logic in widgets
- Reuse components
- Keep screens clean
- Avoid deeply nested widgets

---

# File Rules

- Max reasonable file size: ~300 lines
- Split complex widgets
- Clear naming

---

# Naming

Use explicit readable naming.

Avoid abbreviations.

---

# Comments

Only comment complex logic.

---

# Goal

Readable maintainable MVP code.
```

---

# DEPLOYMENT.md

```md
# Deployment Guide

## VPS

Recommended:
- Ubuntu 24.04
- 2 CPU
- 2 GB RAM
- 50 GB SSD

---

# Docker Services

- nginx
- backend
- postgres

---

# Domains

Example:
- api.domain.com
- updates.domain.com

---

# HTTPS

Use Let's Encrypt.

---

# Backups

Daily PostgreSQL backups.

---

# Uploads

Store uploads locally:
/uploads

---

# Nginx

Responsibilities:
- SSL termination
- reverse proxy
- static uploads
- update files hosting

---

# Auto Updates

Windows app checks:
/update.json

If newer version exists:
- download installer
- prompt update
```

---

# SECURITY.md

```md
# Security

## Authentication

- bcrypt hashing
- JWT access token
- refresh token
- token expiration

---

# API Security

- rate limiting
- CORS
- input validation
- SQL injection protection

---

# Upload Security

- validate MIME types
- validate extensions
- max 50MB
- image-only uploads
- generate unique filenames

---

# Password Rules

Minimum:
- 8 characters

---

# Secrets

Never hardcode:
- JWT secret
- DB credentials
- API keys
```

---

# FILE_UPLOADS.md

```md
# File Uploads

## Allowed Types

- jpg
- jpeg
- png
- webp

---

# Maximum Size

50 MB

---

# Storage

/uploads/notes
/uploads/users

---

# Filename Strategy

Use UUID filenames.

Never trust original filename.

---

# Compression

Compress large images.

Use Sharp.

---

# Validation

Validate:
- MIME type
- extension
- size

---

# Security

Never execute uploaded files.
```

---

# ENVIRONMENT_VARIABLES.md

```md
# Environment Variables

NODE_ENV=
PORT=
DATABASE_URL=
JWT_SECRET=
JWT_REFRESH_SECRET=
CORS_ORIGIN=
UPLOADS_PATH=
MAX_UPLOAD_SIZE=

---

# Production Example

NODE_ENV=production
PORT=3000
MAX_UPLOAD_SIZE=52428800
```

---

# ROADMAP.md

```md
# MVP

- Authentication
- Groups
- Invitations
- Notes
- Checklists
- Image uploads
- Search
- Archive
- Docker deployment

---

# Post-MVP

- Roles system
- Telegram login
- Push notifications
- Realtime collaboration
- Offline mode
- Markdown
- Comments
- Version history
```

---

# TASKS.md

```md
# Backend

- [ ] Initialize Fastify project
- [ ] Setup Prisma
- [ ] Create PostgreSQL schema
- [ ] Auth module
- [ ] Users module
- [ ] Groups module
- [ ] Invitations module
- [ ] Notes module
- [ ] Upload module
- [ ] Docker setup
- [ ] Nginx setup

---

# Frontend

- [ ] Initialize Flutter app
- [ ] Setup Riverpod
- [ ] Setup go_router
- [ ] Authentication screens
- [ ] Main navigation
- [ ] Notes list
- [ ] Note editor
- [ ] Image upload UI
- [ ] Search screen
- [ ] Invitations screen
- [ ] Settings screen
- [ ] Dark theme
- [ ] Light theme

---

# Deployment

- [ ] Buy VPS
- [ ] Setup Ubuntu
- [ ] Configure Docker
- [ ] Configure SSL
- [ ] Setup domain
- [ ] Deploy backend
- [ ] Deploy database
- [ ] Release APK
- [ ] Build Windows .exe
```

---

# CLAUDE_CONTEXT.md

```md
# Claude Instructions

Always prioritize:
- simplicity
- readability
- maintainability
- fast MVP delivery

---

# Avoid

Do NOT introduce:
- microservices
- CQRS
- DDD
- event sourcing
- repository pattern unless truly necessary
- complex abstractions
- excessive interfaces
- premature optimization

---

# Preferred Style

Prefer:
- explicit naming
- small services
- clean REST APIs
- pragmatic architecture
- modular monolith

---

# Project Context

This is a small MVP for ~20 users.

Main goals:
- low cost
- fast delivery
- easy maintenance
- production-ready basics

---

# Frontend

Use:
- Riverpod
- go_router
- reusable widgets
- responsive layout

---

# Backend

Use:
- Fastify
- Prisma
- PostgreSQL
- Zod validation

---

# Code Style

- readable over clever
- simple over abstract
- consistency over experimentation
```

