# Udagram

This project is to develop an Instagram-like app with three services: frontend, restapi-feed & restapi-user. These services are decoupled in term of developement and deployment by adopting docker & kubenertes technologies.

- `frontend`: built with Ionic framework with simple UI as below.
- `restapi-feed`: handle feed data (caption and image) input by user.
- `restapi-user`: handle user authentication and autherization.
- `storage`: AWS RDS Postgres & AWS S3.
<p align="center">
<image src="./media/Udagram-overview.jpg" width="80%">
</p>
<p align="center"> <strong> Udagram Overview </strong><p>

## Local development environment

As experienced with version conflict issues, it's worth noting the softwares' version that work with setup files within this repo.

- OS: `Ubuntu 18.04 LTS`
- docker: `19.03.8`
- docker-compose: `1.24.0`
- kubeone: `0.11.1`
- kubectl: `1.18.1`
- terraform: `0.12.24`
- npm: `6.14.4`
- node: `8.10.0`
- aws-cli: `2.0.7`

## Storage service setup
- Create an AWS RDS instance with Postgres & S3 to store user and feed data. S3 permission requires additional CORS configuration setup as below.
<p align="center">
<image src="./media/aws-storage.jpg" width="80%">
</p>
<p align="center"> <strong> RDS & S3 setup </strong><p>

## Dockerize application

- Prepare below evironment variables and save at `~/.profile`

  ```bash
  export POSTGRESS_USERNAME='';
  export POSTGRESS_PASSWORD='';
  export POSTGRESS_DB='';
  export POSTGRESS_HOST='';
  export AWS_REGION='';
  export AWS_PROFILE='';
  export AWS_BUCKET='';
  export JWT_SECRET='';
  ```

- From project directory, run below commands step by step.  To enhance devops capability, the script `publish_to_docker_hub.sh` will handle all steps. Simply run `sh deloyment/docker/publish_to_docker_hub.sh`.

  ```bash
  cd deployment/docker

  # Build images
  sudo docker-compose -f docker-compose-build.yaml build --parallel

  # Push images to docker hub
  sudo docker-compose -f docker-compose-build.yaml push

  # Run docker containers (reverseproxy, restapi-user, restapi-feed & frontend)
  # Argument -E helps to grab evironment variables described above into containers
  source ~/.profile
  sudo -E docker-compose up
  ```

- Validate the result via web browser at localhost:8100 and Postman at port 8080 to test API functionalities (see the GIF images below).

<p align="center">
<image src="./media/docker-run.gif" width="80%">
</p>
<p align="center"> <strong> Docker run on local machine </strong><p>

<p align="center">
<image src="./media/functionalities-test.gif" width="80%">
</p>
<p align="center"> <strong> Functionalities test </strong><p>

## Deploy containers to Kubernetes

### Install Kubenertes cluster with KubeOne

