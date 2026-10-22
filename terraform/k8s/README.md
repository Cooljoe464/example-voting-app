# EKS deployment for the voting app

This directory provisions an Amazon EKS cluster and managed node group in the
account's default VPC, then verifies the cluster and deploys the application.

It supports two workflows:

- **Real AWS** uses the default Terraform workspace and the real AWS provider.
- **MiniStack** uses the `ministack` workspace and a local AWS emulator. MiniStack
  runs a real, privileged k3s container as the EKS data plane, so the Kubernetes
  API, pods, and ECR image pulls work locally without creating billable AWS
  resources. Use it for fast, repeatable `apply`/`destroy` and Helm testing.

The MiniStack workflow creates five ECR repositories and disables EKS addons and
managed node groups, which MiniStack does not implement. The default VPC
(`vpc-00000001` and its three subnets) is seeded by MiniStack; no VPC bootstrap
is required.

## Prerequisites

- Terraform **>= 1.17.0**
- AWS CLI v2, authenticated for the target account (real AWS only)
- Helm **>= 4** for the MiniStack Helm demo
- `kubectl`
- Docker with a running daemon (Docker Desktop on Windows)
- `kind` for the optional local application smoke test
- Network access to the AWS APIs and to the default VPC's public subnets

If Terraform is not on `PATH`, set `TF_BIN` to its executable. The scripts also
accept `AWS_BIN`, `KUBECTL_BIN`, `KIND_BIN`, `DOCKER_BIN`, and `HELM_BIN`.

## Real AWS workflow

Authenticate first, for example with IAM Identity Center:

```shell
aws sso login --profile my-profile
export AWS_PROFILE=my-profile
```

Create a tfvars file from the example:

```shell
cp terraform.tfvars.example terraform.tfvars
```

The scripts automatically detect the administrator's public IP and pass it as
`endpoint_public_access_cidrs`. Set `ADMIN_CIDR` to override detection, or set
the value in `terraform.tfvars` if you run Terraform directly. `ADMIN_CIDR`
accepts either `203.0.113.10` or `203.0.113.10/32`.

The real-AWS scripts always select the `default` Terraform workspace:

```shell
./scripts/plan.sh
./scripts/apply.sh
./scripts/verify.sh
./scripts/destroy.sh
```

Use `./scripts/recreate.sh` for the full lifecycle proof:

```text
apply -> verify -> destroy -> assert destroyed -> recreate -> verify -> destroy
```

`verify.sh` waits for the cluster and addons, updates kubeconfig, deploys the
upstream `k8s-specifications`, waits for rollouts, and checks the vote and
result HTTP endpoints. The upstream manifests use the public stock images; the
hardened images are validated by the kind smoke test instead.

The configuration intentionally uses the account's **default VPC**. `locals.tf`
requires at least two default subnets and checks that the node group sizes are
consistent before creating resources. No VPC, NAT gateway, or customer KMS key
is created, which keeps the lifecycle fast and avoids resources that linger
after `destroy`.

### CI and static checks

The native Terraform test uses mocked AWS resources and does not contact AWS:

```shell
terraform init -input=false
terraform fmt -check -recursive
terraform validate
terraform test
```

## MiniStack lifecycle workflow

MiniStack runs as the `ministack` Docker container, backed by the
`ministack-data` volume, and serves the AWS APIs on `http://localhost:4566`. The
scripts start it automatically when needed:

```shell
./scripts/ministack-up.sh
./scripts/ministack-plan.sh
./scripts/ministack-apply.sh
./scripts/ministack-verify.sh
./scripts/ministack-destroy.sh
```

Run the complete lifecycle, including destroy and recreate:

```shell
KEEP_CLUSTER=1 ./scripts/ministack-recreate.sh
```

The scripts use the `ministack` workspace and `terraform.ministack.tfvars`.
MiniStack's k3s data plane runs Kubernetes **1.34**, matching the Terraform
configuration. MiniStack accepts any cluster version string, but the k3s image
defaults to an older release; the scripts set
`MINISTACK_K3S_IMAGE=rancher/k3s:v1.34.12-k3s1` so the server and Terraform
report the same version.

The provider endpoint and credentials are supplied only through environment
variables (`AWS_ENDPOINT_URL`, static test keys, and
`AWS_EC2_METADATA_DISABLED=true`). No real credentials are required. Never point
these credentials at real AWS. EKS k3s containers need the Docker socket, which
Docker Desktop exposes as `/run/host-services/docker.proxy.sock`; native Linux
uses `/var/run/docker.sock`. Override detection with `MINISTACK_DOCKER_SOCKET`.

MiniStack state is persistent, but EKS k3s sidecars do not survive a MiniStack
restart. After restarting the container, re-run `ministack-recreate.sh` so the
cluster is destroyed and recreated against a fresh k3s sidecar.

Stop the MiniStack container while preserving its state volume:

```shell
./scripts/ministack-down.sh
```

Remove the container and volume:

```shell
./scripts/ministack-down.sh --purge
```

If the persistent volume is reset while Terraform still has state, destroy the
`ministack` workspace before recreating it. Otherwise Terraform may try to delete
resources that no longer exist.

### ECR images and Helm demo

