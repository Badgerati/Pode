# PowerShell Support Policy

## Overview
This document details the support policy for PowerShell versions as they relate to Pode releases. Our aim is to provide clarity on which versions of PowerShell are supported by each release of Pode, ensuring a secure, efficient, and compatible development environment.

## Policy Statement
Pode commits to supporting PowerShell versions that are not end of life (EOL) at the moment of each Pode release. This dynamic approach allows Pode to adapt to the evolving PowerShell ecosystem, ensuring compatibility with recent and supported PowerShell versions while maintaining a high security standard.

### Support Lifecycle
- For each Pode release, support is extended to versions of PowerShell that are not EOL at the time of release.
- Subsequent Pode releases may not support previously compatible PowerShell versions if those versions have reached EOL in the interim.
- This policy applies to all versions of PowerShell, including PowerShell (version 7.x), PowerShell Core (versions 6.x) and Windows PowerShell 5.1.
- Windows Powershell 5.1 will be supported by any Pode version released prior the Jan 7 2027

### Example
- **Pode 2.10 Release (April 2024)**: Supports PowerShell 7.2, 7.3, 7.4, and Windows PowerShell 5.1, assuming none are EOL at the time of release.
- **Pode 2.11 Release (Late 2024)**: With PowerShell 7.2 and 7.3 reaching EOL, support for these versions would be discontinued. Pode 2.11 would then support PowerShell Core 7.4 and any newer, non-EOL versions, along with Windows PowerShell 5.1.

## Testing Strategy
Pode is tested against the PowerShell versions it supports at the time of each release. Testing focuses on ensuring compatibility with non-EOL versions of PowerShell, reflecting the policy stated above.

## Warning Mechanism
A warning mechanism within Pode detects the PowerShell version in use at runtime. If a version no longer supported by the current release of Pode is detected—due to reaching EOL—a warning will be issued, advising on the potential risks and recommending an update to a supported version.

## Version Updates and Communication
Updates to the PowerShell version support policy will be documented in Pode’s release notes and official documentation. Users are encouraged to review these sources to stay informed about which PowerShell versions are supported by their version of Pode.

## Feedback and Contributions
Feedback on Pode's PowerShell version support policy is invaluable. We welcome suggestions and contributions from our community to help refine and improve our approach. Please share your thoughts through our GitHub repository or community forums.

