# Single security group for all k3s nodes. No port 22 anywhere - node shell
# access is via SSM Session Manager (see iam module), which needs zero inbound
# rules because it's initiated outbound by the SSM agent over TLS.

resource "aws_security_group" "k3s_node" {
  name        = "${var.project_name}-k3s-node-sg-${var.environment}"
  description = "k3s server/worker nodes - no SSH, API restricted to admin CIDR, HTTP/S open for ingress-nginx"
  vpc_id      = var.vpc_id

  # k3s / Kubernetes API server - restricted to your IP only.
  ingress {
    description = "kube-apiserver from allow-listed CIDRs only (your IP, Jenkins agent IP)"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = var.api_server_allowed_cidrs
  }

  # Node-to-node on 6443 as well - a joining k3s server reaches the init
  # node's API server over its PRIVATE IP to actually join the cluster, and
  # every node talks to the apiserver internally afterward regardless. This
  # was missing entirely - the rule above only covers external admin/Jenkins
  # access, so join nodes had no path to 6443 at all and crash-looped trying
  # to reach it.
  ingress {
    description = "kube-apiserver, node-to-node only"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    self        = true
  }

  # etcd peer + client ports - node-to-node only, never from the internet.
  ingress {
    description = "etcd client/peer, node-to-node only"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    self        = true
  }

  # Flannel VXLAN overlay, node-to-node only.
  ingress {
    description = "flannel VXLAN overlay, node-to-node only"
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    self        = true
  }

  # kubelet metrics/exec, node-to-node only (needed for `kubectl logs/exec`,
  # metrics-server, Prometheus node scraping across nodes).
  ingress {
    description = "kubelet API, node-to-node only"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    self        = true
  }

  # ingress-nginx runs as a hostNetwork DaemonSet - every node terminates
  # HTTP/HTTPS directly, no AWS load balancer needed.
  ingress {
    description = "HTTP for ingress-nginx (redirects to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS for ingress-nginx"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "all outbound (no NAT box needed - nodes have public IPs)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-k3s-node-sg-${var.environment}" }
}
