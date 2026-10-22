# Example Voting App

A simple distributed application running across multiple Docker containers.

## Getting started

Download [Docker Desktop](https://www.docker.com/products/docker-desktop) for Mac or Windows. [Docker Compose](https://docs.docker.com/compose) will be automatically installed. On Linux, make sure you have the latest version of [Compose](https://docs.docker.com/compose/install/).

This solution uses Python, Node.js, .NET, with Redis for messaging and Postgres for storage.

Run in this directory to build and run the app:

```shell
docker compose up
```

The `vote` app will be running at [http://localhost:8080](http://localhost:8080), and the `results` will be at [http://localhost:8081](http://localhost:8081).

Alternately, if you want to run it on a [Docker Swarm](https://docs.docker.com/engine/swarm/), first make sure you have a swarm. If you don't, run:

```shell
docker swarm init
```

Once you have your swarm, in this directory run:

```shell
docker stack deploy --compose-file docker-stack.yml vote
```

## Run the app in Kubernetes

The folder k8s-specifications contains the YAML specifications of the Voting App's services.

Run the following command to create the deployments and services. Note it will create these resources in your current namespace (`default` if you haven't changed it.)

```shell
kubectl create -f k8s-specifications/
```

The `vote` web app is then available on port 31000 on each host of the cluster, the `result` web app is available on port 31001.

To remove them, run:

```shell
kubectl delete -f k8s-specifications/
```

## Run the app on EKS

The `terraform/k8s` directory provisions an EKS cluster and managed node group in the account's default VPC, then deploys this application and verifies the `vote` and `result` HTTP endpoints. See [terraform/k8s/README.md](terraform/k8s/README.md) for prerequisites, the real-AWS workflow, and the MiniStack lifecycle test.

### Local EKS with MiniStack and Helm

MiniStack provides a local AWS control plane and runs a real k3s container as the EKS data plane. The workflow builds the hardened images, pushes them to MiniStack ECR, and deploys the Helm chart:

```shell
cd terraform/k8s
KEEP_CLUSTER=1 ./scripts/ministack-recreate.sh
./scripts/ministack-build.sh
./scripts/ministack-ecr-push.sh
./scripts/ministack-helm-demo.sh
```

The Helm demo installs revision 1, verifies both web endpoints, forces a failed upgrade with a bad image tag, and rolls back to revision 1 (recorded as revision 3). MiniStack does not publish NodePorts to the host; the demo verifies HTTP from inside the pods. See [helm/voting-app](helm/voting-app) for the chart.

## Local Kubernetes smoke test with kind

A real AWS account and worker nodes are not required for the application smoke test. The kind workflow builds the hardened images, loads them into a local cluster, patches the upstream manifests for port `8080`, and checks both web endpoints:

```shell
cd terraform/k8s
./scripts/kind-smoke.sh
```

To keep the cluster for inspection after a successful run:

```shell
KEEP_CLUSTER=1 ./scripts/kind-smoke.sh
```

To remove the cluster manually:

```shell
./scripts/kind-down.sh
```

## Continuous integration

Every push and pull request runs `.github/workflows/ci.yml`:

- Fast tests: Compose validation, Terraform fmt/validate/test, Python syntax,
  Node dependencies and syntax, and a .NET worker build.
- Trivy scans of the repository and each built image. The workflow fails on
  new HIGH or CRITICAL findings. Existing, documented exceptions live in
  [`.trivy/`](.trivy/README.md) and expire on 2027-01-31.
- Image builds for `vote`, `result`, and `worker`.

Pushes publish to GHCR with the full commit SHA:

- `ghcr.io/cooljoe464/example-voting-app-vote:<sha>`
- `ghcr.io/cooljoe464/example-voting-app-result:<sha>`
- `ghcr.io/cooljoe464/example-voting-app-worker:<sha>`

The `latest` tag is added only on `main`. Pull requests build and scan the
images but never push them. The first push creates private GHCR packages; change
their visibility in the repository package settings if public pulls are needed.

### Run the workflow locally with act

Install [act](https://github.com/nektos/act), then run:

```shell
winget install --id nektos.act -e
./scripts/act-ci.sh
```

The `.actrc` pins an amd64 Ubuntu image and sets `ACT=true`. That flag skips
GHCR login and image pushes locally, so the workflow can run without a registry
token. It also runs a `pull_request` simulation to verify that no push happens.
Real registry publishing is verified by the first push to GitHub.

## Architecture

![Architecture diagram](architecture.excalidraw.png)

* A front-end web app in [Python](/vote) which lets you vote between two options
* A [Redis](https://hub.docker.com/_/redis/) which collects new votes
* A [.NET](/worker/) worker which consumes votes and stores them in…
* A [Postgres](https://hub.docker.com/_/postgres/) database backed by a Docker volume
* A [Node.js](/result) web app which shows the results of the voting in real time

## Notes

The voting application only accepts one vote per client browser. It does not register additional votes if a vote has already been submitted from a client.

This isn't an example of a properly architected perfectly designed distributed app... it's just a simple
example of the various types of pieces and languages you might see (queues, persistent data, etc), and how to
deal with them in Docker at a basic level.
