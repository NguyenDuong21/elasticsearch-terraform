node.name: ${vm_host}
node.roles: [master,data,ingest]

cluster.name: my-cluster
path.data: /data/es
path.logs: /data/logs/es
path.repo: /data/backup-elk
bootstrap.memory_lock: true
network.host: ${vm_ip}
discovery.seed_hosts: ["alice", "bob", "carol"]
cluster.initial_master_nodes: ["alice", "bob", "carol"]
xpack.security.transport.ssl.enabled: true
xpack.security.transport.ssl.verification_mode: certificate
xpack.security.transport.ssl.client_authentication: required
xpack.security.transport.ssl.keystore.path: /home/vhv_admin/elasticsearch/config/cert/elastic-certificates.p12
xpack.security.transport.ssl.truststore.path: /home/vhv_admin/elasticsearch/config/cert/elastic-certificates.p12
