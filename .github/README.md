# GitHub Actions & Automation

This directory contains all GitHub Actions workflows and configuration files for the VSM Phoenix project.

## Quick Links

- [Workflow Documentation](WORKFLOW_DOCUMENTATION.md) - Comprehensive guide to all workflows
- [GitHub Actions](https://github.com/features/actions) - Official GitHub Actions documentation

## Workflows

### Core Workflows

1. **CI/CD Pipeline** (`workflows/ci-cd.yml`)
   - Runs on every push and PR
   - Quality checks, testing, and building
   - Multi-environment support

2. **Release Management** (`workflows/release.yml`)
   - Automated release creation
   - Changelog generation
   - Multi-platform builds

3. **Security Scanning** (`workflows/security.yml`)
   - Vulnerability detection
   - License compliance
   - Container scanning

### Automation Workflows

4. **Documentation** (`workflows/documentation.yml`)
   - Auto-generates documentation
   - Deploys to GitHub Pages
   - Creates architecture diagrams

5. **PR Automation** (`workflows/pr-automation.yml`)
   - Auto-labeling
   - Review assignment
   - Branch protection

6. **Monitoring** (`workflows/monitoring.yml`)
   - System health checks
   - Performance metrics
   - Automated reporting

## Configuration Files

- `labeler.yml` - PR auto-labeling rules
- `dependabot.yml` - Automated dependency updates

## Quick Start

### Running Workflows Manually

```bash
# List all workflows
gh workflow list

# Run a specific workflow
gh workflow run "CI/CD Pipeline"

# View workflow runs
gh run list
```

### Creating a Release

```bash
# Tag and push
git tag -a v2.0.0 -m "Release v2.0.0"
git push origin v2.0.0

# Or use workflow dispatch
gh workflow run release.yml -f version=v2.0.0
```

### Monitoring Status

Check workflow status badges in the main README or visit the Actions tab in GitHub.

## Contributing

When adding new workflows:

1. Follow the existing naming convention
2. Document the workflow in WORKFLOW_DOCUMENTATION.md
3. Add appropriate permissions
4. Test thoroughly before merging

## Support

For issues with workflows:
1. Check the workflow logs
2. Review the documentation
3. Open an issue with the `ci/cd` label

---

🤖 Maintained by VSM Phoenix Team