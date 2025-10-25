# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-01-XX

### Added

- Initial release of AshWorkspace
- Workspace resource for multi-tenancy support
- WorkspaceUser join table with role-based access control
- Invitation system with secure token generation
- Email invitation delivery via Swoosh
- Configurable password validation
- Email uniqueness validation within workspaces
- Time-limited invitations (7 days default)
- Bcrypt token hashing for security
- Igniter-based installer for easy setup
- Comprehensive documentation and examples
- Support for custom email templates
- Support for custom invitation senders
- Support for custom roles
- Automatic workspace creation on user registration

### Features

- `AshWorkspace.Changes.SetToken` - Secure token generation
- `AshWorkspace.Changes.CreateDefaultWorkspace` - Auto-workspace creation
- `AshWorkspace.Validators.EmailUniquenessInWorkspace` - Prevent duplicate invitations
- `AshWorkspace.Validators.StrongPasswordValidation` - Password strength enforcement
- `AshWorkspace.Hooks.SendInvitationEmail` - Automatic email delivery
- `AshWorkspace.Senders.InvitationEmail` - Default email sender with templates

### Documentation

- Complete API documentation
- Installation guide
- Customization examples
- Security best practices
- Architecture diagrams

[Unreleased]: https://github.com/your-org/ash_workspace/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/your-org/ash_workspace/releases/tag/v0.1.0
