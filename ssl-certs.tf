# CSR for worker 0
resource "local_file" "csr-worker-0" {
  content = <<EOF
{
  "CN": "system:node:worker-0",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

  filename = "conf/csr-worker-0.json"
}

# Cert generator for worker 0
resource "local_file" "cert-gen-worker-0" {
  content = <<EOF
  cfssl gencert \
  -ca=../ca/ca.pem \
  -ca-key=../ca/ca-key.pem \
  -config=../ca/ca-config.json \
  -hostname=worker-0,${local.nat_ip_worker_0},${local.network_ip_worker_0} \
  -profile=kubernetes \
  csr-worker-0.json | cfssljson -bare worker-0

EOF

  filename = "conf/cert-gen-worker-0.sh"
}

# The Kubernetes API Server Certificate

resource "local_file" "csr-api-server" {
  content = <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

  filename = "conf/csr-api-server.json"
}

resource "local_file" "cert-gen-api-server" {
  content = <<EOF
  cfssl gencert \
  -ca=../ca/ca.pem \
  -ca-key=../ca/ca-key.pem \
  -config=../ca/ca-config.json \
  -hostname=${local.api_public_ip},10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  csr-api-server.json | cfssljson -bare kubernetes-api

EOF

  filename = "conf/cert-gen-api-server.sh"
}
