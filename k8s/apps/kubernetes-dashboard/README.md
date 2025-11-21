# Kubernetes Dashboard

The Kubernetes Dashboard is deployed and accessible at: https://k8s.pane.run

## Access

1. Navigate to: https://k8s.pane.run
2. Select "Token" authentication method
3. Use the admin token below to log in

## Admin Token

To retrieve the current admin token:

```bash
kubectl get secret admin-user-token -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 -d
```

Current token:
```
eyJhbGciOiJSUzI1NiIsImtpZCI6IjdtQ0MySDhFMVdUV2RRUVVKbG80bDJXbTBXenhaNVQtLVFrUGtNX3kxaEkifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlcm5ldGVzLWRhc2hib2FyZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJhZG1pbi11c2VyLXRva2VuIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImFkbWluLXVzZXIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiJkY2VkOTJiYi1hODU2LTQzMGUtODQ0Zi00ZGMwYzJjZDYwNjAiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6a3ViZXJuZXRlcy1kYXNoYm9hcmQ6YWRtaW4tdXNlciJ9.S9qehPE_XDwOEbYEwcL9iS8XnXlK0Xyp1Rz9d9sEHrv6SDZioU0BuXmvqHCZ05W1Wb3p5Zf6bTImwXry9TBtOK1xMcSTYu755u_RThlOdhPS43WIFcO4FQzouGKJdnQSacZup6dysI-9cM9sRWeFzHAJWOxNEd4Ew7YoNOnW99z-_a-hS4nYA7TqR4YyRJxZeh5H1nXIPs3_ah-W2X7g7qooaij2_nghibE_mBF1QmAmS9YLJX3a6PxHvuKbEFgv54CjWxPfjilm2LT5wjOzW3LEmGh8jGZlnlYFySTj5Gq6RiB83rTJpBy2oQsNoJNnrYgq0_KFCCWOd3ly9LxNv81Mwmc30rsSBAFgInuSDeSd_KTWnoJuop1yuYseRr7NRGkOhbY6Zv8XIeICwl2dMBlP5HC7zEZd0YIlZXWnTjjTqQHdf903ZQL8GGr_rCKW2rEWPSUoBloFkm88pnK65GrXIIlV0AugBUB39GtGcDHqi0_pkPB08AO03JwPDZj7MUWJ22TO_Fa9dyHlrUOmHA2Y9r0WSsokzxIGVDB4i7UMlYXOknBIUkfU3oUY1WuRp2ZWEqFr0I69w3bN3g-PYi2N9btd71Tr77KPFu-QawSlRPuzckGWMJROk8SZpH6FmNsD_kZ0t7scVVnofvu5U7QyGlbKoBH_xl0wUgZqhAw
```

## Components

- **Namespace**: `kubernetes-dashboard`
- **Dashboard Service**: `kubernetes-dashboard` (port 443)
- **Metrics Scraper**: `dashboard-metrics-scraper` (port 8000)
- **Admin Service Account**: `admin-user` (cluster-admin role)
- **TLS Certificate**: `k8s-dashboard-tls` (managed by cert-manager)
- **Ingress**: Traefik IngressRoute at `k8s.pane.run`

## Files

- `namespace.yaml` - Namespace definition
- `admin-user.yaml` - Admin service account and cluster role binding
- `admin-token.yaml` - Long-lived token for admin user
- `ingressroute.yaml` - Traefik IngressRoute with TLS certificate

## Management Commands

Check dashboard status:
```bash
kubectl get all -n kubernetes-dashboard
```

View logs:
```bash
kubectl logs -n kubernetes-dashboard -l app.kubernetes.io/name=kubernetes-dashboard
```

Scale dashboard:
```bash
kubectl scale deployment kubernetes-dashboard -n kubernetes-dashboard --replicas=1
```

## Security Notes

- The admin-user service account has cluster-admin privileges
- The token is stored in a Kubernetes secret
- TLS is enabled via cert-manager with Let's Encrypt
- Access is through Traefik ingress with HTTPS only
