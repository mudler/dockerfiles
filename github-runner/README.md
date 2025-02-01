# github-runner

This is a small Dockerfile providing a github runner for amd64 and arm64 which can run on Kubernetes.

Supported arches are:
  - aarch64
  - amd64

## Environment variables
```terminal
| Variable   | Values                                 | default        |
|------------+----------------------------------------+----------------|
| `TOKEN`    | token for runner from github           | <unset>        |
| `ARCH`     | arm64, x64                             | x64            |
| `OS`       | linux,osx                              | linux          |
| `ORG`      | name of the github org                 | <unset>        |
| `REPO`     | name of the github repo                | <unset>        |
| `VERSION`  | version of the github runner to user   | 2.280.3        |
| `CHECKSUM` | checksum for the github runner version | valid checksum |
```

## Run with docker

To run the action runner with docker, for example it is necessary just to specify all the settings with environment variables (and share the docker socket):

```bash
docker run -e TOKEN=<TOKEN> -e ARCH=<ARCH> -e ORG=<ORG> -e REPO=<REPO> -e VERSION=<VERSION> -e CHECKSUM=<CHECKSUM> -v /var/run:/var/run -d --rm quay.io/kairos/github-runner:latest
```

## Run with Kubernetes

Edit the `deployment.yaml` file with your token ( [that you can get from the setting tab of your repo](https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners#adding-a-self-hosted-runner-to-a-repository) ):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: github-token
  namespace: github-runner
stringData:
  token: XXX
```

Edit the `ORG` and the `REPO` in the deployment. You might need also to tweak the github runner version (`VERSION`):

```yaml
        - name: VERSION
          value: "2.287.1"
        - name: ORG
          value: XXX
        - name: REPO
          value: XXX
```

### Bonus

The image runs with a docker dind-sidecar so the github runner can run docker commands. You can select which version of docker by changing the relevant part in the deployment manifest:

```yaml
      containers:
      - name: dind
        image: docker:20.10.16-dind
        command:
        - /usr/local/bin/dockerd-entrypoint.sh
        - --mtu=1100
```
