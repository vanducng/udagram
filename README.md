# Monolith to Microservices
This project is to design, deploy, and operate microservices and cloud-native applications with a simple NodeJS project called Udagram.

## Softwares setup
As experienced with version conflict issues, it's worth noting the softwares' version that work with setup files within this repo.
* docker: `19.03.8`
* docker-compose: `1.24.0`
* kubeone: `0.11.1`
* kubectl: `1.18.1`
* terraform: `0.12.24`
* npm: `6.14.4`
* node: `8.10.0`

## Setup docker environment
* Install docker via https://docs.docker.com/install/.
* Prepare evironment variables and save into `~/.profile`
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
* From project directory, run below commands:
    ```bash
    cd udacity-c3-deployment/docker
    
    # Build images
    sudo docker-compose -f docker-compose-build.yaml build --parallel
    
    # Push images to docker hub
    sudo docker-compose -f docker-compose-build.yaml push

    # Run docker containers (reverseproxy, restapi-user, restapi-feed & frontend)
    # Argument -E helps to grab evironment variables described above into containers
    sudo -E docker-compose up
    ```
* Validate the result via browser at localhost:8100 and Postman at port 8080 to test API functionalities.

## Setup and deploy on Kubernetes
* Setup kubernetes cluster with KubeOne by following [quickstart](https://github.com/kubermatic/kubeone/blob/master/docs/quickstart-aws.md) and [ssh](https://github.com/kubermatic/kubeone/blob/master/docs/ssh.md) documents.
    ```bash
    eval `ssh-agent`
    ssh-add ~/.ssh/id_rsa
    terraform plan
    terraform apply --auto-approve
    terraform output -json > tf.json
    export KUBECONFIG=$PWD/udagram-kubeconfig
    ```
* Remember the step of exporting KubeConfig once finished cluster setup: `export KUBECONFIG=$PWD/<cluster_name>-kubeconfig`
* Run `kubectl get pods` to check if every are up as expected
* Setup the proper container images, environment configmap and secret (AWS & Postgres credential).
    ```bash
    # Get AWS credential path in base64 format for aws-secret.yml
    echo -n ~/.aws/credentials|base64

    # Get env-secret variable in base64 format for env-secret.yml
    echo -n POSTGRESS_USERNAME|base64
    echo -n POSTGRESS_PASSWORD|base64
    
    # Incase wanna to decode the
    echo -n L2hvbWUvdmFuZHVjbmcvLmF3cy9jcmVkZW50aWFscw==|base64 --decode
    ```
* Run below commands to apply our application settings to kubernetes cluster
    ```bash
    # Appy evironment secrets and variables
    kubectl apply -f udacity-c3-deployment/k8s/aws-secret.yaml
    kubectl apply -f udacity-c3-deployment/k8s/env-configmap.yaml
    kubectl apply -f udacity-c3-deployment/k8s/env-secret.yaml

    # Apply config for all services
    kubectl apply -f udacity-c3-deployment/k8s/backend-feed-service.yaml
    kubectl apply -f udacity-c3-deployment/k8s/backend-user-service.yaml
    kubectl apply -f udacity-c3-deployment/k8s/reverseproxy-service.yaml
    kubectl apply -f udacity-c3-deployment/k8s/frontend-service.yaml

    # Apply config for deployments
    kubectl apply -f udacity-c3-deployment/k8s/backend-feed-deployment.yaml
    kubectl apply -f udacity-c3-deployment/k8s/backend-user-deployment.yaml
    kubectl apply -f udacity-c3-deployment/k8s/reverseproxy-deployment.yaml
    kubectl apply -f udacity-c3-deployment/k8s/frontend-deployment.yaml

    # Apply config for pod
    kubectl apply -f udacity-c3-deployment/k8s/pod-example/pod.yaml
    ```
* Test the deployment by running port-forward to `reverseproxy` service at port 8080.
    ```bash
    kubectl port-forward service/reverseproxy 8080:8080
    ```

## CI/CD with Travis
* Install Travis from market place and link to project
* Prepare the CI/CD plan within `.travis.yml` file in the root of project
* In every new commit, check the Travis build result.  

> Note: Check the screenshots folder for the result captured during this project deployment