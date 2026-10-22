# Trivy exceptions

CI fails on new HIGH or CRITICAL findings. These files contain temporary,
scoped exceptions for findings that already exist in the pinned images and
manifests. They are not a global ignore list.

| File | Applies to | Scope |
| --- | --- | --- |
| `repo.yaml` | `trivy fs` scan | Existing result dependencies and intentional EKS/manifest configuration |
| `vote.yaml` | `vote` image scan | Pinned Python base image and build tooling |
| `result.yaml` | `result` image scan | Pinned Node 18/Debian 12 base image and existing result dependencies |
| `worker.yaml` | `worker` image scan | EOL .NET 7 runtime base image and existing worker dependencies |

## Rules

- Every exception names a specific CVE or misconfiguration ID.
- Every exception has an expiry date and a statement explaining why it is
  accepted.
- Do not add a new exception without documenting the reason and reviewing the
  affected package or base image.
- Remove exceptions when the dependency, base image, or manifest is updated.
- Re-run the scans before extending an expiry. If a finding is fixed, the
  exception should be deleted rather than renewed.

All current exceptions expire on **2027-01-31**. After that date Trivy will
report them again and CI will fail until they are fixed or explicitly renewed.
