#!/bin/bash

DIR=$(dirname $0)

# Configure the kubenetes cluster
echo ${KUBERNETES_CA} | base64 --decode > udagram-ca.pem
echo ${KUBERNETES_CLIENT_CA} | base64 --decode > udagram-client-ca.pem
echo ${KUBERNETES_CLIENT_KEY} | base64 --decode > udagram-key.pem
kubectl config set-cluster udagram --server=${KUBERNETES_ENDPOINT} --certificate-authority=udagram-ca.pem
kubectl config set-credentials kubernetes-admin --client-certificate=udagram-client-ca.pem --client-key=udagram-key.pem
kubectl config set-context kubernetes-admin@udagram --cluster=udagram --namespace=default --user=kubernetes-admin
kubectl config use-context kubernetes-admin@udagram

# Replace sensitive variables with evironment ones
# Then apply configmap and secrets
configmap=`cat "$DIR/env-configmap.yaml" | sed "s/{{AWS_BUCKET}}/$AWS_BUCKET/g;s/{{AWS_PROFILE}}/$AWS_PROFILE/g;s/{{AWS_REGION}}/$AWS_REGION/g;s/{{POSTGRESS_DB}}/$POSTGRESS_DB/g;s/{{POSTGRESS_HOST}}/$POSTGRESS_HOST/g;s#{{URL}}#$URL#g;s/{{JWT_SECRET}}/$JWT_SECRET/g"`
echo "$configmap" | kubectl apply -f -

secret=`cat "$DIR/env-secret.yaml" | sed "s/{{POSTGRESS_USERNAME}}/$(echo -n $POSTGRESS_USERNAME|base64)/g;s/{{POSTGRESS_PASSWORD}}/$(echo -n $POSTGRESS_PASSWORD|base64)/g"`
echo "$secret" | kubectl apply -f -

awsSecret=`cat "$DIR/aws-secret.yaml" | sed "s/{{AWS_CREDENTIALS}}/$AWS_CREDENTIALS/g"`
echo "$awsSecret" | kubectl apply -f -

# Apply services
kubectl apply -f $DIR/backend-feed-service.yaml
kubectl apply -f $DIR/backend-user-service.yaml
kubectl apply -f $DIR/reverseproxy-service.yaml
kubectl apply -f $DIR/frontend-service.yaml

# Apply deployment
kubectl apply -f $DIR/backend-feed-deployment.yaml
kubectl apply -f $DIR/backend-user-deployment.yaml
kubectl apply -f $DIR/reverseproxy-deployment.yaml
kubectl apply -f $DIR/frontend-deployment.yaml

# Deploy fluend for cloudwatch monitor
# URL: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-logs.html#ContainerInsights-verify-FluentD
kubectl apply -f $DIR/cloudwatch-namespace.yaml
kubectl create configmap cluster-info --from-literal=cluster.name=udagram --from-literal=logs.region=us-east-1 -n amazon-cloudwatch --dry-run=client -o yaml | kubectl apply -f -