The Terraform configuration creates ECR repositories for `vote`, `result`,
`worker`, `redis`, and `db`. The MiniStack lifecycle destroy deletes those
repositories and their images, so build and push after the lifecycle test:

```shell
./scripts/ministack-build.sh
./scripts/ministack-ecr-push.sh
```

`ministack-ecr-push.sh` logs in to `localhost:4566`, tags the local images into
the MiniStack ECR registry, and pushes them. MiniStack configures k3s with an ECR
mirror, so the cluster pulls
`000000000000.dkr.ecr.us-east-1.amazonaws.com/voting-app/*` without an image pull
secret or `/etc/hosts` entry.

The Helm chart lives in [helm/voting-app](../../helm/voting-app). It deploys all
five components into the `voting-app` namespace with the image registry supplied
at install time. Run the install, failed-upgrade, and rollback demo with:

```shell
./scripts/ministack-helm-demo.sh
```

If Helm is not on `PATH`, set `HELM_BIN` to its executable. The demo:

1. Installs revision 1 and verifies the `vote` and `result` HTTP endpoints.
2. Upgrades with `vote.image.tag=does-not-exist` and a second vote replica; the
   rollout fails with `ImagePullBackOff`, leaving revision 2 in `failed` state.
3. Rolls back to revision 1, which Helm records as deployed revision 3, and
   re-checks the endpoints.

MiniStack does not publish NodePorts to the host. Verify HTTP with
`kubectl port-forward` or `kubectl exec`; the demo uses `kubectl exec`.

## Local application smoke test with kind

The kind workflow uses the real Kubernetes API and validates the hardened
images end to end:

```shell
./scripts/kind-smoke.sh
```

It performs the following steps:

1. Creates the `voting-app` kind cluster (context `kind-voting-app`).
2. Builds `voting-app/vote:kind`, `voting-app/result:kind`, and
   `voting-app/worker:kind`.
3. Loads the images into the kind node.
4. Applies `k8s-specifications`, switches the three application deployments to
   the local images, sets `imagePullPolicy: IfNotPresent`, and points the vote
   and result services at container port `8080`.
5. Waits for all deployments and checks `vote` (`HTTP GET` and `POST`) and
   `result`.

By default the cluster is deleted after the run. Keep it for inspection with:

```shell
KEEP_CLUSTER=1 ./scripts/kind-smoke.sh
```

Individual steps are also available:

```shell
./scripts/kind-up.sh
./scripts/kind-build.sh
./scripts/kind-load.sh
./scripts/kind-deploy.sh
./scripts/kind-verify.sh
./scripts/kind-down.sh
```

## State isolation

| Workflow | Workspace | Default var file |
| --- | --- | --- |
| Real AWS | `default` | `terraform.tfvars` |
| MiniStack | `ministack` | `terraform.ministack.tfvars` |

Keep the workspaces separate. The real-AWS scripts select `default`
automatically, and the MiniStack scripts select `ministack` automatically.
State is stored under `terraform.tfstate.d/` and is ignored by Git.

## Outputs

| Output | Description |
| --- | --- |
| `aws_region` | Region used by the deployment |
| `vpc_id` | Default VPC used by the cluster |
| `subnet_ids` | Default VPC subnets selected for EKS |
| `cluster_name` | EKS cluster name |
| `cluster_version` | EKS Kubernetes version |
| `cluster_endpoint` | EKS API server endpoint |
| `cluster_certificate_authority_data` | Base64 CA data (sensitive) |
| `node_group_arn` | Managed node group ARN (null when node groups are disabled) |
| `update_kubeconfig_command` | Ready-to-run kubeconfig command |
| `ecr_registry` | ECR registry used by the Helm chart |
| `ecr_repository_urls` | ECR repository URLs for the five components |

## Troubleshooting

- **`no valid credential sources`**: authenticate with `aws sso login` or set
  a valid `AWS_PROFILE`.
- **`could not determine the administrator public IP`**: set `ADMIN_CIDR`.
- **MiniStack plan fails on `DescribeAddonVersions` or a node group**: keep
  `enable_eks_addons = false` and `enable_managed_node_group = false` in
  `terraform.ministack.tfvars`; MiniStack does not implement those APIs.
- **MiniStack EKS pods stay `Pending` or kubeconfig is stale**: re-run
  `./scripts/ministack-verify.sh`. The EKS endpoint port can change after a
  destroy/recreate, and `update-kubeconfig` must run again.
- **MiniStack `ImagePullBackOff` for ECR images**: rebuild and re-push after a
  lifecycle destroy; `ministack-destroy.sh` deletes the ECR repositories.
- **Docker push to `localhost:4566` rejected**: add `localhost:4566` as an
  insecure registry in Docker Desktop, or use the anonymous MiniStack ECR
  registry endpoint.
- **kind pods in `ImagePullBackOff`**: confirm the images were loaded and that
  the deployments use `imagePullPolicy: IfNotPresent`; `kind-deploy.sh` applies
  both.
- **Wrong workspace after switching workflows**: re-run the appropriate
  `plan.sh`/`apply.sh` wrapper, which selects the correct workspace, or use
  `terraform workspace select default` / `terraform workspace select ministack`.
