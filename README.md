# ess-matrix-conf-2025

## Single Node Kubernetes Clusters

### Linux

- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/) : A good starting point for a single node cluster on a local laptop
- [k3s](https://k3s.io/) : A good starting point for a single node cluster on a virtual machine

### MacOS

- [rancher](https://rancher-desktop.io/) : A good starting point for a single node cluster with a GUI. Uses k3s under the hood.

### Windows

- [rancher](https://rancher-desktop.io/) : A good starting point for a single node cluster with a GUI. Uses k3s under the hood.

## kubectl (Kubernetes Command Line Interface)

- Go to the [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) page to download and install kubectl

- With rancher, use `kubectl config use-context rancher-desktop` to switch to the rancher context.
- With kind, use `kubectl config use-context kind-<cluster name>` to switch to the kind context.

## Helm

- Go to the [helm.sh](https://helm.sh/docs/intro/install/) page to download and install helm

## Certificates

Initialize the namespace with `kubectl create namespace ess`.

### mkcert

Useful to set up ESS on a local machine. See the [github project](https://github.com/FiloSottile/mkcert)

Example usage:

```bash
mkcert -install
mkcert ess.localhost
kubectl create secret tls ess-well-known-certificate --cert=./ess.localhost.pem --key=./ess.localhost-key.pem -n ess

mkcert matrix.ess.localhost
kubectl create secret tls ess-matrix-certificate --cert=./matrix.ess.localhost.pem --key=./matrix.ess.localhost-key.pem -n ess

mkcert mrtc.ess.localhost
kubectl create secret tls ess-mrtc-certificate --cert=./mrtc.ess.localhost.pem --key=./mrtc.ess.localhost-key.pem -n ess

mkcert chat.ess.localhost
kubectl create secret tls ess-chat-certificate --cert=./chat.ess.localhost.pem --key=./chat.ess.localhost-key.pem -n ess

mkcert auth.ess.localhost
kubectl create secret tls ess-auth-certificate --cert=./auth.ess.localhost.pem --key=./auth.ess.localhost-key.pem -n ess

mkcert admin.ess.localhost
kubectl create secret tls ess-admin-certificate --cert=./admin.ess.localhost.pem --key=./admin.ess.localhost-key.pem -n ess
```

### Cert-Manager

Cert-Manager is a Kubernetes project that manages certificates for you. See the ESS Community README for more details.

## Set-up

### Local laptops

#### Linux

Linux users can use the script `scripts/setup_dev_cluster.sh` to set up a local cluster with a local CA.

#### MacOS & Windows

MacOS users should use [rancher](#macos) and [mkcert](#mkcert) to set up the local CA.

#### Setup

Follow the [ESS Community README](https://github.com/element-hq/ess-helm).

For local testing:
 - For the DNS, you can use your `/etc/hosts` file
 - For the certificates, "Use existing certificates" option with mkcert.

##### Matrix RTC local setup

The following values should be used to test matrix RTC locally.

```yml
matrixRTC:
  extraEnv:
  - name: LIVEKIT_INSECURE_SKIP_VERIFY_TLS
    value: YES_I_KNOW_WHAT_I_AM_DOING
  hostAliases:
  - hostnames:
    - ess.localhost
    - mrtc.ess.localhost
    - synapse.ess.localhost
    ip: '{{ ( (lookup "v1" "Service" "ingress-nginx" "ingress-nginx-controller") |
      default (dict "spec" (dict "clusterIP" "127.0.0.1")) ).spec.clusterIP }}'
```

##### Matrix Authentication Service without SMTP server

The following values should be used to test Matrix Authentication Service locally without SMTP.

```yml
matrixAuthenticationService:
  image:
    tag: 1.4.0-rc.1
  additional:
    auth.yaml:
      config: |
        account:
          password_registration_enabled: true
          password_change_allowed: true
          registration_token_required: true
          password_registration_email_required: false
```

### VPS

For VPS, you should follow the ESS Walkthrough.

### Explaining the install process

#### Use kubectl to watch the pods
```
kubectl get pods -n ess -w
NAME                                                   READY   STATUS      RESTARTS   AGE
```

#### Watch in Rancher UI

![Rancher](assets/rancher.png)

#### Setup steps

1. The deployment markers run first, and make sure that the state of the installation is compatible with the options passed in the values files. For example, it would prevent disabling MAS once ESS is setup with MAS enabled.
  ```
  ess-deployment-markers-pre-6c75f                       0/1     Completed   0          11m
  ```
1. All the secrets that the chart is able to generate are initialized
  ```
  ess-init-secrets-kdh42                                 0/1     Completed   0          11m
  ```
1. A job runs before the main installation to check that Synapse configuration is OK
  ```
  ess-synapse-check-config-69t7c                         0/1     Completed   0          11m
  ```
1. The main installation runs by setting up a couple of services in parallel.
  1. Postgres is automatically created by default, and hosts all the required databases used within ESS.
  ```
  ess-postgres-0                                         3/3     Running     0          10m
  ```
  1. HAProxy handles internal routing to Synapse and its workers
  ```
  ess-haproxy-7bbc94b855-mt6bj                           1/1     Running     0          10m
  ```
  1. Synapse starts with only a `main` process which should be enough for most simple homeservers.
  ```
  ess-synapse-main-0                                     1/1     Running     0          10m
  ```
  1. Matrix Authentication Service starts and will handle all the users authentication.
  ```
  ess-matrix-authentication-service-56597f54c5-fqd9b     1/1     Running     0          10m
  ```
  1. Matrix RTC is made of 2 services : The authorisation service and the SFU. The Authorisation service issues JWT tokens for Matrix users to authenticate against the SFU. The SFU handles the VoIP WebRTC traffic.
  ```
  ess-matrix-rtc-authorisation-service-9ff6d44d5-z7n2n   1/1     Running     0          10m
  ess-matrix-rtc-sfu-5896d47fd4-5dvs2                    1/1     Running     0          10m
  ```
  1. Element Web and Element Admin clients allows user to use ESS.
  ```
  ess-element-admin-59b96c7fc8-p2thz                     1/1     Running     0          10m
  ess-element-web-56f99c8889-hszzj                       1/1     Running     0          10m
  ```
  1. Deployment Markers post-hook run to update the markers. Those will prevent you to pass breaking configuration to your ESS deployment.
  ```
  ess-deployment-markers-post-vwb7f                      0/1     Completed   0          10m
  ```

### First actions and checks

#### Create 1 initial admin user

Run the following command, and select "Set the admin status", "Set Password", and then "Create the user".

```
kubectl exec -n ess -it deploy/ess-matrix-authentication-service -- mas-cli manage register-user
```

#### Open the admin UI

Go to `https://admin.ess.localhost` and login with the credentials you just created.

#### Create a new registration token

From the Admin UI, create a new registration token. This can be used to register a new user.
