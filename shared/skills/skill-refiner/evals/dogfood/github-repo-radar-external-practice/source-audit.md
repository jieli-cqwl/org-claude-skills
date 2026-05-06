# github-repo-radar external best-practice source audit

Collected at: 2026-05-05 America/Los_Angeles

Purpose: prove the github-repo-radar shadow run consumes external best-practice sources across SR-R1~SR-R10, not only Flow.

## Source Classes

### official

- GitHub Docs: Best practices for repositories  
  https://docs.github.com/en/enterprise-cloud@latest/repositories/creating-and-managing-repositories/best-practices-for-repositories  
  Used for README, license, contribution guidance, code of conduct, security features, branch/protection expectations, and repository management basics.
- GitHub Docs: Setting up your project for healthy contributions  
  https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions  
  Used for CONTRIBUTING, license, code of conduct, support resources, community health file, and contribution labels.
- GitHub Docs: GitHub security features  
  https://docs.github.com/en/code-security/getting-started/github-security-features  
  Used for security signal expectations: Dependabot, secret scanning, push protection, code scanning, SECURITY.md, and private vulnerability reporting.

### github

- GitHub Docs source: searching for repositories  
  https://github.com/github/docs/blob/main/content/search-github/searching-on-github/searching-for-repositories.md  
  Used for query qualifiers: in, repo, user/org, forks, stars, pushed, language, topic, license, mirror, archived, good-first-issues, help-wanted-issues.
- OpenSSF Scorecard repository  
  https://github.com/ossf/scorecard  
  Used as inspectable GitHub-hosted source for automated security heuristics and structured results.
- OpenSSF Scorecard checks documentation  
  https://github.com/ossf/scorecard/blob/main/docs/checks.md  
  Used for concrete check families: Maintained, Branch-Protection, CI-Tests, Code-Review, Contributors, Security-Policy, Vulnerabilities, SAST, Pinned-Dependencies, Signed-Releases.

### community

- CHAOSS metrics repository  
  https://github.com/chaoss/metrics  
  Used for implementation-agnostic open source community health metrics and governance/community-health vocabulary.
- Linux Foundation Research: Recommended Practices for Hosting and Managing Open Source Projects on GitHub  
  https://www.linuxfoundation.org/research/hosting-os-projects-on-github  
  Used for documentation, user support, security, licensing, language, peer review, release cadence, CI, DCO, and CLA considerations.
- Linux Foundation infographic: Recommended Practices for Hosting and Managing Open Source Projects on Github  
  https://www.linuxfoundation.org/hubfs/LF%20Research/Recommended%20Practices%20for%20Hosting%20and%20Managing%20OS%20Projects%20on%20Github%20-%20Infographic.pdf?hsLang=en  
  Used to cross-check the LF report topics in a compact artifact.

## Ring Consumption Matrix

SR-R1~SR-R10 all consume official, GitHub, and community source classes.

| Ring | official | github | community |
| --- | --- | --- | --- |
| Trigger | GitHub Docs repo/community/security | github/docs search + ossf/scorecard | CHAOSS + Linux Foundation |
| Responsibility | GitHub Docs repo/community/security | github/docs search + ossf/scorecard | CHAOSS + Linux Foundation |
| Input | GitHub Docs repo/community/security | github/docs search + ossf/scorecard | CHAOSS + Linux Foundation |
| Flow | GitHub Docs repo/community/security | github/docs search + ossf/scorecard | CHAOSS + Linux Foundation |
| Output | GitHub Docs repo/community/security | github/docs search + ossf/scorecard | CHAOSS + Linux Foundation |
| Resource | GitHub Docs repo/community/security | github/docs search + ossf/scorecard | CHAOSS + Linux Foundation |
| Determinism | GitHub Docs repo/community/security | github/docs search + ossf/scorecard | CHAOSS + Linux Foundation |
| Eval | GitHub Docs repo/community/security | github/docs search + ossf/scorecard | CHAOSS + Linux Foundation |
| Cleanup | GitHub Docs repo/community/security | github/docs search + ossf/scorecard | CHAOSS + Linux Foundation |
| Runtime | GitHub Docs repo/community/security | github/docs search + ossf/scorecard | CHAOSS + Linux Foundation |

## Conflict Handling

Scorecard total is never treated as a single verdict. Stars, Trending, README quality, downloads, release cadence, and community metrics are treated as signals that must be challenged by purpose fit, license, maintenance, security, adoption, and exit-path checks.
