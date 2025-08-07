# GitHub Workflow Documentation

This document provides comprehensive documentation for all GitHub Actions workflows implemented for the VSM Phoenix Phase 2 release.

## Table of Contents

1. [Overview](#overview)
2. [Workflow Files](#workflow-files)
3. [CI/CD Pipeline](#cicd-pipeline)
4. [Release Management](#release-management)
5. [Security Scanning](#security-scanning)
6. [Documentation Generation](#documentation-generation)
7. [PR Automation](#pr-automation)
8. [Monitoring & Reporting](#monitoring--reporting)
9. [Configuration Files](#configuration-files)
10. [Usage Instructions](#usage-instructions)
11. [Best Practices](#best-practices)

## Overview

The VSM Phoenix project uses GitHub Actions for continuous integration, deployment, security scanning, and automation. These workflows support the Phase 2 release objectives:

- 🧠 Intelligent conversation management
- 🔒 Enhanced security features
- 🔗 Causality tracking implementation
- 🚀 Performance optimizations
- 🛡️ Resilience patterns

## Workflow Files

All workflow files are located in `.github/workflows/`:

- `ci-cd.yml` - Main CI/CD pipeline
- `release.yml` - Release management and deployment
- `security.yml` - Security scanning and vulnerability detection
- `documentation.yml` - Automated documentation generation
- `pr-automation.yml` - Pull request automation and management
- `monitoring.yml` - System monitoring and reporting

## CI/CD Pipeline

### File: `.github/workflows/ci-cd.yml`

The CI/CD pipeline runs on every push and pull request to main branches.

### Jobs:

1. **quality-checks**
   - Elixir formatting check
   - Credo static analysis
   - Dependency validation
   - Compilation with warnings as errors

2. **test-elixir**
   - Unit tests
   - Integration tests
   - Isolated tests
   - Test coverage reporting

3. **test-javascript**
   - JavaScript tests
   - Linting

4. **build-assets**
   - Production asset compilation
   - Asset optimization

5. **docker-build**
   - Multi-platform Docker images
   - Container registry push

6. **integration-tests**
   - End-to-end tests
   - VSM system validation
   - API testing

### Usage:

```bash
# Trigger manually
gh workflow run "CI/CD Pipeline"

# View recent runs
gh run list --workflow=ci-cd.yml
```

## Release Management

### File: `.github/workflows/release.yml`

Handles versioned releases and deployments.

### Features:

- Automated changelog generation
- Multi-platform release artifacts
- Docker image deployment
- GitHub release creation
- Version update PRs

### Triggering a Release:

```bash
# Create a release tag
git tag -a v2.0.0 -m "Phase 2 Release"
git push origin v2.0.0

# Or trigger manually
gh workflow run release.yml \
  -f version=v2.0.0 \
  -f prerelease=false \
  -f draft=true
```

## Security Scanning

### File: `.github/workflows/security.yml`

Comprehensive security scanning on every push and weekly schedule.

### Scans:

1. **Dependency vulnerabilities**
   - Elixir hex audit
   - npm audit
   - Outdated dependency detection

2. **Static analysis**
   - Sobelow security scanner
   - Secret detection
   - CodeQL analysis

3. **Container scanning**
   - Trivy vulnerability scanner
   - Grype analysis

4. **License compliance**
   - License compatibility checks

### Manual Security Scan:

```bash
gh workflow run "Security Scanning"
```

## Documentation Generation

### File: `.github/workflows/documentation.yml`

Automated documentation building and deployment.

### Features:

- ExDoc generation
- Module dependency graphs
- API documentation
- Architecture diagrams
- GitHub Pages deployment

### Viewing Documentation:

Documentation is automatically deployed to GitHub Pages:
`https://<username>.github.io/vsm-phoenix-app/`

## PR Automation

### File: `.github/workflows/pr-automation.yml`

Automates pull request management tasks.

### Features:

1. **Auto-labeling**
   - Size labels (XS, S, M, L, XL)
   - Component labels based on files
   - Conventional commit validation

2. **Review assignment**
   - Team-based code ownership
   - Automatic reviewer selection

3. **PR checklist**
   - Quality checklist
   - Testing requirements
   - Documentation updates

4. **Branch protection**
   - Naming convention enforcement
   - Base branch validation

5. **Metrics**
   - Change statistics
   - Review time estimates

## Monitoring & Reporting

### File: `.github/workflows/monitoring.yml`

System health monitoring and reporting.

### Reports:

1. **Code metrics**
   - Lines of code
   - Module count
   - Complexity analysis

2. **Performance monitoring**
   - Memory usage
   - Response times
   - VSM system health

3. **Dependency audit**
   - Outdated packages
   - Security vulnerabilities

4. **Workflow analytics**
   - Success rates
   - Average duration

### Schedule:

- Daily comprehensive reports
- Every 6 hours for metrics collection

### Manual Report Generation:

```bash
gh workflow run monitoring.yml -f report_type=all
```

## Configuration Files

### `.github/labeler.yml`

Configuration for automatic PR labeling based on file paths.

## Usage Instructions

### 1. Setting Up Workflows

All workflows are automatically active once merged to the repository.

### 2. Required Secrets

No additional secrets required - workflows use the default `GITHUB_TOKEN`.

### 3. Customization

Edit workflow files to customize:
- Trigger conditions
- Job configurations
- Tool versions
- Notification settings

### 4. Monitoring Workflow Status

```bash
# List all workflows
gh workflow list

# View specific workflow runs
gh run list --workflow="CI/CD Pipeline"

# Watch a running workflow
gh run watch
```

### 5. Debugging Failed Workflows

```bash
# View logs for a failed run
gh run view <run-id> --log-failed

# Re-run failed jobs
gh run rerun <run-id> --failed
```

## Best Practices

### 1. Branch Protection

Configure branch protection rules for main branches:
- Require PR reviews
- Require status checks to pass
- Enforce linear history
- Require branches to be up to date

### 2. Workflow Optimization

- Use job matrices for parallel testing
- Cache dependencies between runs
- Use artifacts for data sharing between jobs
- Implement proper timeout values

### 3. Security

- Never commit secrets to the repository
- Use GitHub Secrets for sensitive data
- Enable Dependabot for automatic updates
- Review security scan results regularly

### 4. Monitoring

- Check workflow analytics weekly
- Address failing workflows promptly
- Optimize long-running jobs
- Clean up old workflow runs

### 5. Documentation

- Update this document when adding new workflows
- Document any custom actions or scripts
- Keep workflow files well-commented
- Maintain changelog for workflow changes

## Troubleshooting

### Common Issues:

1. **Workflow not triggering**
   - Check trigger conditions
   - Verify branch names
   - Ensure proper permissions

2. **Test failures**
   - Check service dependencies
   - Verify environment variables
   - Review test logs

3. **Release failures**
   - Ensure proper tag format
   - Check permissions
   - Verify artifact generation

4. **Documentation build errors**
   - Check for syntax errors
   - Verify dependency installation
   - Review build logs

### Getting Help:

1. Check workflow logs for detailed error messages
2. Review GitHub Actions documentation
3. Open an issue with the `ci/cd` label
4. Contact the DevOps team

---

## Workflow Maintenance

### Monthly Tasks:

- Review and update deprecated actions
- Check for new security vulnerabilities
- Optimize workflow performance
- Update documentation

### Quarterly Tasks:

- Audit workflow permissions
- Review and clean up old artifacts
- Update tool versions
- Performance benchmarking

---

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>