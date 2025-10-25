
kubectl create secret generic azure-credentials \
  --from-literal=client-id='your_client_id' \
  --from-literal=client-secret='your_client_secret' \
  --from-literal=tenant-id='your_tenant_id' \
  --from-literal=subscription-id='your_subscription_id'


docker build -t azure-lb-updater .
docker push 192.168.8.129:32000/update-lb-cron:1.0.0
kubectl apply -f cron.yaml