- Setup kubernetes cluster with KubeOne by following [quickstart](https://github.com/kubermatic/kubeone/blob/master/docs/quickstart-aws.md) and [ssh](https://github.com/kubermatic/kubeone/blob/master/docs/ssh.md) documents.

  ```bash
  # Enable ssh agent, ensure the pair key are generated in advance if not available
  eval `ssh-agent`
  ssh-add ~/.ssh/id_rsa

  # Establish AWS infrastructure with terraform
  # Prepare terraform.tfvars with respective cluster info including cluster_name, region, ssh_public_key path & instance size
  cd deployment/k8s/infrastructure
  terraform init
  terraform plan
  terraform apply --auto-approve
  terraform output -json > tf.json

  # Install the kubenertes cluster
  # Prepare create config.yaml describe kubernetes version & cloud provider
  # udagram-kubeconfig file will be generated as kubernetes config file for kubectl command usage later
  kubeone install config.yaml --tfjson
  kubectl --kubeconfig=udagram-kubeconfig #Alternative way is to save the config content to ~/.kube/config
  ```

- In case cluster removal required, follow below steps

  ```bash
  cd deployment/k8s/infrastructure
  kubeone reset config.yaml --tfjson terraform.tfstate
  terraform destroy
  ```

### Deploy application

- Setup the proper container images, environment configmap and secret (AWS & Postgres credential).
- All variables are packed within evironment configmap and secret. With secret configuration, variables are passed under base64 encoded format to less expose sensitive data. Below commands describes how it can simply achieved.
  ```bash
  # Get AWS credential path in base64 format for aws-secret.yml
  echo -n "`cat ~/.aws/credentials`"|base64

  # Get env-secret variable in base64 format for env-secret.yml
  echo -n POSTGRESS_USERNAME|base64
  echo -n POSTGRESS_PASSWORD|base64

  # Decode
  echo -n text_to_decode|base64 --decode
  ```

- Run below commands to deploy application to kubernetes cluster step by step. To enhance devops capability, the script `deploy_to_kube_cluster.sh` will handle all steps. Simply run `sh deloyment/k8s/deploy_to_kube_cluster.sh`. 

  ```bash
  # Appy evironment secrets and variables
  kubectl apply -f deployment/k8s/aws-secret.yaml
  kubectl apply -f deployment/k8s/env-configmap.yaml
  kubectl apply -f deployment/k8s/env-secret.yaml

  # Apply config for all services
  kubectl apply -f deployment/k8s/backend-feed-service.yaml
  kubectl apply -f deployment/k8s/backend-user-service.yaml
  kubectl apply -f deployment/k8s/reverseproxy-service.yaml
  kubectl apply -f deployment/k8s/frontend-service.yaml

  # Apply config for deployments
  kubectl apply -f deployment/k8s/backend-feed-deployment.yaml
  kubectl apply -f deployment/k8s/backend-user-deployment.yaml
  kubectl apply -f deployment/k8s/reverseproxy-deployment.yaml
  kubectl apply -f deployment/k8s/frontend-deployment.yaml

  # Run port-forward to test the web UI and API functionalies locally via web browser/postman
  kubectl port-forward service/frontend 8100:8100
  kubectl port-forward service/reverseproxy 8080:8080
  ```
- Below screenshot shows our application has been successfully deployed to the kubernetes cluster.
  <p align="center">
  <image src="./media/kubernetes deployment.jpg" width="80%">
  </p>
  <p align="center"> <strong> Kubernetes on live </strong><p>

### Kubernetes with rolling update for new version
- Assume that we have new restapi-feed version, with kubernetes the deployment has never been easier with no downtime. Look below GIF image, the new container created, then terminate the old one and finally replace all with all containers in new version.
  <p align="center">
  <image src="./media/kube-rolling-update.gif" width="80%">
  </p>
  <p align="center"> <strong> Kubernetes rolling update </strong><p>

### Kubernetes with 2 version running on same cluster for A/B testing purpose


### Deploy fluentd for Cloudwatch logging
- Follow the a details instruction by AWS [here](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-logs.html#ContainerInsights-verify-FluentD) to enable centralize logging capability.
- Run below commands to deploy fluentd to the Kubernetes cluster
  ```bash
  # Deploy fluentd for cloudwatch monitor
  kubectl apply -f deployment/k8s/cloudwatch-namespace.yaml
  kubectl create configmap cluster-info --from-literal=cluster.name=udagram --from-literal=logs.region=us-east-1 -n amazon-cloudwatch --dry-run=client -o yaml | kubectl apply -f -
  
  # Check if the pod under amazon-cloudwatch deployed properly
  kubectl get pods -n amazon-cloudwatch
  ```
- As this service will write log to LogGroup within Cloudwatch, the IAM configuration of permission for the the role may required. Run `kubectl logs pod_name -n amazon-cloudwatch|grep error` to deep diving the issue if logs are not available. Below screenshot shows successful log record to Cloudwatch ussing fluentd.
  <p align="center">
    <image src="./media/cloudwatch.jpg" width="80%">
  </p>
  <p align="center"> <strong> Cloudwatch </strong><p>

## CI/CD with Travis

- Install Travis from market place and link to project
- Prepare the CI/CD plan within `.travis.yml` file in the root of project
- Configure environment variables
  <p align="center">
    <image src="./media/travis-environment-var.jpg" width="100%">
  </p>
  <p align="center"> <strong> Travis environment variables </strong><p>

- Once committed, travis will push the new docker images to docker hub, and apply the changes to defined kubernetes cluster.
  <p align="center">
    <image src="./media/travis-deployment.jpg" width="80%">
  </p>
  <p align="center"> <strong> Travis build success </strong><p>

